import 'dart:async';
import 'dart:io';

import 'package:accord_memo/application/backup/app_database_session.dart';
import 'package:accord_memo/application/backup/backup_exceptions.dart';
import 'package:accord_memo/application/backup/backup_file_access.dart';
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

  test('document : export SQLite valide avant publication et nettoyage', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'live.db'));
    final document = File(p.join(directory.path, 'document.db'));
    final selection = _TestSelection(
      File(p.join(directory.path, 'stage.db')),
      destination: document,
    );
    final access = _TestFileAccess(save: selection);
    final container = _container(live: live);
    await _seedLiveWorld(container.read(appDatabaseProvider));
    final before = container.read(appDatabaseProvider);
    final service = _service(container: container, live: live, fileAccess: access);

    expect(await service.backup(), BackupOutcome.completed);
    expect(access.suggestedName, 'AccordMemo_backup_2026-09-18_14-30.db');
    expect(selection.events, ['commit', 'dispose']);
    expect(selection.file.existsSync(), isFalse);
    expect(() => _validator.validate(document.path), returnsNormally);
    expect(_lastNamesFromSqliteFile(document), ['Dupont']);
    expect(identical(before, container.read(appDatabaseProvider)), isTrue);
    expect(await _lastNames(before), ['Dupont']);
  });

  test('document : annuler les sélecteurs ne touche pas la base', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'live.db'));
    final container = _container(live: live);
    await _insertCustomer(container.read(appDatabaseProvider));
    final session = _RecordingSession(container.read(appDatabaseSessionProvider));
    final service = _service(
      container: container, live: live,
      fileAccess: _TestFileAccess(), session: session,
    );
    expect(await service.backup(), BackupOutcome.cancelled);
    expect(await service.restore(confirm: () async => fail('confirmation')),
        RestoreOutcome.cancelled);
    expect(session.events, isEmpty);
    expect(await _lastNames(container.read(appDatabaseProvider)), ['Dupont']);
  });

  test('document : erreur écriture, nettoyage et données intactes', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'live.db'));
    final container = _container(live: live);
    await _insertCustomer(container.read(appDatabaseProvider));
    final selection = _TestSelection(
      File(p.join(directory.path, 'stage.db')), failCommit: true,
    );
    final service = _service(
      container: container, live: live,
      fileAccess: _TestFileAccess(save: selection),
    );
    await expectLater(service.backup(), throwsA(isA<FileSystemException>()));
    expect(selection.events, ['commit', 'dispose']);
    expect(selection.file.existsSync(), isFalse);
    expect(await _lastNames(container.read(appDatabaseProvider)), ['Dupont']);
    // Le verrou est libéré après l'erreur.
    expect(await service.restore(), RestoreOutcome.cancelled);
  });

  for (final kind in ['invalide', 'incompatible', 'tables absentes']) {
    test('document $kind refusé avant confirmation et fermeture', () async {
      final directory = await tempDir();
      final live = File(p.join(directory.path, 'live.db'));
      final source = File(p.join(directory.path, 'stage.db'));
      if (kind == 'incompatible') {
        await _writeMigratedDatabase(source, userVersion: 7);
      } else if (kind == 'tables absentes') {
        final raw = sqlite3.open(source.path);
        raw.execute('PRAGMA user_version = 6');
        raw.close();
      } else {
        await source.writeAsString('pas une base SQLite');
      }
      final container = _container(live: live);
      await _insertCustomer(container.read(appDatabaseProvider));
      final before = container.read(appDatabaseProvider);
      final session = _RecordingSession(container.read(appDatabaseSessionProvider));
      final selection = _TestSelection(source);
      final service = _service(
        container: container, live: live, session: session,
        fileAccess: _TestFileAccess(open: selection),
      );
      await expectLater(
        service.restore(confirm: () async => fail('confirmation prématurée')),
        throwsA(kind == 'incompatible'
            ? isA<BackupFromNewerApp>() : isA<BackupFileInvalid>()),
      );
      expect(session.events, isEmpty);
      expect(selection.events, ['dispose']);
      expect(source.existsSync(), isFalse);
      expect(identical(before, container.read(appDatabaseProvider)), isTrue);
      expect(await _lastNames(before), ['Dupont']);
    });
  }

  test('document : refuser la confirmation nettoie sans fermer la base', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'live.db'));
    final source = File(p.join(directory.path, 'stage.db'));
    await _writeMigratedDatabase(source);
    final container = _container(live: live);
    await _insertCustomer(container.read(appDatabaseProvider));
    final selection = _TestSelection(source);
    final session = _RecordingSession(container.read(appDatabaseSessionProvider));
    final service = _service(
      container: container, live: live, session: session,
      fileAccess: _TestFileAccess(open: selection),
    );
    var confirmations = 0;
    expect(await service.restore(confirm: () async {
      confirmations++;
      expect(source.existsSync(), isTrue);
      expect(session.events, isEmpty);
      return false;
    }), RestoreOutcome.cancelled);
    expect(confirmations, 1);
    expect(session.events, isEmpty);
    expect(selection.events, ['dispose']);
    expect(source.existsSync(), isFalse);
    expect(await _lastNames(container.read(appDatabaseProvider)), ['Dupont']);
  });

  for (final fromAndroid in [false, true]) {
    test('format partagé : ${fromAndroid ? 'Android vers Windows' : 'Windows vers Android'}', () async {
      final directory = await tempDir();
      final origin = File(p.join(directory.path, 'origin.db'));
      final target = File(p.join(directory.path, 'target.db'));
      final document = File(p.join(directory.path, 'document.db'));
      final stage = File(p.join(directory.path, 'stage.db'));
      final originContainer = _container(live: origin);
      final targetContainer = _container(live: target);
      await _seedLiveWorld(originContainer.read(appDatabaseProvider));
      await _insertCustomer(targetContainer.read(appDatabaseProvider), lastName: 'Martin');
      final exporter = _service(
        container: originContainer, live: origin,
        picker: FakeFileLocationPicker(savePath: document.path),
        fileAccess: fromAndroid
            ? _TestFileAccess(save: _TestSelection(stage, destination: document))
            : null,
      );
      expect(await exporter.backup(), BackupOutcome.completed);
      if (!fromAndroid) await document.copy(stage.path);
      final session = _RecordingSession(targetContainer.read(appDatabaseSessionProvider));
      final store = _RecordingStore(session);
      final importer = _service(
        container: targetContainer, live: target, session: session,
        backupStore: store,
        picker: FakeFileLocationPicker(openPath: document.path),
        fileAccess: fromAndroid ? null : _TestFileAccess(open: _TestSelection(stage)),
      );
      final before = targetContainer.read(appDatabaseProvider);
      expect(await importer.restore(confirm: () async {
        session.events.add('confirm');
        return true;
      }), RestoreOutcome.completed);
      expect(session.events, ['confirm', 'snapshot', 'close', 'delete', 'replace', 'open']);
      expect(identical(before, targetContainer.read(appDatabaseProvider)), isFalse);
      expect(await _lastNames(targetContainer.read(appDatabaseProvider)), ['Dupont']);
      final dashboard = await targetContainer.read(dashboardSnapshotProvider.future);
      expect(dashboard.dueSoon.single.lastName, 'Dupont');
      expect(await targetContainer.read(historySnapshotProvider.future), hasLength(1));
      // Les données persistent après une autre fermeture/réouverture réelle.
      await session.closeForReplacement();
      await session.openAfterReplacement();
      expect(await _lastNames(targetContainer.read(appDatabaseProvider)), ['Dupont']);
      expect(document.existsSync(), isTrue);
      expect(stage.existsSync(), isFalse);
    });
  }

  test('document : échec réouverture, rollback puis nettoyage de la sélection', () async {
    final directory = await tempDir();
    final live = File(p.join(directory.path, 'live.db'));
    final source = File(p.join(directory.path, 'stage.db'));
    await _writeMigratedDatabase(source);
    final container = _container(live: live);
    await _insertCustomer(container.read(appDatabaseProvider));
    final session = _RecordingSession(
      container.read(appDatabaseSessionProvider), failFirstOpen: true,
    );
    final selection = _TestSelection(source);
    final service = _service(
      container: container, live: live, session: session,
      backupStore: _RecordingStore(session),
      fileAccess: _TestFileAccess(open: selection),
    );
    await expectLater(service.restore(confirm: () async => true),
        throwsA(isA<RestoreRolledBack>()));
    expect(session.events, [
      'snapshot', 'close', 'delete', 'replace', 'open',
      'delete', 'replace', 'open',
    ]);
    expect(await _lastNames(container.read(appDatabaseProvider)), ['Dupont']);
    expect(selection.events, ['dispose']);
    expect(source.existsSync(), isFalse);
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
  BackupFileAccess? fileAccess,
  AppDatabaseSession? session,
}) {
  return DataBackupService(
    clock: _clock,
    idGenerator: FakeIdGenerator(spareIds()),
    locator: FakeAppDataLocator.fromFile(live),
    picker: picker ?? FakeFileLocationPicker(),
    validator: backupValidator ?? _validator,
    store: backupStore ?? _store,
    session: session ?? container.read(appDatabaseSessionProvider),
    fileAccess: fileAccess,
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

final class _TestFileAccess implements BackupFileAccess {
  _TestFileAccess({this.save, this.open});

  final BackupFileSelection? save;
  final BackupFileSelection? open;
  String? suggestedName;

  @override
  Future<BackupFileSelection?> selectSave({required String suggestedFileName}) async {
    suggestedName = suggestedFileName;
    return save;
  }

  @override
  Future<BackupFileSelection?> selectOpen() async => open;
}

final class _TestSelection implements BackupFileSelection {
  _TestSelection(this.file, {this.destination, this.failCommit = false});

  final File file;
  final File? destination;
  final bool failCommit;
  final events = <String>[];

  @override
  String get localPath => file.path;

  @override
  Future<void> commit() async {
    events.add('commit');
    // Vérifie le véritable fichier remis au transport, pas une fixture SQLite.
    _validator.validate(file.path);
    if (failCommit) throw const FileSystemException('écriture refusée');
    await file.copy(destination!.path);
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
    if (file.existsSync()) await file.delete();
  }
}

final class _RecordingSession implements AppDatabaseSession {
  _RecordingSession(this._inner, {this.failFirstOpen = false});

  final AppDatabaseSession _inner;
  final bool failFirstOpen;
  final events = <String>[];
  var closed = false;
  var opens = 0;

  @override
  Future<void> exportSnapshot(String destinationPath) async {
    events.add('snapshot');
    expect(closed, isFalse);
    await _inner.exportSnapshot(destinationPath);
  }

  @override
  Future<void> closeForReplacement() async {
    await _inner.closeForReplacement();
    closed = true;
    events.add('close');
  }

  @override
  Future<void> openAfterReplacement() async {
    events.add('open');
    expect(closed, isTrue);
    opens++;
    if (failFirstOpen && opens == 1) throw StateError('ouverture impossible');
    await _inner.openAfterReplacement();
    closed = false;
  }
}

final class _RecordingStore implements BackupStore {
  _RecordingStore(this.session);

  final _RecordingSession session;

  @override
  Future<void> deleteDatabaseFiles(String databasePath) {
    expect(session.closed, isTrue);
    session.events.add('delete');
    return _store.deleteDatabaseFiles(databasePath);
  }

  @override
  Future<void> materializeBackup({
    required String sourcePath,
    required String liveDatabasePath,
  }) {
    expect(session.closed, isTrue);
    session.events.add('replace');
    return _store.materializeBackup(
      sourcePath: sourcePath, liveDatabasePath: liveDatabasePath,
    );
  }

  @override
  Future<void> replaceAtomically({required String fromTemp, required String destination}) =>
      _store.replaceAtomically(fromTemp: fromTemp, destination: destination);

  @override
  Future<void> deleteFileIfExists(String path) => _store.deleteFileIfExists(path);
}
