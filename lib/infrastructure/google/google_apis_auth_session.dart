import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../application/ports/google_auth_session.dart';
import '../../application/ports/secret_store.dart';
import 'google_oauth_desktop_client.dart';

const googleMailSendScopes = [
  'https://www.googleapis.com/auth/gmail.send',
  'openid',
  'email',
];

const googleRefreshTokenStorageKey = 'accord_memo.google.oauth.refresh_token';
const googleAccountEmailStorageKey = 'accord_memo.google.oauth.account_email';

typedef ObtainGoogleUserConsent =
    Future<AccessCredentials> Function({
      required ClientId clientId,
      required List<String> scopes,
      required void Function(String url) prompt,
    });

typedef OpenGoogleRefreshClient =
    Future<AuthClient> Function({
      required ClientId clientId,
      required String refreshToken,
      required List<String> scopes,
    });

typedef RevokeGoogleToken = Future<void> Function(String token);

typedef OpenAuthorizationUrl = Future<bool> Function(Uri url);

final class GoogleApisAuthSession implements GoogleAuthSession {
  GoogleApisAuthSession({
    required this._desktopClient,
    required this._store,
    ObtainGoogleUserConsent? obtainConsent,
    OpenGoogleRefreshClient? openRefreshClient,
    RevokeGoogleToken? revokeToken,
    OpenAuthorizationUrl? openAuthorizationUrl,
  }) : _obtainConsent = obtainConsent ?? _defaultObtainConsent,
       _openRefreshClient = openRefreshClient ?? _defaultOpenRefreshClient,
       _revokeToken = revokeToken ?? _defaultRevokeToken,
       _openAuthorizationUrl =
           openAuthorizationUrl ?? _defaultOpenAuthorizationUrl;

  final GoogleOAuthDesktopClient _desktopClient;
  final SecretStore _store;
  final ObtainGoogleUserConsent _obtainConsent;
  final OpenGoogleRefreshClient _openRefreshClient;
  final RevokeGoogleToken _revokeToken;
  final OpenAuthorizationUrl _openAuthorizationUrl;

  ClientId get _clientId {
    return ClientId(_desktopClient.clientId, _desktopClient.clientSecret);
  }

  @override
  Future<GoogleAuthState> currentState() async {
    final email = await _store.read(googleAccountEmailStorageKey);
    final refreshToken = await _store.read(googleRefreshTokenStorageKey);
    if (email == null ||
        email.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return const GoogleAuthState.disconnected();
    }
    return GoogleAuthState.connected(email);
  }

  @override
  Future<GoogleAuthState> connect() async {
    if (!_desktopClient.isConfigured) {
      throw const GoogleOAuthClientNotConfigured();
    }

    late final AccessCredentials credentials;
    try {
      credentials = await _obtainConsent(
        clientId: _clientId,
        scopes: googleMailSendScopes,
        prompt: (url) {
          _openAuthorizationUrl(
            Uri.parse(url),
          ).then((opened) {
            if (!opened) {
              throw const GoogleAuthorizationFailed();
            }
          });
        },
      );
    } on UserConsentException {
      throw const GoogleAuthorizationCancelled();
    } on GoogleAuthException {
      rethrow;
    } catch (_) {
      throw const GoogleAuthorizationFailed();
    }

    final refreshToken = credentials.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GoogleRefreshTokenMissing();
    }

    var email = _emailFromIdToken(credentials.idToken);
    email ??= await _emailFromUserInfo(credentials.accessToken.data);
    if (email == null || email.isEmpty) {
      throw const GoogleAuthorizationFailed();
    }

    await _store.write(googleRefreshTokenStorageKey, refreshToken);
    await _store.write(googleAccountEmailStorageKey, email);
    return GoogleAuthState.connected(email);
  }

  @override
  Future<GoogleAuthState> reconnect() async {
    await disconnect();
    return connect();
  }

  @override
  Future<void> disconnect() async {
    final refreshToken = await _store.read(googleRefreshTokenStorageKey);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _revokeToken(refreshToken);
      } catch (_) {
        // La révocation distante ne doit pas bloquer l’effacement local.
      }
    }
    await _store.delete(googleRefreshTokenStorageKey);
    await _store.delete(googleAccountEmailStorageKey);
  }

  Future<String> senderAddress() async {
    final state = await currentState();
    final email = state.accountEmail;
    if (!state.isConnected || email == null) {
      throw const GoogleSessionDisconnected();
    }
    return email;
  }

  Future<AuthClient> authorizedClient() async {
    if (!_desktopClient.isConfigured) {
      throw const GoogleOAuthClientNotConfigured();
    }
    final refreshToken = await _store.read(googleRefreshTokenStorageKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const GoogleSessionDisconnected();
    }
    try {
      return await _openRefreshClient(
        clientId: _clientId,
        refreshToken: refreshToken,
        scopes: googleMailSendScopes,
      );
    } on AccessDeniedException {
      throw const GoogleSessionDisconnected();
    } catch (_) {
      throw const GoogleAuthorizationFailed();
    }
  }
}

Future<AccessCredentials> _defaultObtainConsent({
  required ClientId clientId,
  required List<String> scopes,
  required void Function(String url) prompt,
}) {
  final client = http.Client();
  return obtainAccessCredentialsViaUserConsent(
    clientId,
    scopes,
    client,
    prompt,
  ).whenComplete(client.close);
}

Future<AuthClient> _defaultOpenRefreshClient({
  required ClientId clientId,
  required String refreshToken,
  required List<String> scopes,
}) {
  return clientViaRefreshToken(clientId, refreshToken, scopes);
}

Future<void> _defaultRevokeToken(String token) async {
  final client = http.Client();
  try {
    await client.post(
      Uri.parse('https://oauth2.googleapis.com/revoke'),
      body: {'token': token},
    );
  } finally {
    client.close();
  }
}

Future<bool> _defaultOpenAuthorizationUrl(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

Future<String?> _emailFromUserInfo(String accessToken) async {
  final client = http.Client();
  try {
    final response = await client.get(
      Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      return null;
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final email = json['email'];
    if (email is! String || email.isEmpty) {
      return null;
    }
    return email;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

String? _emailFromIdToken(String? idToken) {
  if (idToken == null || idToken.isEmpty) {
    return null;
  }
  final parts = idToken.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final email = json['email'];
    if (email is! String || email.isEmpty) {
      return null;
    }
    return email;
  } catch (_) {
    return null;
  }
}
