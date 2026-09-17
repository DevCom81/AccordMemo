import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'sqlite_database_path.dart';
import 'tables/customers_table.dart';
import 'tables/pianos_table.dart';
import 'tables/tunings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Customers, Pianos, Tunings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createCustomerIndexes();
        await _createPianoIndexes();
        await _createTuningIndexes();
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
