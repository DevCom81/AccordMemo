import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/main.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/clients/clients_providers.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app_data_locator.dart';
import 'support/fake_mail_overrides.dart';

void main() {
  testWidgets('démarre AccordMémo sur le tableau de bord', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSnapshotProvider.overrideWith((ref) async {
            return DashboardSnapshot(
              today: CalendarDate(2026, 9, 17),
              overdue: const [],
              dueSoon: const [],
              upcoming: const [],
            );
          }),
          clientsSearchProvider.overrideWith((ref) async => <Customer>[]),
          historySnapshotProvider.overrideWith(
            (ref) async => const <HistoryEntry>[],
          ),
          appDataLocatorProvider.overrideWith(
            (ref) => FakeAppDataLocator.displayOnly(),
          ),
          ...fakeMailOverrides(),
        ],
        child: const AccordMemoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Pianos d’Occitanie'), findsOneWidget);
  });
}
