final class GoogleAuthState {
  const GoogleAuthState.disconnected()
      : isConnected = false,
        accountEmail = null;

  const GoogleAuthState.connected(this.accountEmail) : isConnected = true;

  final bool isConnected;
  final String? accountEmail;
}

sealed class GoogleAuthException implements Exception {
  const GoogleAuthException();
}

final class GoogleOAuthClientNotConfigured extends GoogleAuthException {
  const GoogleOAuthClientNotConfigured();

  @override
  String toString() => 'GoogleOAuthClientNotConfigured';
}

final class GoogleAuthorizationCancelled extends GoogleAuthException {
  const GoogleAuthorizationCancelled();

  @override
  String toString() => 'GoogleAuthorizationCancelled';
}

final class GoogleAuthorizationFailed extends GoogleAuthException {
  const GoogleAuthorizationFailed();

  @override
  String toString() => 'GoogleAuthorizationFailed';
}

final class GoogleRefreshTokenMissing extends GoogleAuthException {
  const GoogleRefreshTokenMissing();

  @override
  String toString() => 'GoogleRefreshTokenMissing';
}

final class GoogleSessionDisconnected extends GoogleAuthException {
  const GoogleSessionDisconnected();

  @override
  String toString() => 'GoogleSessionDisconnected';
}

/// Session Gmail côté application. Aucun token n’est exposé.
abstract interface class GoogleAuthSession {
  Future<GoogleAuthState> currentState();

  Future<GoogleAuthState> connect();

  Future<GoogleAuthState> reconnect();

  Future<void> disconnect();
}
