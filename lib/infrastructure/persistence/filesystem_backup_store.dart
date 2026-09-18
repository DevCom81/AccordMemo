import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../application/backup/backup_store.dart';

final class FilesystemBackupStore implements BackupStore {
  const FilesystemBackupStore();

  @override
  Future<void> replaceAtomically({
    required String fromTemp,
    required String destination,
  }) async {
    final temp = File(fromTemp);
    final dest = File(destination);
    if (!await dest.exists()) {
      await temp.rename(destination);
      return;
    }
    final previous = File('$destination.prev');
    if (await previous.exists()) {
      await previous.delete();
    }
    await dest.rename(previous.path);
    try {
      await temp.rename(destination);
    } catch (error) {
      if (await dest.exists()) {
        await dest.delete();
      }
      if (await previous.exists()) {
        await previous.rename(destination);
      }
      rethrow;
    }
    await previous.delete();
  }

  @override
  Future<void> deleteDatabaseFiles(String databasePath) async {
    for (final path in [databasePath, '$databasePath-wal', '$databasePath-shm']) {
      await deleteFileIfExists(path);
    }
  }

  @override
  Future<void> materializeBackup({
    required String sourcePath,
    required String liveDatabasePath,
  }) async {
    await deleteDatabaseFiles(liveDatabasePath);
    final live = File(liveDatabasePath);
    await live.parent.create(recursive: true);
    final source = sqlite3.open(sourcePath);
    try {
      source.execute('VACUUM INTO ?', [liveDatabasePath]);
    } finally {
      source.close();
    }
  }

  @override
  Future<void> deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
