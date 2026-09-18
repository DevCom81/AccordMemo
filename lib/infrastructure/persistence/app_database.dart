import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'sqlite_database_path.dart';
import 'tables/activities_table.dart';
import 'tables/customers_table.dart';
import 'tables/pianos_table.dart';
import 'tables/reminders_table.dart';
import 'tables/tunings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Customers, Pianos, Tunings, Reminders, Activities])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createCustomerIndexes();
        await _createPianoIndexes();
        await _createTuningIndexes();
        await _createReminderIndexes();
        await _createActivityIndexes();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(customers);
          await _createCustomerIndexes();
        }
        if (from < 3) {
          await m.createTable(pianos);
          await _createPianoIndexes();
        }
        if (from < 4) {
          await m.createTable(tunings);
          await _createTuningIndexes();
        }
        if (from < 5) {
          await m.createTable(reminders);
          await _createReminderIndexes();
        }
        if (from < 6) {
          await m.createTable(activities);
          await _createActivityIndexes();
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createCustomerIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_customers_archived_at '
      'ON customers (archived_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_customers_last_name '
      'ON customers (last_name)',
    );
  }

  Future<void> _createPianoIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pianos_customer_id '
      'ON pianos (customer_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pianos_archived_at '
      'ON pianos (archived_at)',
    );
  }

  Future<void> _createTuningIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tunings_piano_id_tuning_date '
      'ON tunings (piano_id, tuning_date)',
    );
  }

  Future<void> _createReminderIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_reminders_one_scheduled_per_piano '
      'ON reminders (piano_id) WHERE status = \'scheduled\'',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reminders_origin_tuning_id '
      'ON reminders (origin_tuning_id)',
    );
  }

  Future<void> _createActivityIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_occurred_at '
      'ON activities (occurred_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_piano_id_occurred_at '
      'ON activities (piano_id, occurred_at)',
    );
  }
}

AppDatabase openProductionAppDatabase({
  SqliteDatabasePath location = const SqliteDatabasePath(),
}) {
  return AppDatabase(
    LazyDatabase(() async {
      final file = location.resolveProduction();
      await file.parent.create(recursive: true);
      return NativeDatabase.createInBackground(
        file,
        setup: (database) {
          database.execute('PRAGMA journal_mode = WAL');
        },
      );
    }),
  );
}

AppDatabase openDemoAppDatabase({
  SqliteDatabasePath location = const SqliteDatabasePath(),
}) {
  return AppDatabase(
    LazyDatabase(() async {
      final file = location.resolveDemoFromEnvironment();
      await file.parent.create(recursive: true);
      return NativeDatabase.createInBackground(
        file,
        setup: (database) {
          database.execute('PRAGMA journal_mode = WAL');
        },
      );
    }),
  );
}
