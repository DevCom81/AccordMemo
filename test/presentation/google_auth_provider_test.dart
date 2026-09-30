import 'package:accord_memo/infrastructure/google/fake_google_auth_session.dart';
import 'package:accord_memo/infrastructure/google/google_android_auth_session.dart';
import 'package:accord_memo/infrastructure/google/google_apis_auth_session.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/dev/demo_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_secret_store.dart';

void main() {
  for (final android in [false, true]) {
    test('sélection OAuth ${android ? 'Android' : 'Windows'} sans appel natif', () {
      final container = ProviderContainer(overrides: [
        googleAuthOnAndroidProvider.overrideWithValue(android),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ]);
      addTearDown(container.dispose);
      final session = container.read(googleAuthSessionProvider);
      expect(session, android
          ? isA<GoogleAndroidAuthSession>() : isA<GoogleApisAuthSession>());
      expect(identical(session, container.read(googleAuthorizedSessionProvider)),
          isTrue);
    });
  }

  test('démo Android garde la session factice', () {
    final container = ProviderContainer(overrides: [
      demoModeProvider.overrideWithValue(true),
      googleAuthOnAndroidProvider.overrideWithValue(true),
    ]);
    addTearDown(container.dispose);
    expect(container.read(googleAuthSessionProvider), isA<FakeGoogleAuthSession>());
  });
}
