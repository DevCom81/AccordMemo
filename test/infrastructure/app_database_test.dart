import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ouvre une base mémoire et active les foreign keys', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);

    final userVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(userVersion.read<int>('user_version'), 6);

    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('customers', 'pianos', 'tunings', 'reminders', 'activities')",
        )
        .get();
    expect(tables, hasLength(5));
  });
}
