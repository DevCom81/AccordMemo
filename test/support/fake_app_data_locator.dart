import 'dart:io';

import 'package:accord_memo/application/backup/app_data_locator.dart';

final class FakeAppDataLocator implements AppDataLocator {
  const FakeAppDataLocator({
    required this.liveDatabasePath,
    String? displayLocation,
  }) : displayLocation = displayLocation ?? liveDatabasePath;

  factory FakeAppDataLocator.fromFile(File file) {
    return FakeAppDataLocator(liveDatabasePath: file.path);
  }

  factory FakeAppDataLocator.displayOnly() {
    return const FakeAppDataLocator(
      liveDatabasePath:
          r'C:\Users\Eleonore\AppData\Roaming\AccordMemo\accord_memo.db',
      displayLocation: r'C:\Users\Eleonore\AppData\Roaming\AccordMemo',
    );
  }

  @override
  final String liveDatabasePath;

  @override
  String get liveDirectoryPath => File(liveDatabasePath).parent.path;

  @override
  final String displayLocation;
}
