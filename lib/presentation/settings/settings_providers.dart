import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/backup/app_data_locator.dart';
import '../../application/backup/backup_store.dart';
import '../../application/backup/backup_validator.dart';
import '../../application/backup/data_backup_service.dart';
import '../../application/backup/file_location_picker.dart';
import '../../infrastructure/files/file_selector_location_picker.dart';
import '../../infrastructure/persistence/filesystem_backup_store.dart';
import '../../infrastructure/persistence/sqlite_app_data_locator.dart';
import '../../infrastructure/persistence/sqlite_backup_validator.dart';
import '../app_providers.dart';
import '../dev/demo_mode.dart';

final appDataLocatorProvider = Provider<AppDataLocator>((ref) {
  if (ref.watch(demoModeProvider)) {
    return SqliteAppDataLocator.demo();
  }
  return SqliteAppDataLocator.production();
});

final fileLocationPickerProvider = Provider<FileLocationPicker>((ref) {
  return const FileSelectorLocationPicker();
});

final backupValidatorProvider = Provider<BackupValidator>((ref) {
  return const SqliteBackupValidator();
});

final backupStoreProvider = Provider<BackupStore>((ref) {
  return const FilesystemBackupStore();
});

final dataBackupServiceProvider = Provider<DataBackupService>((ref) {
  return DataBackupService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    locator: ref.watch(appDataLocatorProvider),
    picker: ref.watch(fileLocationPickerProvider),
    validator: ref.watch(backupValidatorProvider),
    store: ref.watch(backupStoreProvider),
    session: ref.watch(appDatabaseSessionProvider),
  );
});
