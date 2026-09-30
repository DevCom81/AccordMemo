import 'package:google_sign_in/google_sign_in.dart';

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
      GoogleSignIn.instance.initialize(serverClientId: serverClientId);

  @override
  Future<AndroidGoogleAccount> authenticate() async =>
      _NativeAccount(await GoogleSignIn.instance.authenticate());

  @override
  Future<AndroidGoogleAccount?> restore() async {
    final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    return account == null ? null : _NativeAccount(account);
  }

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();
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
