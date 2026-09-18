import 'package:sqlite3/sqlite3.dart';

import '../../application/backup/backup_exceptions.dart';
import '../../application/backup/backup_validator.dart';

final class SqliteBackupValidator implements BackupValidator {
  const SqliteBackupValidator();

  static const supportedSchemaVersion = 6;

  @override
  void validate(String filePath) {
    Database? database;
    try {
      database = sqlite3.open(filePath, mode: OpenMode.readOnly);
      final version = _userVersion(database);
      if (version > supportedSchemaVersion) {
        throw BackupFromNewerApp(version);
      }
      if (version < 2) {
        throw const BackupFileInvalid();
      }
      final tables = _tableNames(database);
      for (final table in _expectedTables(version)) {
        if (!tables.contains(table)) {
          throw const BackupFileInvalid();
        }
      }
      final check = database.select('PRAGMA quick_check');
      if (check.isEmpty || check.first.values.first.toString() != 'ok') {
        throw const BackupFileInvalid();
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupFileInvalid();
    } finally {
      database?.close();
    }
  }

  int _userVersion(Database database) {
    final rows = database.select('PRAGMA user_version');
    if (rows.isEmpty) {
      throw const BackupFileInvalid();
    }
    final value = rows.first.values.first;
    if (value is int) {
      return value;
    }
    return int.parse(value.toString());
  }

  Set<String> _tableNames(Database database) {
    final rows = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return rows.map((row) => row.values.first.toString()).toSet();
  }

  List<String> _expectedTables(int version) {
    final tables = <String>['customers'];
    if (version >= 3) {
      tables.add('pianos');
    }
    if (version >= 4) {
      tables.add('tunings');
    }
    if (version >= 5) {
      tables.add('reminders');
    }
    if (version >= 6) {
      tables.add('activities');
    }
    return tables;
  }
}
