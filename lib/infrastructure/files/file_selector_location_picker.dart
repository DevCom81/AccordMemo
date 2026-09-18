import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../../application/backup/file_location_picker.dart';

final class FileSelectorLocationPicker implements FileLocationPicker {
  const FileSelectorLocationPicker();

  static const _backupType = XTypeGroup(
    label: 'Sauvegarde AccordMémo',
    extensions: ['db'],
  );

  @override
  Future<String?> pickSaveLocation({required String suggestedFileName}) async {
    final location = await getSaveLocation(
      suggestedName: suggestedFileName,
      initialDirectory: _documentsDirectory,
      acceptedTypeGroups: const [_backupType],
    );
    return location?.path;
  }

  @override
  Future<String?> pickOpenLocation() async {
    final file = await openFile(
      acceptedTypeGroups: const [_backupType],
      initialDirectory: _documentsDirectory,
    );
    return file?.path;
  }

  String? get _documentsDirectory {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return null;
    }
    return p.join(home, 'Documents');
  }
}
