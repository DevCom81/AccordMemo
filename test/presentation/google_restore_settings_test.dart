import 'dart:async';

import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/settings/settings_page.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:accord_memo/presentation/settings/settings_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final connected in [false, true]) {
    testWidgets('Android : attend la restauration avant état connecté=$connected', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final restored = Completer<GoogleAuthState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          backupOnAndroidProvider.overrideWithValue(true),
          googleAuthOnAndroidProvider.overrideWithValue(true),
          googleAuthStateProvider.overrideWith((ref) => restored.future),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ));
      await tester.pump();
      expect(find.text(settingsMailRestoring), findsOneWidget);
      expect(find.text(settingsMailConnect), findsNothing);
      expect(find.text(settingsMailReconnect), findsNothing);
      restored.complete(connected
          ? const GoogleAuthState.connected('accord@example.com')
          : const GoogleAuthState.disconnected());
      await tester.pumpAndSettle();
      expect(find.text(settingsMailRestoring), findsNothing);
      expect(find.text(connected
          ? '${settingsMailConnectedPrefix}accord@example.com'
          : settingsMailConnect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
