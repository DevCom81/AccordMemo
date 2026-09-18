abstract interface class AppDatabaseSession {
  Future<void> exportSnapshot(String destinationPath);

  Future<void> closeForReplacement();

  Future<void> openAfterReplacement();
}
