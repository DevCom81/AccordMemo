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
}
