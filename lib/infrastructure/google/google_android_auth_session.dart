import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../application/ports/google_auth_session.dart';
import '../../application/ports/secret_store.dart';
import 'android_google_sign_in.dart';
import 'google_authorized_session.dart';

export 'android_google_sign_in.dart' show googleAndroidScopes;

const googleAndroidAccountStorageKey = 'accord_memo.google.android.account_id';
const googleAndroidServerClientId = String.fromEnvironment(
  'ACCORD_MEMO_GOOGLE_ANDROID_SERVER_CLIENT_ID',
);

final class GoogleAndroidAuthSession implements GoogleAuthorizedSession {
  GoogleAndroidAuthSession({
    required this._signIn,
    required this._store,
    required this._serverClientId,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final AndroidGoogleSignIn _signIn;
  final SecretStore _store;
  final String _serverClientId;
  final http.Client Function() _clientFactory;
  AndroidGoogleAccount? _account;
  bool _explicitlyDisconnected = false;
  Future<void> _pending = Future<void>.value();

  // Sérialise restauration, connexion et logout pour empêcher une restauration
  // en cours de rétablir la session après une déconnexion explicite.
  Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) async {
      try {
        return await action();
      } on GoogleAuthException {
        rethrow;
      } on GoogleSignInException catch (error) {
        throw switch (error.code) {
          GoogleSignInExceptionCode.canceled =>
            const GoogleAuthorizationCancelled(),
          GoogleSignInExceptionCode.clientConfigurationError =>
            const GoogleOAuthClientNotConfigured(),
          _ => const GoogleAuthorizationFailed(),
        };
      } catch (_) {
        throw const GoogleAuthorizationFailed();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _initialize() async {
    if (_serverClientId.trim().isEmpty) {
      throw const GoogleOAuthClientNotConfigured();
    }
    await _signIn.initialize();
  }

  Future<AndroidGoogleAccount?> _restore() async {
    if (_account != null || _explicitlyDisconnected) {
      return _account;
    }
    final savedId = await _store.read(googleAndroidAccountStorageKey);
    if (savedId == null || _serverClientId.trim().isEmpty) {
      return null;
    }
    await _initialize();
    final restored = await _signIn.restore();
    if (restored != null && restored.id == savedId) {
      _account = restored;
    }
    return _account;
  }

  Future<GoogleAuthState> _state() async {
    final account = await _restore();
    if (account == null) {
      return const GoogleAuthState.disconnected();
    }
    final token = await account.accessToken(
      googleAndroidScopes,
      interactive: false,
    );
    if (token == null || token.isEmpty) {
      _account = null;
      return const GoogleAuthState.disconnected();
    }
    return GoogleAuthState.connected(account.email);
  }

  @override
  Future<GoogleAuthState> currentState() => _run(_state);

  Future<GoogleAuthState> _connect() async {
    await _initialize();
    await _disconnect();
    final account = await _signIn.authenticate();
    final token = await account.accessToken(
      googleAndroidScopes,
      interactive: true,
    );
    if (account.id.isEmpty ||
        account.email.isEmpty ||
        token == null ||
        token.isEmpty) {
      throw const GoogleAuthorizationFailed();
    }
    // Seul l'identifiant du compte autorisé est persistant. Aucun token OAuth
    // n'est confié au stockage applicatif ; Google gère son renouvellement.
    await _store.write(googleAndroidAccountStorageKey, account.id);
    _account = account;
    _explicitlyDisconnected = false;
    return GoogleAuthState.connected(account.email);
  }

  @override
  Future<GoogleAuthState> connect() => _run(_connect);

  @override
  Future<GoogleAuthState> reconnect() => _run(_connect);

  Future<void> _disconnect() async {
    _account = null;
    _explicitlyDisconnected = true;
    await _store.delete(googleAndroidAccountStorageKey);
    if (_serverClientId.trim().isNotEmpty) {
      await _initialize();
      // signOut efface la session SDK sans révoquer le consentement Google.
      await _signIn.signOut();
    }
  }

  @override
  Future<void> disconnect() => _run(_disconnect);

  @override
  Future<String> senderAddress() => _run(() async {
    final state = await _state();
    if (!state.isConnected) {
      throw const GoogleSessionDisconnected();
    }
    return state.accountEmail!;
  });

  @override
  Future<http.Client> authorizedClient() => _run(() async {
    final account = await _restore();
    if (account == null) {
      throw const GoogleSessionDisconnected();
    }
    final token = await account.accessToken(
      googleAndroidScopes,
      interactive: false,
    );
    if (token == null || token.isEmpty) {
      _account = null;
      throw const GoogleSessionDisconnected();
    }
    return _GoogleTokenClient(_clientFactory(), account, token);
  });
}

final class _GoogleTokenClient extends http.BaseClient {
  _GoogleTokenClient(this._inner, this._account, this._token);

  final http.Client _inner;
  final AndroidGoogleAccount _account;
  final String _token;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer $_token';
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      await response.stream.drain<void>();
      try {
        await _account.clearToken(_token);
      } catch (_) {
        throw const GoogleSessionDisconnected();
      }
      // Aucun rejeu automatique d'un envoi de mail : éviter les doublons.
      throw const GoogleSessionDisconnected();
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
