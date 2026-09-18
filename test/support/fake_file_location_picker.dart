import 'dart:async';

import 'package:accord_memo/application/backup/file_location_picker.dart';

final class FakeFileLocationPicker implements FileLocationPicker {
  FakeFileLocationPicker({this.savePath, this.openPath});

  String? savePath;
  String? openPath;
  String? lastSuggestedFileName;

  @override
  Future<String?> pickSaveLocation({required String suggestedFileName}) async {
    lastSuggestedFileName = suggestedFileName;
    return savePath;
  }

  @override
  Future<String?> pickOpenLocation() async {
    return openPath;
  }
}

final class PendingFileLocationPicker implements FileLocationPicker {
  final save = Completer<String?>();
  final open = Completer<String?>();

  @override
  Future<String?> pickSaveLocation({required String suggestedFileName}) {
    return save.future;
  }

  @override
  Future<String?> pickOpenLocation() {
    return open.future;
  }
}
