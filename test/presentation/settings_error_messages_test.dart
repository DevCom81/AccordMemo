import 'package:accord_memo/application/backup/backup_exceptions.dart';
import 'package:accord_memo/infrastructure/persistence/sqlite_database_path.dart';
import 'package:accord_memo/presentation/settings/settings_error_messages.dart';
import 'package:accord_memo/presentation/settings/settings_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mappe les erreurs de copie sans jargon technique', () {
    expect(
      settingsBackupMessage(const BackupFileInvalid()),
      settingsBackupInvalid,
    );
    expect(
      settingsBackupMessage(const BackupFromNewerApp(7)),
      settingsBackupNewer,
    );
    expect(settingsBackupMessage(const BackupBusy()), settingsBackupBusy);
    expect(
      settingsBackupMessage(const MissingAppDataException()),
      settingsBackupError,
    );
    expect(settingsBackupMessage(Exception('VACUUM INTO')), settingsBackupError);
  });

  test('mappe les erreurs de restauration sans jargon technique', () {
    expect(
      settingsRestoreMessage(const BackupFileInvalid()),
      settingsBackupInvalid,
    );
    expect(
      settingsRestoreMessage(const BackupFromNewerApp(7)),
      settingsBackupNewer,
    );
    expect(settingsRestoreMessage(const RestoreRolledBack()), settingsRestoreError);
    expect(settingsRestoreMessage(const RestoreFailed()), settingsRestoreError);
    expect(
      settingsRestoreMessage(Exception('WAL')),
      settingsRestoreError,
    );
  });
}
