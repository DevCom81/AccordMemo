import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../application/ports/google_auth_session.dart';

const googleAndroidScopes = [
  'openid',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/gmail.send',
];

abstract interface class AndroidGoogleAccount {
  String get id;
  String get email;
  Future<String?> accessToken(List<String> scopes, {required bool interactive});
  Future<void> clearToken(String token);
}

/// Frontière native remplaçable dans les tests sans compte ni services Google.
abstract interface class AndroidGoogleSignIn {
  Future<void> initialize();
  Future<AndroidGoogleAccount> authenticate();
  Future<AndroidGoogleAccount?> restore();
  Future<void> signOut();
}

final class NativeAndroidGoogleSignIn implements AndroidGoogleSignIn {
  NativeAndroidGoogleSignIn(this.serverClientId);

  final String serverClientId;
  // Le plugin possède un singleton : son initialisation doit être unique,
  // même si le conteneur de providers est recréé.
  static Future<void>? _initialization;

  @override
  Future<void> initialize() => _initialization ??=
      GoogleSignIn.instance.initialize(serverClientId: serverClientId).catchError(
        (Object error, StackTrace stack) {
          _initialization = null;
          Error.throwWithStackTrace(error, stack);
        },
      );

  @override
  Future<AndroidGoogleAccount> authenticate() async =>
      _NativeAccount(await GoogleSignIn.instance.authenticate());

  @override
  Future<AndroidGoogleAccount?> restore() async {
    // LightweightAuthentication peut afficher une UI sur Android. L'API
    // d'autorisation, elle, retourne null si une interaction est nécessaire.
    final authorization = GoogleSignIn.instance.authorizationClient;
    return restoreGoogleAuthorization(
      authorize: (scopes) async =>
          (await authorization.authorizationForScopes(scopes))?.accessToken,
      clearToken: (token) =>
          authorization.clearAuthorizationToken(accessToken: token),
    );
  }

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();
}

/// Récupère l'identité auprès de Google, jamais depuis un token décodé localement.
/// Le service compare ensuite son identifiant avec celui du stockage sécurisé.
Future<AndroidGoogleAccount?> restoreGoogleAuthorization({
  required Future<String?> Function(List<String>) authorize,
  required Future<void> Function(String) clearToken,
  http.Client Function()? clientFactory,
}) async {
  final factory = clientFactory ?? http.Client.new;
  final token = await authorize(googleAndroidScopes);
  if (token == null || token.isEmpty) {
    return null;
  }
  final identity = await _googleIdentity(token, factory);
  if (identity == null) {
    return null;
  }
  return _RestoredAccount(
    identity.id,
    identity.email,
    authorize,
    clearToken,
    factory,
  );
}

Future<({String id, String email})?> _googleIdentity(
  String token,
  http.Client Function() clientFactory,
) async {
  final client = clientFactory();
  try {
    final response = await client
        .get(
          Uri.https('www.googleapis.com', '/oauth2/v3/userinfo'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401 || response.statusCode == 403) {
      return null;
    }
    if (response.statusCode != 200) {
      throw const GoogleAuthorizationFailed();
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['sub'] is! String ||
        (data['sub'] as String).isEmpty ||
        data['email'] is! String ||
        (data['email'] as String).isEmpty ||
        data['email_verified'] != true) {
      throw const GoogleAuthorizationFailed();
    }
    return (id: data['sub'] as String, email: data['email'] as String);
  } finally {
    client.close();
  }
}

final class _RestoredAccount implements AndroidGoogleAccount {
  _RestoredAccount(
    this.id,
    this.email,
    this._authorize,
    this._clearToken,
    this._clientFactory,
  );

  @override
  final String id;
  @override
  final String email;
  final Future<String?> Function(List<String>) _authorize;
  final Future<void> Function(String) _clearToken;
  final http.Client Function() _clientFactory;

  @override
  Future<String?> accessToken(
    List<String> scopes, {
    required bool interactive,
  }) async {
    // Ne jamais basculer silencieusement vers un autre compte choisi par le SDK.
    // Chaque nouveau token reste géré par Google et son identité est contrôlée.
    final token = await _authorize(scopes);
    if (token == null || token.isEmpty) {
      return null;
    }
    final identity = await _googleIdentity(token, _clientFactory);
    return identity?.id == id && identity?.email == email ? token : null;
  }

  @override
  Future<void> clearToken(String token) => _clearToken(token);
}

final class _NativeAccount implements AndroidGoogleAccount {
  _NativeAccount(this.account);

  final GoogleSignInAccount account;

  @override
  String get id => account.id;

  @override
  String get email => account.email;

  @override
  Future<String?> accessToken(
    List<String> scopes, {
    required bool interactive,
  }) async {
    final authorization = await account.authorizationClient
        .authorizationForScopes(scopes);
    if (authorization != null) {
      return authorization.accessToken;
    }
    if (!interactive) {
      return null;
    }
    return (await account.authorizationClient.authorizeScopes(scopes)).accessToken;
  }

  @override
  Future<void> clearToken(String token) => account.authorizationClient
      .clearAuthorizationToken(accessToken: token);
}
