import 'dart:async';
import 'dart:io';

import 'package:accord_memo/application/backup/app_database_session.dart';
import 'package:accord_memo/application/backup/backup_exceptions.dart';
import 'package:accord_memo/application/backup/backup_outcome.dart';
import 'package:accord_memo/application/backup/backup_store.dart';
import 'package:accord_memo/application/backup/backup_validator.dart';
import 'package:accord_memo/application/backup/data_backup_service.dart';
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
import 'package:accord_memo/infrastructure/persistence/filesystem_backup_store.dart';
import 'package:accord_memo/infrastructure/persistence/sqlite_backup_validator.dart';
import 'package:accord_memo/presentation/app_database_holder.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../support/fake_app_data_locator.dart';
import '../support/fake_file_location_picker.dart';
import '../support/fake_id_generator.dart';
import '../support/file_app_database.dart';
import '../support/fixed_clock.dart';

final _clock = FixedClock(DateTime(2026, 9, 18, 14, 30));
const _validator = SqliteBackupValidator();
const _store = FilesystemBackupStore();

void main() {
  Future<Directory> tempDir() async {
    final directory = await Directory.systemTemp.createTemp(
      'accord_memo_backup_',
    );
    addTearDown(() => directory.delete(recursive: true));
    return directory;
  }

  test('annuler le dialogue de copie ne change rien', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'accord_memo.db'));
    final container = _container(live: live);
    final picker = FakeFileLocationPicker();
    final service = _service(
      container: container,
      live: live,
      picker: picker,
    );

    await _insertCustomer(container.read(appDatabaseProvider), lastName: 'Dupont');

    expect(await service.backup(), BackupOutcome.cancelled);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('AccordMemo_backup_')),
      isEmpty,
    );
    expect(
      await _lastNames(container.read(appDatabaseProvider)),
      ['Dupont'],
    );
  });

  test('sauvegarde atomique : destination existante intacte si la nouvelle copie échoue', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'accord_memo.db'));
    final dest = File(p.join(directory.path, 'AccordMemo_backup_2026-09-18_14-30.db'));
    final container = _container(live: live);
    final session = container.read(appDatabaseSessionProvider);

    await _insertCustomer(container.read(appDatabaseProvider), lastName: 'Dupont');
    final okService = DataBackupService(
      clock: _clock,
      idGenerator: FakeIdGenerator(spareIds()),
      locator: FakeAppDataLocator.fromFile(live),
      picker: FakeFileLocationPicker(),
      validator: _validator,
      store: _store,
      session: session,
    );
    expect(
      await okService.backup(destinationPath: dest.path),
      BackupOutcome.completed,
    );

    await _insertCustomer(
      container.read(appDatabaseProvider),
      id: '22222222-2222-4222-8222-222222222222',
      lastName: 'Martin',
    );

    final failingService = DataBackupService(
      clock: _clock,
      idGenerator: FakeIdGenerator(spareIds(8)),
      locator: FakeAppDataLocator.fromFile(live),
      picker: FakeFileLocationPicker(),
      validator: _RejectExportValidator(_validator),
      store: _store,
      session: session,
    );

    await expectLater(
      failingService.backup(destinationPath: dest.path),
      throwsA(isA<BackupFileInvalid>()),
    );

    expect(await dest.exists(), isTrue);
    expect(_lastNamesFromSqliteFile(dest), ['Dupont']);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .any((file) => p.basename(file.path).contains('.export-')),
      isFalse,
    );
  });

  test('restore renouvelle le provider et relit dashboard, historique et dernier accord', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'accord_memo.db'));
    final backup = File(p.join(directory.path, 'source.db'));
    final container = _container(live: live);
    final service = _service(container: container, live: live);

    await _seedLiveWorld(container.read(appDatabaseProvider));
    expect(
      await service.backup(destinationPath: backup.path),
      BackupOutcome.completed,
    );

    await _insertCustomer(
      container.read(appDatabaseProvider),
      id: '22222222-2222-4222-8222-222222222222',
      lastName: 'Martin',
    );

    final previous = container.read(appDatabaseProvider);
    expect(await _lastNames(previous), containsAll(['Dupont', 'Martin']));

    await container.read(dashboardSnapshotProvider.future);
    await container.read(historySnapshotProvider.future);

    expect(
      await service.restore(sourcePath: backup.path),
      RestoreOutcome.completed,
    );

    final renewed = container.read(appDatabaseProvider);
    expect(identical(previous, renewed), isFalse);
    expect(await _lastNames(renewed), ['Dupont']);
    expect(await _lastNames(renewed), isNot(contains('Martin')));

    container.invalidate(dashboardSnapshotProvider);
    container.invalidate(historySnapshotProvider);
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
  });

  test('rollback après échec post-fermeture restaure les données originales', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'accord_memo.db'));
    final source = File(p.join(directory.path, 'source.db'));
    await _writeMigratedDatabase(source);

    final container = _container(live: live);
    await _insertCustomer(container.read(appDatabaseProvider), lastName: 'Dupont');

    final previous = container.read(appDatabaseProvider);
    final failingStore = _FailingFirstMaterializeStore(_store);
    final service = DataBackupService(
      clock: _clock,
      idGenerator: FakeIdGenerator(spareIds()),
      locator: FakeAppDataLocator.fromFile(live),
      picker: FakeFileLocationPicker(),
      validator: _validator,
      store: failingStore,
      session: container.read(appDatabaseSessionProvider),
    );

    await expectLater(
      service.restore(sourcePath: source.path),
      throwsA(isA<RestoreRolledBack>()),
    );

    final reopened = container.read(appDatabaseProvider);
    expect(identical(previous, reopened), isFalse);
    expect(await reopened.customSelect('SELECT 1').getSingle(), isNotNull);
    expect(await _lastNames(reopened), ['Dupont']);
    expect(failingStore.materializeCalls, 2);
  });

  test('une copie trop récente est refusée avant fermeture de la base live', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'accord_memo.db'));
    final source = File(p.join(directory.path, 'newer.db'));
    await _writeMigratedDatabase(source, userVersion: 7);

    final container = _container(live: live);
    final service = _service(container: container, live: live);

    await _insertCustomer(container.read(appDatabaseProvider), lastName: 'Dupont');

    final before = container.read(appDatabaseProvider);
    await expectLater(
      service.restore(sourcePath: source.path),
      throwsA(isA<BackupFromNewerApp>()),
    );
    expect(identical(container.read(appDatabaseProvider), before), isTrue);
    expect(await _lastNames(before), ['Dupont']);
  });

  test('une sauvegarde déjà en cours est refusée', () async {
    final hanging = _HangingSession();
    final service = DataBackupService(
      clock: _clock,
      idGenerator: FakeIdGenerator(spareIds()),
      locator: FakeAppDataLocator.displayOnly(),
      picker: FakeFileLocationPicker(),
      validator: _validator,
      store: _store,
      session: hanging,
    );

    final first = service.backup(destinationPath: '/tmp/unused.db');
    await expectLater(
      service.backup(destinationPath: '/tmp/other.db'),
      throwsA(isA<BackupBusy>()),
    );
    hanging.export.completeError(const BackupFileInvalid());
    await expectLater(first, throwsA(isA<BackupFileInvalid>()));
  });
}

ProviderContainer _container({required File live}) {
  final container = ProviderContainer(
    overrides: [
      appDatabaseOpenerProvider.overrideWith(
        (ref) => () => openFileAppDatabase(live),
      ),
      appDataLocatorProvider.overrideWith(
        (ref) => FakeAppDataLocator.fromFile(live),
      ),
      clockProvider.overrideWith((ref) => _clock),
    ],
  );
  addTearDown(() async {
    await container.read(appDatabaseProvider.notifier).closeForReplacement();
    container.dispose();
  });
  return container;
}

DataBackupService _service({
  required ProviderContainer container,
  required File live,
  FakeFileLocationPicker? picker,
  BackupValidator? backupValidator,
  BackupStore? backupStore,
}) {
  return DataBackupService(
    clock: _clock,
    idGenerator: FakeIdGenerator(spareIds()),
    locator: FakeAppDataLocator.fromFile(live),
    picker: picker ?? FakeFileLocationPicker(),
    validator: backupValidator ?? _validator,
    store: backupStore ?? _store,
    session: container.read(appDatabaseSessionProvider),
  );
}

Future<void> _insertCustomer(
  AppDatabase database, {
  String id = '11111111-1111-4111-8111-111111111111',
  String lastName = 'Dupont',
}) {
  return DriftCustomerRepository(database).insert(
    Customer.create(
      id: CustomerId(id),
      lastName: lastName,
      now: _clock.now(),
    ),
  );
}

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

Future<void> _writeMigratedDatabase(File file, {int? userVersion}) async {
  final database = openFileAppDatabase(file);
  try {
    await database.customSelect('SELECT 1').getSingle();
  } finally {
    await database.close();
  }
  if (userVersion == null) {
    return;
  }
  final raw = sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = $userVersion');
  } finally {
    raw.close();
  }
}

List<String> _lastNamesFromSqliteFile(File file) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    final rows = database.select(
      'SELECT last_name FROM customers WHERE archived_at IS NULL',
    );
    return [
      for (final row in rows) row['last_name'] as String,
    ];
  } finally {
    database.close();
  }
}

final class _RejectExportValidator implements BackupValidator {
  const _RejectExportValidator(this._inner);

  final BackupValidator _inner;

  @override
  void validate(String filePath) {
    if (p.basename(filePath).startsWith('accord_memo.export-')) {
      throw const BackupFileInvalid();
    }
    _inner.validate(filePath);
  }
}

final class _FailingFirstMaterializeStore implements BackupStore {
  _FailingFirstMaterializeStore(this._inner);

  final BackupStore _inner;
  var materializeCalls = 0;

  @override
  Future<void> replaceAtomically({
    required String fromTemp,
    required String destination,
  }) {
    return _inner.replaceAtomically(fromTemp: fromTemp, destination: destination);
  }

  @override
  Future<void> deleteDatabaseFiles(String databasePath) {
    return _inner.deleteDatabaseFiles(databasePath);
  }

  @override
  Future<void> materializeBackup({
    required String sourcePath,
    required String liveDatabasePath,
  }) async {
    materializeCalls += 1;
    if (materializeCalls == 1) {
      throw StateError('échec volontaire après fermeture');
    }
    return _inner.materializeBackup(
      sourcePath: sourcePath,
      liveDatabasePath: liveDatabasePath,
    );
  }

  @override
  Future<void> deleteFileIfExists(String path) {
    return _inner.deleteFileIfExists(path);
  }
}

final class _HangingSession implements AppDatabaseSession {
  final export = Completer<void>();

  @override
  Future<void> exportSnapshot(String destinationPath) => export.future;

  @override
  Future<void> closeForReplacement() async {}

  @override
  Future<void> openAfterReplacement() async {}
}
