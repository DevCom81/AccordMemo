import 'dart:convert';

import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/infrastructure/google/google_apis_auth_session.dart';
import 'package:accord_memo/infrastructure/google/google_oauth_desktop_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

import '../support/in_memory_secret_store.dart';

String _idTokenFor(String email) {
  String encode(Map<String, Object> json) {
    return base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  }

  return '${encode({'alg': 'none'})}.${encode({'email': email})}.sig';
}

void main() {
  const client = GoogleOAuthDesktopClient(
    clientId: 'desktop-client-id',
    clientSecret: 'desktop-client-secret',
  );

  test('session restaurée depuis le coffre sans nouveau consentement', () async {
    final store = InMemorySecretStore();
    await store.write(googleRefreshTokenStorageKey, 'refresh-1');
    await store.write(googleAccountEmailStorageKey, 'eleonore@example.com');

    var consentCalls = 0;
    final session = GoogleApisAuthSession(
      desktopClient: client,
      store: store,
      obtainConsent: ({required clientId, required scopes, required prompt}) {
        consentCalls += 1;
        throw StateError('consent should not run');
      },
    );

    final state = await session.currentState();
    expect(state.isConnected, isTrue);
    expect(state.accountEmail, 'eleonore@example.com');
    expect(consentCalls, 0);
  });

  test('disconnect efface les credentials utilisateur', () async {
    final store = InMemorySecretStore();
    await store.write(googleRefreshTokenStorageKey, 'refresh-1');
    await store.write(googleAccountEmailStorageKey, 'eleonore@example.com');
    final revoked = <String>[];

    final session = GoogleApisAuthSession(
      desktopClient: client,
      store: store,
      revokeToken: (token) async => revoked.add(token),
    );

    await session.disconnect();
    expect(await store.read(googleRefreshTokenStorageKey), isNull);
    expect(await store.read(googleAccountEmailStorageKey), isNull);
    expect(revoked, ['refresh-1']);
    expect((await session.currentState()).isConnected, isFalse);
  });

  test('connect stocke le refresh token, pas un access token durable', () async {
    final store = InMemorySecretStore();
    var openedBrowser = false;
    final session = GoogleApisAuthSession(
      desktopClient: client,
      store: store,
      openAuthorizationUrl: (url) async {
        openedBrowser = true;
        return true;
      },
      obtainConsent: ({required clientId, required scopes, required prompt}) async {
        prompt('https://accounts.google.com/o/oauth2/v2/auth');
        return AccessCredentials(
          AccessToken(
            'Bearer',
            'ya29-access-should-not-be-stored',
            DateTime.utc(2026, 9, 17, 12),
          ),
          'refresh-secret',
          googleMailSendScopes,
          idToken: _idTokenFor('eleonore@example.com'),
        );
      },
    );

    final state = await session.connect();
    expect(openedBrowser, isTrue);
    expect(state.accountEmail, 'eleonore@example.com');
    expect(await store.read(googleRefreshTokenStorageKey), 'refresh-secret');
    expect(await store.read(googleAccountEmailStorageKey), 'eleonore@example.com');
    expect(
      store.values.values,
      isNot(contains('ya29-access-should-not-be-stored')),
    );
  });

  test('client OAuth absent refuse la connexion', () async {
    final session = GoogleApisAuthSession(
      desktopClient: const GoogleOAuthDesktopClient(
        clientId: '',
        clientSecret: '',
      ),
      store: InMemorySecretStore(),
    );
    await expectLater(
      session.connect(),
      throwsA(isA<GoogleOAuthClientNotConfigured>()),
    );
  });
}
