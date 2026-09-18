import '../../application/backup/backup_exceptions.dart';
import '../../application/ports/google_auth_session.dart';
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

String settingsMailMessage(Object error) {
  if (error is GoogleOAuthClientNotConfigured) {
    return settingsMailNotConfigured;
  }
  if (error is GoogleAuthorizationCancelled) {
    return settingsMailConnectCancelled;
  }
  if (error is GoogleRefreshTokenMissing ||
      error is GoogleAuthorizationFailed) {
    return settingsMailConnectFailed;
  }
  return settingsMailGenericError;
}
