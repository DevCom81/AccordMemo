import '../../application/backup/backup_exceptions.dart';
import '../../infrastructure/persistence/sqlite_database_path.dart';
import 'settings_strings.dart';

String settingsBackupMessage(Object error) {
  if (error is BackupFromNewerApp) {
    return settingsBackupNewer;
  }
  if (error is BackupFileInvalid) {
    return settingsBackupInvalid;
  }
  if (error is BackupBusy) {
    return settingsBackupBusy;
  }
  if (error is MissingAppDataException) {
    return settingsBackupError;
  }
  return settingsBackupError;
}

String settingsRestoreMessage(Object error) {
  if (error is BackupFromNewerApp) {
    return settingsBackupNewer;
  }
  if (error is BackupFileInvalid) {
    return settingsBackupInvalid;
  }
  if (error is BackupBusy) {
    return settingsBackupBusy;
  }
  if (error is RestoreRolledBack || error is RestoreFailed) {
    return settingsRestoreError;
  }
  return settingsRestoreError;
}
