import '../../application/ports/google_auth_session.dart';

final class FakeGoogleAuthSession implements GoogleAuthSession {
  FakeGoogleAuthSession.disconnected() : _state = const GoogleAuthState.disconnected();

  FakeGoogleAuthSession.connected({required String accountEmail})
      : _state = GoogleAuthState.connected(accountEmail);

  GoogleAuthState _state;
  var connectCalls = 0;
  var disconnectCalls = 0;
  Object? connectError;

  @override
  Future<GoogleAuthState> currentState() async => _state;

  @override
  Future<GoogleAuthState> connect() async {
    connectCalls += 1;
    final error = connectError;
    if (error != null) {
      throw error;
    }
    _state = const GoogleAuthState.connected('eleonore@example.com');
    return _state;
  }

  @override
  Future<GoogleAuthState> reconnect() async {
    await disconnect();
    return connect();
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _state = const GoogleAuthState.disconnected();
  }
}
