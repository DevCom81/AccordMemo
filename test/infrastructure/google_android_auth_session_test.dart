import 'dart:async';

import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/infrastructure/google/android_google_sign_in.dart';
import 'package:accord_memo/infrastructure/google/google_android_auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/in_memory_secret_store.dart';

final class _Account implements AndroidGoogleAccount {
  @override
  String id = 'test-account';
  @override
  String email = 'accord@example.com';
  String? token = 'test-access-token';
  Object? error;
  final requests = <({List<String> scopes, bool interactive})>[];
  final cleared = <String>[];

  @override
  Future<String?> accessToken(List<String> scopes, {
    required bool interactive,
  }) async {
    requests.add((scopes: List.of(scopes), interactive: interactive));
    if (error != null) {
      throw error!;
    }
    return token;
  }

  @override
  Future<void> clearToken(String token) async => cleared.add(token);
}

final class _SignIn implements AndroidGoogleSignIn {
  final account = _Account();
  int initializationCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;
  int authenticateCalls = 0;
  Object? authenticateError;
  Object? signOutError;
  Completer<AndroidGoogleAccount?>? restoration;

  @override
  Future<void> initialize() async {
    initializationCalls++;
  }

  @override
  Future<AndroidGoogleAccount> authenticate() async {
    authenticateCalls++;
    if (authenticateError != null) {
      throw authenticateError!;
    }
    return account;
  }

  @override
  Future<AndroidGoogleAccount?> restore() async {
    restoreCalls++;
    return restoration == null ? account : await restoration!.future;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) {
      throw signOutError!;
    }
  }
}

void main() {
  late _SignIn native;
  late InMemorySecretStore store;
  late GoogleAndroidAuthSession session;

  setUp(() {
    native = _SignIn();
    store = InMemorySecretStore();
    session = GoogleAndroidAuthSession(
      signIn: native,
      store: store,
      serverClientId: 'test-only-web-client',
    );
  });

  test('aucune restauration avant une connexion explicite', () async {
    expect((await session.currentState()).isConnected, isFalse);
    expect(native.initializationCalls, 0);
    expect(native.restoreCalls, 0);
  });

  test('connexion, email, scopes exacts et aucun token persistant', () async {
    final state = await session.connect();
    expect(state.isConnected, isTrue);
    expect(state.accountEmail, 'accord@example.com');
    expect(native.account.requests.single.scopes, [
        'openid',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/gmail.send',
    ]);
    expect(native.account.requests.single.interactive, isTrue);
    expect(store.values, {googleAndroidAccountStorageKey: 'test-account'});
    expect(await session.senderAddress(), state.accountEmail);
    expect(native.account.requests.last.interactive, isFalse);
  });

  test('restauration du même compte avec autorisation sans consentement', () async {
    await store.write(googleAndroidAccountStorageKey, native.account.id);
    expect((await session.currentState()).accountEmail, native.account.email);
    expect((await session.currentState()).isConnected, isTrue);
    expect(native.restoreCalls, 1);
    expect(native.authenticateCalls, 0);
    expect(native.account.requests.every((r) => !r.interactive), isTrue);
  });

  test('ne restaure pas un autre compte', () async {
    await store.write(googleAndroidAccountStorageKey, 'another-account');
    expect((await session.currentState()).isConnected, isFalse);
    expect(native.account.requests, isEmpty);
  });

  test('autorisation absente : déconnecté, aucun consentement automatique', () async {
    await store.write(googleAndroidAccountStorageKey, native.account.id);
    native.account.token = null;
    expect((await session.currentState()).isConnected, isFalse);
    await expectLater(session.authorizedClient(),
        throwsA(isA<GoogleSessionDisconnected>()));
    expect(native.account.requests.every((r) => !r.interactive), isTrue);
  });

  test('logout puis redémarrage ne restaure plus le compte', () async {
    await session.connect();
    await session.disconnect();
    expect(store.values, isEmpty);
    expect((await session.currentState()).isConnected, isFalse);
    final restarted = GoogleAndroidAuthSession(
      signIn: native, store: store, serverClientId: 'test-only-web-client',
    );
    expect((await restarted.currentState()).isConnected, isFalse);
    expect(native.restoreCalls, 0);
    expect(native.signOutCalls, 2);
    expect((await restarted.connect()).isConnected, isTrue);
  });

  test('échec signOut signalé mais état local supprimé', () async {
    await session.connect();
    native.signOutError = StateError('native failure');
    await expectLater(session.disconnect(),
        throwsA(isA<GoogleAuthorizationFailed>()));
    expect(store.values, isEmpty);
    expect((await session.currentState()).isConnected, isFalse);
  });

  test('logout attend la restauration puis efface son résultat', () async {
    await store.write(googleAndroidAccountStorageKey, native.account.id);
    native.restoration = Completer<AndroidGoogleAccount?>();
    final restored = session.currentState();
    final disconnected = session.disconnect();
    native.restoration!.complete(native.account);
    await restored;
    await disconnected;
    expect((await session.currentState()).isConnected, isFalse);
    expect(store.values, isEmpty);
  });

  test('configuration absente : erreur applicative sans appel natif', () async {
    final unconfigured = GoogleAndroidAuthSession(
      signIn: native, store: store, serverClientId: '',
    );
    await expectLater(unconfigured.connect(),
        throwsA(isA<GoogleOAuthClientNotConfigured>()));
    expect(native.initializationCalls, 0);
  });

  for (final entry in <GoogleSignInExceptionCode, Matcher>{
    GoogleSignInExceptionCode.canceled: isA<GoogleAuthorizationCancelled>(),
    GoogleSignInExceptionCode.clientConfigurationError:
        isA<GoogleOAuthClientNotConfigured>(),
    GoogleSignInExceptionCode.unknownError: isA<GoogleAuthorizationFailed>(),
  }.entries) {
    test('erreur native traduite : ${entry.key}', () async {
      native.authenticateError = GoogleSignInException(code: entry.key);
      await expectLater(session.connect(), throwsA(entry.value));
      expect((await session.currentState()).isConnected, isFalse);
      expect(store.values, isEmpty);
    });
  }

  test('annulation du consentement après identité : aucune session', () async {
    native.account.error = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    await expectLater(session.connect(),
        throwsA(isA<GoogleAuthorizationCancelled>()));
    expect((await session.currentState()).isConnected, isFalse);
    expect(store.values, isEmpty);
  });

  test('reconnexion annulée ne rétablit pas l’ancien compte', () async {
    await session.connect();
    native.authenticateError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    await expectLater(session.reconnect(),
        throwsA(isA<GoogleAuthorizationCancelled>()));
    expect((await session.currentState()).isConnected, isFalse);
    expect(store.values, isEmpty);
  });

  test('chaque client redemande un token au SDK sans consentement', () async {
    final tokens = <String?>[];
    session = GoogleAndroidAuthSession(
      signIn: native, store: store, serverClientId: 'test-only-web-client',
      clientFactory: () => MockClient((request) async {
        tokens.add(request.headers['Authorization']);
        return http.Response('{}', 200);
      }),
    );
    await session.connect();
    for (final token in ['first-token', 'renewed-token']) {
      native.account.token = token;
      final client = await session.authorizedClient();
      try {
        await client.get(Uri.https('gmail.googleapis.com', '/'));
      } finally {
        client.close();
      }
    }
    expect(tokens, ['Bearer first-token', 'Bearer renewed-token']);
    expect(native.account.requests.skip(1).every((r) => !r.interactive), isTrue);
    expect(store.values, {googleAndroidAccountStorageKey: 'test-account'});
  });

  test('client Gmail utilise un token SDK, invalide un 401 sans rejeu', () async {
    var requests = 0;
    session = GoogleAndroidAuthSession(
      signIn: native, store: store, serverClientId: 'test-only-web-client',
      clientFactory: () => MockClient((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer test-access-token');
        return http.Response('', 401);
      }),
    );
    await session.connect();
    final client = await session.authorizedClient();
    try {
      await expectLater(client.post(Uri.https('gmail.googleapis.com', '/')),
          throwsA(isA<GoogleSessionDisconnected>()));
    } finally {
      client.close();
    }
    expect(requests, 1);
    expect(native.account.cleared, ['test-access-token']);
  });
}
