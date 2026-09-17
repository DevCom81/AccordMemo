import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Utilisateur Drift simulant le Lot 2 : schemaVersion 2, sans table métier
/// créée dans beforeOpen (l'API Drift n'autorise pas runCustom avant
/// ensureOpen). La table customers est créée ensuite, exécuteur déjà ouvert.
final class _Lot2SchemaUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test('migre le schéma 2 jusqu’à la version courante en créant pianos', () async {
    final directory = await Directory.systemTemp.createTemp(
      'accord_memo_migrate_pianos_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'accord_memo.db'));

    final v2Executor = NativeDatabase(file);
    await v2Executor.ensureOpen(_Lot2SchemaUser());
    try {
      await v2Executor.runCustom('''
CREATE TABLE customers (
  id TEXT NOT NULL PRIMARY KEY,
  civility TEXT NULL,
  last_name TEXT NOT NULL,
  first_name TEXT NULL,
  address TEXT NULL,
  postal_code TEXT NULL,
  city TEXT NULL,
  email TEXT NULL,
  phone TEXT NULL,
  archived_at INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

      final version = await v2Executor.runSelect('PRAGMA user_version', []);
      expect(version.single['user_version'], 2);

      final customers = await v2Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customers'",
        [],
      );
      expect(customers, isNotEmpty);

      final pianos = await v2Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pianos'",
        [],
      );
      expect(pianos, isEmpty);
    } finally {
      await v2Executor.close();
    }

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final migratedCustomers = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customers'",
        )
        .get();
    expect(migratedCustomers, isNotEmpty);

    final migratedPianos = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pianos'",
        )
        .get();
    expect(migratedPianos, isNotEmpty);

    final migratedTunings = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tunings'",
        )
        .get();
    expect(migratedTunings, isNotEmpty);

    final migratedReminders = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reminders'",
        )
        .get();
    expect(migratedReminders, isNotEmpty);

    final migratedVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(migratedVersion.read<int>('user_version'), 6);
  });
}
