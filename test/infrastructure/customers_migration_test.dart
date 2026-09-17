import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Utilisateur Drift simulant le schéma Lot 1 (version 1, aucune table métier).
final class _Lot1SchemaUser implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test('migre le schéma 1 vers 2 en créant customers', () async {
    final directory = await Directory.systemTemp.createTemp(
      'accord_memo_migrate_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'accord_memo.db'));

    final v1Executor = NativeDatabase(file);
    await v1Executor.ensureOpen(_Lot1SchemaUser());
    try {
      final version = await v1Executor.runSelect('PRAGMA user_version', []);
      expect(version.single['user_version'], 1);

      final tables = await v1Executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customers'",
        [],
      );
      expect(tables, isEmpty);
    } finally {
      await v1Executor.close();
    }

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final migratedTables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'customers'",
        )
        .get();
    expect(migratedTables, isNotEmpty);

    final migratedVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(migratedVersion.read<int>('user_version'), 2);
  });
}
