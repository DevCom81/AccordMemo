import 'package:sqlite3/sqlite3.dart';

import '../../application/backup/backup_exceptions.dart';
import '../../application/backup/backup_validator.dart';

final class SqliteBackupValidator implements BackupValidator {
  const SqliteBackupValidator();

  static const supportedSchemaVersion = 6;

  // Colonnes du format partagé, inchangées depuis la création de chaque table.
  // Les seuls noms de tables ne suffisent pas à reconnaître une copie lisible.
  static const _readableColumns = {
    'customers': 'id, civility, last_name, first_name, address, postal_code, '
        'city, email, phone, archived_at, created_at, updated_at',
    'pianos': 'id, customer_id, brand, model, serial_number, type, location, '
        'notes, reminder_interval_months, reminders_enabled, archived_at, '
        'created_at, updated_at',
    'tunings': 'id, piano_id, tuning_date, notes, created_at, updated_at',
    'reminders': 'id, piano_id, origin_tuning_id, due_date, status, '
        'manually_rescheduled, cancellation_reason, sent_at, cancelled_at, '
        'created_at, updated_at',
    'activities': 'id, type, piano_id, tuning_id, reminder_id, previous_date, '
        'new_date, occurred_at',
  };

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
        database.select('SELECT ${_readableColumns[table]} FROM $table LIMIT 1');
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
