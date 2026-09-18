import 'dart:io';

import 'package:accord_memo/application/backup/app_database_session.dart';
import 'package:accord_memo/application/backup/backup_outcome.dart';
import 'package:accord_memo/application/backup/file_location_picker.dart';
import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/application/history/history_kind.dart';
import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_activity_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_reminder_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_tuning_repository.dart';
import 'package:accord_memo/presentation/app_database_holder.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/clients/clients_providers.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/history/history_strings.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:accord_memo/presentation/settings/settings_strings.dart';
import 'package:accord_memo/presentation/shell/app_shell.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fake_app_data_locator.dart';
import '../support/fake_file_location_picker.dart';
import '../support/fake_id_generator.dart';
import '../support/file_app_database.dart';
import '../support/fixed_clock.dart';

final _clock = FixedClock(DateTime(2026, 9, 18, 14, 30));

void main() {
  Future<void> prepareDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('affiche Données sans jargon technique', (tester) async {
    await prepareDesktop(tester);
    await tester.pumpWidget(_displaySettingsApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();

    expect(find.text(settingsPageTitle), findsWidgets);
    expect(find.text(settingsDataSectionTitle), findsOneWidget);
    expect(find.text(settingsLocalOnlyMessage), findsOneWidget);
    expect(find.text(settingsLocationLabel), findsOneWidget);
    expect(
      find.text(r'C:\Users\Eleonore\AppData\Roaming\AccordMemo'),
      findsOneWidget,
    );
    expect(find.text(settingsBackupButton), findsOneWidget);
    expect(find.text(settingsRestoreButton), findsOneWidget);
    expect(find.text('SQLite'), findsNothing);
    expect(find.text('WAL'), findsNothing);
    expect(find.text('SHM'), findsNothing);
    expect(find.text('schemaVersion'), findsNothing);
    expect(find.text('VACUUM'), findsNothing);
    expect(find.text('Drift'), findsNothing);
    expect(
      find.text('Cette section sera disponible prochainement.'),
      findsNothing,
    );
  });

  testWidgets('annuler Enregistrer sous ne change rien et n’affiche pas d’erreur', (
    tester,
  ) async {
    await prepareDesktop(tester);
    final picker = FakeFileLocationPicker();

    await tester.pumpWidget(_idleSettingsApp(picker: picker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(settingsBackupButton));
    await tester.pump();
    await tester.pump();

    expect(find.text(settingsBackupSuccess), findsNothing);
    expect(find.text(settingsBackupError), findsNothing);
    expect(find.text(settingsWorking), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, settingsBackupButton),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, settingsRestoreButton),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      picker.lastSuggestedFileName,
      'AccordMemo_backup_2026-09-18_14-30.db',
    );
  });

  testWidgets('désactive les boutons pendant une opération', (tester) async {
    await prepareDesktop(tester);
    final picker = PendingFileLocationPicker();

    await tester.pumpWidget(_idleSettingsApp(picker: picker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramètres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(settingsBackupButton));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, settingsBackupButton),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, settingsRestoreButton),
          )
          .onPressed,
      isNull,
    );
    expect(find.text(settingsWorking), findsOneWidget);

    picker.save.complete(null);
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, settingsBackupButton),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text(settingsWorking), findsNothing);
  });

  testWidgets('restore confirme, remplace les données et nettoie la sélection', (
    tester,
  ) async {
    await prepareDesktop(tester);
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('accord_memo_settings_restore_'),
    );
    expect(directory, isNotNull);
    final live = File(p.join(directory!.path, 'accord_memo.db'));
    final backup = File(p.join(directory.path, 'source.db'));
    final picker = FakeFileLocationPicker(openPath: backup.path);

    await tester.pumpWidget(
      _liveSettingsApp(live: live, picker: picker),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    addTearDown(
      () => tester.runAsync(() async {
        await container.read(appDatabaseProvider).close();
        await directory.delete(recursive: true);
      }),
    );

    Future<void> resolveShellQueries() async {
      await tester.runAsync(() async {
        await container.read(dashboardSnapshotProvider.future);
        await container.read(historySnapshotProvider.future);
        await container.read(clientsSearchProvider.future);
      });
      await tester.pump();
    }

    await resolveShellQueries();

    await tester.runAsync(() async {
      await _seedLiveWorld(container.read(appDatabaseProvider));
      await container.read(dataBackupServiceProvider).backup(
        destinationPath: backup.path,
      );
      await DriftCustomerRepository(container.read(appDatabaseProvider)).insert(
        Customer.create(
          id: CustomerId('22222222-2222-4222-8222-222222222222'),
          lastName: 'Martin',
          now: _clock.now(),
        ),
      );
    });
    container.invalidate(clientsSearchProvider);
    container.invalidate(dashboardSnapshotProvider);
    container.invalidate(historySnapshotProvider);
    await resolveShellQueries();

    await tester.tap(find.text('Clients & Pianos'));
    await tester.pump();
    await tester.tap(find.text('Martin'));
    await tester.runAsync(() async {
      await container.read(selectedCustomerPianosProvider.future);
      await container.read(selectedCustomerLatestTuningDatesProvider.future);
    });
    await tester.pump();
    expect(container.read(selectedCustomerIdProvider), isNotNull);

    await tester.tap(find.text('Paramètres'));
    await tester.pump();
    await tester.tap(find.text(settingsRestoreButton));
    await tester.pump();
    expect(find.text(settingsRestoreBody), findsOneWidget);
    expect(find.text(settingsRestoreConfirm), findsOneWidget);

    final previous = container.read(appDatabaseProvider);
    await tester.tap(find.text(settingsCancel));
    await tester.pump();

    await tester.runAsync(() async {
      expect(
        await container.read(dataBackupServiceProvider).restore(
          sourcePath: backup.path,
        ),
        RestoreOutcome.completed,
      );
    });
    final renewed = container.read(appDatabaseProvider);
    expect(identical(previous, renewed), isFalse);

    container.read(selectedCustomerIdProvider.notifier).clear();
    container.invalidate(dashboardSnapshotProvider);
    container.invalidate(clientsSearchProvider);
    container.invalidate(selectedCustomerPianosProvider);
    container.invalidate(selectedCustomerLatestTuningDatesProvider);
    container.invalidate(historySnapshotProvider);

    await tester.runAsync(() async {
      await renewed.customSelect('SELECT 1').getSingle();
      expect(await _lastNames(renewed), ['Dupont']);
      final dashboard = await container.read(dashboardSnapshotProvider.future);
      expect(dashboard.dueSoon, hasLength(1));
      expect(dashboard.dueSoon.single.lastName, 'Dupont');
      final history = await container.read(historySnapshotProvider.future);
      expect(history, hasLength(1));
      expect(history.single.kind, HistoryKind.tuningCreated);
      final latest = await container
          .read(latestPianoTuningQueryProvider)
          .findLatestDatesByCustomerId(
            CustomerId('11111111-1111-4111-8111-111111111111'),
          );
      expect(
        latest[PianoId('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')],
        CalendarDate(2026, 1, 15),
      );
      await container.read(clientsSearchProvider.future);
    });
    await tester.pump();

    expect(container.read(selectedCustomerIdProvider), isNull);
    expect(find.text('Martin'), findsNothing);

    await tester.tap(find.text('Aujourd’hui'));
    await tester.pump();
    await tester.runAsync(() async {
      await container.read(dashboardSnapshotProvider.future);
    });
    await tester.pump();
    expect(find.text('Dupont'), findsWidgets);
    expect(find.text('Martin'), findsNothing);

    await tester.tap(find.text('Historique'));
    await tester.pump();
    await tester.runAsync(() async {
      await container.read(historySnapshotProvider.future);
    });
    await tester.pump();
    expect(find.text(historyKindTuningCreated), findsOneWidget);

    await tester.tap(find.text('Clients & Pianos'));
    await tester.pump();
    expect(find.text(clientsSelectPrompt), findsOneWidget);
    await tester.tap(find.text('Dupont'));
    await tester.runAsync(() async {
      await container.read(selectedCustomerPianosProvider.future);
      await container.read(selectedCustomerLatestTuningDatesProvider.future);
    });
    await tester.pump();
    expect(find.text('${clientsLastTuningPrefix}15/01/2026'), findsOneWidget);
  });
}

Widget _idleSettingsApp({required FileLocationPicker picker}) {
  return ProviderScope(
    overrides: [
      dashboardSnapshotProvider.overrideWith((ref) async => _emptyDashboard),
      clientsSearchProvider.overrideWith((ref) async => <Customer>[]),
      historySnapshotProvider.overrideWith(
        (ref) async => const <HistoryEntry>[],
      ),
      appDataLocatorProvider.overrideWith(
        (ref) => FakeAppDataLocator.displayOnly(),
      ),
      fileLocationPickerProvider.overrideWith((ref) => picker),
      clockProvider.overrideWith((ref) => _clock),
      appDatabaseSessionProvider.overrideWith((ref) => const _IdleSession()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const AppShell(),
    ),
  );
}

final class _IdleSession implements AppDatabaseSession {
  const _IdleSession();

  @override
  Future<void> exportSnapshot(String destinationPath) async {}

  @override
  Future<void> closeForReplacement() async {}

  @override
  Future<void> openAfterReplacement() async {}
}

Widget _displaySettingsApp() {
  return ProviderScope(
    overrides: [
      dashboardSnapshotProvider.overrideWith((ref) async => _emptyDashboard),
      clientsSearchProvider.overrideWith((ref) async => <Customer>[]),
      historySnapshotProvider.overrideWith(
        (ref) async => const <HistoryEntry>[],
      ),
      appDataLocatorProvider.overrideWith(
        (ref) => FakeAppDataLocator.displayOnly(),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const AppShell(),
    ),
  );
}

Widget _liveSettingsApp({
  required File live,
  required FileLocationPicker picker,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseOpenerProvider.overrideWith(
        (ref) => () => openFileAppDatabase(live),
      ),
      appDataLocatorProvider.overrideWith(
        (ref) => FakeAppDataLocator.fromFile(live),
      ),
      fileLocationPickerProvider.overrideWith((ref) => picker),
      clockProvider.overrideWith((ref) => _clock),
      idGeneratorProvider.overrideWith((ref) => FakeIdGenerator(spareIds())),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const AppShell(),
    ),
  );
}

final _emptyDashboard = DashboardSnapshot(
  today: CalendarDate(2026, 9, 18),
  overdue: const [],
  dueSoon: const [],
  upcoming: const [],
);

Future<void> _seedLiveWorld(AppDatabase database) async {
  final customer = Customer.create(
    id: CustomerId('11111111-1111-4111-8111-111111111111'),
    lastName: 'Dupont',
    now: _clock.now(),
  );
  final piano = Piano.create(
    id: PianoId('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
    customerId: customer.id,
    brand: 'Yamaha',
    now: _clock.now(),
  );
  final tuning = Tuning.create(
    id: TuningId('cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
    pianoId: piano.id,
    tuningDate: CalendarDate(2026, 1, 15),
    today: CalendarDate(2026, 9, 18),
    now: _clock.now(),
  );
  final reminder = Reminder.schedule(
    id: ReminderId('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
    pianoId: piano.id,
    originTuningId: tuning.id,
    dueDate: CalendarDate(2026, 9, 20),
    now: _clock.now(),
  );
  final activity = Activity.tuningCreated(
    id: ActivityId('99999999-9999-4999-8999-999999999999'),
    pianoId: piano.id,
    tuningId: tuning.id,
    now: _clock.now(),
  );
  await DriftCustomerRepository(database).insert(customer);
  await DriftPianoRepository(database).insert(piano);
  await DriftTuningRepository(database).insert(tuning);
  await DriftReminderRepository(database).insert(reminder);
  await DriftActivityRepository(database).insert(activity);
}

Future<List<String>> _lastNames(AppDatabase database) async {
  final rows = await DriftCustomerRepository(database).search(
    filter: CustomerStatusFilter.active,
    query: '',
  );
  return rows.map((customer) => customer.lastName).toList();
}
