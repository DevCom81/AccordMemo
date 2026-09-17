import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Utilisateur Drift simulant le Lot 4 : schemaVersion 4.
final class _Lot4SchemaUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 4;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test('migre le schéma 4 vers 5 en créant reminders', () async {
    final directory = await Directory.systemTemp.createTemp(
      'accord_memo_migrate_reminders_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'accord_memo.db'));

    final v4Executor = NativeDatabase(file);
    await v4Executor.ensureOpen(_Lot4SchemaUser());
    try {
      await v4Executor.runCustom('''
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
      await v4Executor.runCustom('''
CREATE TABLE pianos (
  id TEXT NOT NULL PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES customers (id) ON DELETE RESTRICT,
  brand TEXT NULL,
  model TEXT NULL,
  serial_number TEXT NULL,
  type TEXT NULL,
  location TEXT NULL,
  notes TEXT NULL,
  reminder_interval_months INTEGER NOT NULL,
  reminders_enabled INTEGER NOT NULL CHECK ("reminders_enabled" IN (0, 1)),
  archived_at INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
      await v4Executor.runCustom('''
CREATE TABLE tunings (
  id TEXT NOT NULL PRIMARY KEY,
  piano_id TEXT NOT NULL REFERENCES pianos (id) ON DELETE RESTRICT,
  tuning_date TEXT NOT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
      await v4Executor.runCustom('''
INSERT INTO customers (id, last_name, created_at, updated_at)
VALUES ('customer-1', 'Dupont', 0, 0)
''');
      await v4Executor.runCustom('''
INSERT INTO pianos (
  id, customer_id, brand, reminder_interval_months, reminders_enabled,
  created_at, updated_at
)
VALUES ('piano-1', 'customer-1', 'Yamaha', 12, 1, 0, 0)
''');
      await v4Executor.runCustom('''
INSERT INTO tunings (id, piano_id, tuning_date, created_at, updated_at)
VALUES ('tuning-1', 'piano-1', '2026-09-17', 0, 0)
''');

      final version = await v4Executor.runSelect('PRAGMA user_version', []);
      expect(version.single['user_version'], 4);

      final customers = await v4Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customers'",
        [],
      );
      expect(customers, isNotEmpty);

      final pianos = await v4Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pianos'",
        [],
      );
      expect(pianos, isNotEmpty);

      final tunings = await v4Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tunings'",
        [],
      );
      expect(tunings, isNotEmpty);

      final reminderTables = await v4Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reminders'",
        [],
      );
      expect(reminderTables, isEmpty);
    } finally {
      await v4Executor.close();
    }

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final migratedReminders = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reminders'",
        )
        .get();
    expect(migratedReminders, isNotEmpty);

    final uniqueIndex = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_reminders_one_scheduled_per_piano'",
        )
        .get();
    expect(uniqueIndex, isNotEmpty);

    final originIndex = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_reminders_origin_tuning_id'",
        )
        .get();
    expect(originIndex, isNotEmpty);

    final preservedCustomer = await database
        .customSelect("SELECT last_name FROM customers WHERE id = 'customer-1'")
        .getSingle();
    expect(preservedCustomer.read<String>('last_name'), 'Dupont');

    final preservedPiano = await database
        .customSelect("SELECT brand FROM pianos WHERE id = 'piano-1'")
        .getSingle();
    expect(preservedPiano.read<String>('brand'), 'Yamaha');

    final preservedTuning = await database
        .customSelect("SELECT tuning_date FROM tunings WHERE id = 'tuning-1'")
        .getSingle();
    expect(preservedTuning.read<String>('tuning_date'), '2026-09-17');

    final migratedVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(migratedVersion.read<int>('user_version'), 5);
  });
}
