import 'dart:convert';

import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/infrastructure/google/android_google_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('autorisation existante : identité Google et renouvellement via SDK', () async {
    var token = 'sdk-token-1';
    final scopesRequested = <List<String>>[];
    final receivedTokens = <String?>[];
    final cleared = <String>[];
    final account = await restoreGoogleAuthorization(
      authorize: (scopes) async {
        scopesRequested.add(scopes);
        return token;
      },
      clearToken: (value) async => cleared.add(value),
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://www.googleapis.com/oauth2/v3/userinfo');
        receivedTokens.add(request.headers['Authorization']);
        return http.Response(jsonEncode({
          'sub': 'google-account-id',
          'email': 'accord@example.com',
          'email_verified': true,
        }), 200);
      }),
    );
    expect(account, isNotNull);
    expect(account!.id, 'google-account-id');
    expect(account.email, 'accord@example.com');
    token = 'sdk-token-2';
    expect(await account.accessToken(googleAndroidScopes, interactive: false), token);
    expect(scopesRequested, [googleAndroidScopes, googleAndroidScopes]);
    expect(receivedTokens, ['Bearer sdk-token-1', 'Bearer sdk-token-2']);
    await account.clearToken(token);
    expect(cleared, ['sdk-token-2']);
  });

  test('consentement requis : aucune requête userinfo ni interaction de secours', () async {
    final account = await restoreGoogleAuthorization(
      authorize: (_) async => null,
      clearToken: (_) async => fail('invalidation inattendue'),
      clientFactory: () => throw StateError('aucun HTTP attendu'),
    );
    expect(account, isNull);
  });

  test('changement de compte SDK : le nouveau token ne peut pas servir à envoyer', () async {
    var id = 'original-account';
    final account = await restoreGoogleAuthorization(
      authorize: (_) async => 'sdk-token',
      clearToken: (_) async {},
      clientFactory: () => MockClient((_) async => http.Response(jsonEncode({
        'sub': id, 'email': '$id@example.com', 'email_verified': true,
      }), 200)),
    );
    expect(account!.id, 'original-account');
    id = 'other-account';
    expect(await account.accessToken(googleAndroidScopes, interactive: false), isNull);
  });

  for (final status in [401, 403]) {
    test('userinfo $status : session non restaurable', () async {
      expect(await restoreGoogleAuthorization(
        authorize: (_) async => 'sdk-token',
        clearToken: (_) async {},
        clientFactory: () => MockClient((_) async => http.Response('', status)),
      ), isNull);
    });
  }

  for (final body in ['{}', '{"sub":"id","email":"mail@example.com"}']) {
    test('identité incomplète ou non vérifiée refusée : $body', () async {
      await expectLater(restoreGoogleAuthorization(
        authorize: (_) async => 'sdk-token',
        clearToken: (_) async {},
        clientFactory: () => MockClient((_) async => http.Response(body, 200)),
      ), throwsA(isA<GoogleAuthorizationFailed>()));
    });
  }

  test('indisponibilité Google : erreur temporaire distincte d’un refus', () async {
    await expectLater(restoreGoogleAuthorization(
      authorize: (_) async => 'sdk-token',
      clearToken: (_) async {},
      clientFactory: () => MockClient((_) async => http.Response('', 503)),
    ), throwsA(isA<GoogleAuthorizationFailed>()));
  });
}
