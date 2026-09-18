sealed class BackupException implements Exception {
  const BackupException();
}

final class BackupFileInvalid extends BackupException {
  const BackupFileInvalid();
}

final class BackupFromNewerApp extends BackupException {
  const BackupFromNewerApp(this.userVersion);

  final int userVersion;
}

final class BackupBusy extends BackupException {
  const BackupBusy();
}

final class RestoreRolledBack extends BackupException {
  const RestoreRolledBack();
}

final class RestoreFailed extends BackupException {
  const RestoreFailed();
}
