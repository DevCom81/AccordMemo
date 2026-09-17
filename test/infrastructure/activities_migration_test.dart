import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Utilisateur Drift simulant le Lot 5 : schemaVersion 5.
final class _Lot5SchemaUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 5;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test('migre le schéma 5 vers 6 en créant activities', () async {
    final directory = await Directory.systemTemp.createTemp(
      'accord_memo_migrate_activities_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'accord_memo.db'));

    final v5Executor = NativeDatabase(file);
    await v5Executor.ensureOpen(_Lot5SchemaUser());
    try {
      await v5Executor.runCustom('''
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
      await v5Executor.runCustom('''
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
      await v5Executor.runCustom('''
CREATE TABLE tunings (
  id TEXT NOT NULL PRIMARY KEY,
  piano_id TEXT NOT NULL REFERENCES pianos (id) ON DELETE RESTRICT,
  tuning_date TEXT NOT NULL,
  notes TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
      await v5Executor.runCustom('''
CREATE TABLE reminders (
  id TEXT NOT NULL PRIMARY KEY,
  piano_id TEXT NOT NULL REFERENCES pianos (id) ON DELETE RESTRICT,
  origin_tuning_id TEXT NOT NULL REFERENCES tunings (id) ON DELETE RESTRICT,
  due_date TEXT NOT NULL,
  status TEXT NOT NULL,
  manually_rescheduled INTEGER NOT NULL CHECK ("manually_rescheduled" IN (0, 1)),
  cancellation_reason TEXT NULL,
  sent_at INTEGER NULL,
  cancelled_at INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  CHECK (status IN ('scheduled', 'sent', 'cancelled'))
)
''');
      await v5Executor.runCustom(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_reminders_one_scheduled_per_piano "
        "ON reminders (piano_id) WHERE status = 'scheduled'",
      );
      await v5Executor.runCustom(
        'CREATE INDEX IF NOT EXISTS idx_reminders_origin_tuning_id '
        'ON reminders (origin_tuning_id)',
      );
      await v5Executor.runCustom('''
INSERT INTO customers (id, last_name, created_at, updated_at)
VALUES ('customer-1', 'Dupont', 0, 0)
''');
      await v5Executor.runCustom('''
INSERT INTO pianos (
  id, customer_id, brand, reminder_interval_months, reminders_enabled,
  created_at, updated_at
)
VALUES ('piano-1', 'customer-1', 'Yamaha', 12, 1, 0, 0)
''');
      await v5Executor.runCustom('''
INSERT INTO tunings (id, piano_id, tuning_date, created_at, updated_at)
VALUES ('tuning-1', 'piano-1', '2026-09-17', 0, 0)
''');
      await v5Executor.runCustom('''
INSERT INTO reminders (
  id, piano_id, origin_tuning_id, due_date, status, manually_rescheduled,
  created_at, updated_at
)
VALUES ('reminder-1', 'piano-1', 'tuning-1', '2027-09-17', 'scheduled', 0, 0, 0)
''');

      final version = await v5Executor.runSelect('PRAGMA user_version', []);
      expect(version.single['user_version'], 5);

      final activityTables = await v5Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'activities'",
        [],
      );
      expect(activityTables, isEmpty);
    } finally {
      await v5Executor.close();
    }

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final migratedActivities = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'activities'",
        )
        .get();
    expect(migratedActivities, isNotEmpty);

    final occurredAtIndex = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_activities_occurred_at'",
        )
        .get();
    expect(occurredAtIndex, isNotEmpty);

    final pianoIndex = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_activities_piano_id_occurred_at'",
        )
        .get();
    expect(pianoIndex, isNotEmpty);

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

    final preservedReminder = await database
        .customSelect("SELECT due_date FROM reminders WHERE id = 'reminder-1'")
        .getSingle();
    expect(preservedReminder.read<String>('due_date'), '2027-09-17');

    final migratedVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(migratedVersion.read<int>('user_version'), 6);
  });
}
