import 'dart:io';

import 'package:accord_memo/application/backup/backup_exceptions.dart';
import 'package:accord_memo/infrastructure/persistence/sqlite_backup_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../support/file_app_database.dart';

void main() {
  const validator = SqliteBackupValidator();

  Future<Directory> tempDir() async {
    final directory = await Directory.systemTemp.createTemp(
      'accord_memo_validator_',
    );
    addTearDown(() => directory.delete(recursive: true));
    return directory;
  }

  test('accepte une base AccordMémo schemaVersion 6', () async {
    final directory = await tempDir();
    final file = File(p.join(directory.path, 'ok.db'));
    final database = openFileAppDatabase(file);
    await database.customSelect('SELECT 1').getSingle();
    await database.close();

    expect(() => validator.validate(file.path), returnsNormally);
  });

  test('rejette un fichier illisible', () async {
    final directory = await tempDir();
    final file = File(p.join(directory.path, 'not.db'));
    await file.writeAsString('ceci n’est pas sqlite');

    expect(
      () => validator.validate(file.path),
      throwsA(isA<BackupFileInvalid>()),
    );
  });

  test('rejette une copie créée par une version plus récente', () async {
    final directory = await tempDir();
    final file = File(p.join(directory.path, 'newer.db'));
    final database = openFileAppDatabase(file);
    await database.customSelect('SELECT 1').getSingle();
    await database.close();

    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 7');
    raw.close();

    expect(
      () => validator.validate(file.path),
      throwsA(
        isA<BackupFromNewerApp>().having((error) => error.userVersion, 'userVersion', 7),
      ),
    );
  });

  test('rejette une base sans les tables attendues', () async {
    final directory = await tempDir();
    final file = File(p.join(directory.path, 'empty.db'));
    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 6');
    raw.close();

    expect(
      () => validator.validate(file.path),
      throwsA(isA<BackupFileInvalid>()),
    );
  });

  test('rejette une user_version inférieure à 2', () async {
    final directory = await tempDir();
    final file = File(p.join(directory.path, 'v1.db'));
    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    expect(
      () => validator.validate(file.path),
      throwsA(isA<BackupFileInvalid>()),
    );
  });

  test('rejette les bons noms de tables avec des colonnes incompatibles', () async {
    final directory = await tempDir();
    final file = File(p.join(directory.path, 'impostor.db'));
    final raw = sqlite3.open(file.path);
    try {
      raw.execute('PRAGMA user_version = 6');
      for (final table in ['customers', 'pianos', 'tunings', 'reminders', 'activities']) {
        raw.execute('CREATE TABLE $table (id TEXT)');
      }
    } finally {
      raw.close();
    }
    expect(() => validator.validate(file.path), throwsA(isA<BackupFileInvalid>()));
  });

  for (final version in [2, 3, 4, 5]) {
    test('conserve la lecture du format historique version $version', () async {
      final directory = await tempDir();
      final file = File(p.join(directory.path, 'v$version.db'));
      final database = openFileAppDatabase(file);
      await database.customSelect('SELECT 1').getSingle();
      await database.close();
      final raw = sqlite3.open(file.path);
      try {
        raw.execute('PRAGMA foreign_keys = OFF');
        raw.execute('DROP TABLE activities');
        if (version < 5) raw.execute('DROP TABLE reminders');
        if (version < 4) raw.execute('DROP TABLE tunings');
        if (version < 3) raw.execute('DROP TABLE pianos');
        raw.execute('PRAGMA user_version = $version');
      } finally {
        raw.close();
      }
      expect(() => validator.validate(file.path), returnsNormally);
    });
  }
}
