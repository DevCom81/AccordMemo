import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'sqlite_database_path.dart';
import 'tables/customers_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Customers])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createCustomerIndexes();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(customers);
          await _createCustomerIndexes();
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
