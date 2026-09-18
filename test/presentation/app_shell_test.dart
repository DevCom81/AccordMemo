import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/clients/clients_providers.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_strings.dart';
import 'package:accord_memo/presentation/dev/demo_mode.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/history/history_strings.dart';
import 'package:accord_memo/presentation/shell/app_shell.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigue vers les placeholders et recharge Aujourd’hui au retour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var loads = 0;
    var historyLoads = 0;
    final empty = DashboardSnapshot(
      today: CalendarDate(2026, 9, 17),
      overdue: const [],
      dueSoon: const [],
      upcoming: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSnapshotProvider.overrideWith((ref) async {
            loads += 1;
            return empty;
          }),
          clientsSearchProvider.overrideWith((ref) async => <Customer>[]),
          historySnapshotProvider.overrideWith((ref) async {
            historyLoads += 1;
            return const <HistoryEntry>[];
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(historyLoads, 1);
    expect(find.text(dashboardEmptyTitle), findsOneWidget);
    expect(find.text('DÉMO'), findsNothing);

    await tester.tap(find.text('Clients & Pianos'));
    await tester.pumpAndSettle();
    expect(find.text(clientsEmptyActiveTitle), findsOneWidget);
    expect(
      find.text('Cette section sera disponible prochainement.'),
      findsNothing,
    );
    expect(loads, 1);
    expect(historyLoads, 1);

    await tester.tap(find.text('Aujourd’hui'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(historyLoads, 1);
    expect(find.text(dashboardEmptyTitle), findsOneWidget);

    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();
    expect(find.text(historyPageTitle), findsWidgets);
    expect(find.text(historyFilterAll), findsOneWidget);
    expect(find.text(historyEmptyAllTitle), findsOneWidget);
    expect(
      find.text('Cette section sera disponible prochainement.'),
      findsNothing,
    );
    expect(historyLoads, 2);

    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsWidgets);
    expect(
      find.text('Cette section sera disponible prochainement.'),
      findsOneWidget,
    );
    expect(historyLoads, 2);
  });

  testWidgets('affiche le badge DÉMO uniquement si le mode démo est actif', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final empty = DashboardSnapshot(
      today: CalendarDate(2026, 9, 17),
      overdue: const [],
      dueSoon: const [],
      upcoming: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSnapshotProvider.overrideWith((ref) async => empty),
          clientsSearchProvider.overrideWith((ref) async => <Customer>[]),
          historySnapshotProvider.overrideWith(
            (ref) async => const <HistoryEntry>[],
          ),
          demoModeProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DÉMO'), findsOneWidget);
    expect(find.bySemanticsLabel('Mode démonstration'), findsOneWidget);
  });

  testWidgets('n’overflow pas lorsque la sidebar n’a que ~289 px de haut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 337);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final empty = DashboardSnapshot(
      today: CalendarDate(2026, 9, 17),
      overdue: const [],
      dueSoon: const [],
      upcoming: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSnapshotProvider.overrideWith((ref) async => empty),
          clientsSearchProvider.overrideWith((ref) async => <Customer>[]),
          historySnapshotProvider.overrideWith(
            (ref) async => const <HistoryEntry>[],
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Clients & Pianos'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Saison 2026-2027'), findsOneWidget);
  });
}
