abstract interface class BackupStore {
  Future<void> replaceAtomically({
    required String fromTemp,
    required String destination,
  });

  Future<void> deleteDatabaseFiles(String databasePath);

  Future<void> materializeBackup({
    required String sourcePath,
    required String liveDatabasePath,
  });

  Future<void> deleteFileIfExists(String path);
}
