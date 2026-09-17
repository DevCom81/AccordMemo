import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'sqlite_database_path.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Aucune migration tant que schemaVersion reste à 1.
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
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
