import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class MissingAppDataException implements Exception {
  const MissingAppDataException();

  @override
  String toString() {
    return "Variable d'environnement APPDATA absente ou vide : "
        'impossible de déterminer le dossier de données AccordMémo.';
  }
}

final class SqliteDatabasePath {
  static const directoryName = 'AccordMemo';
  static const fileName = 'accord_memo.db';
  static const demoFileName = 'accord_memo_demo.db';

  const SqliteDatabasePath() : _applicationSupportDirectory = null;

  const SqliteDatabasePath._android(this._applicationSupportDirectory);

  final Directory? _applicationSupportDirectory;

  /// Résout une fois le répertoire natif avant de construire les providers.
  /// Windows conserve sa résolution historique via APPDATA.
  static Future<SqliteDatabasePath> forCurrentPlatform({
    bool? isAndroid,
    Future<Directory> Function()? applicationSupportDirectory,
  }) async {
    if (!(isAndroid ?? Platform.isAndroid)) {
      return const SqliteDatabasePath();
    }
    final resolveDirectory =
        applicationSupportDirectory ?? getApplicationSupportDirectory;
    final directory = await resolveDirectory();
    return SqliteDatabasePath._android(directory);
  }

  File resolve(String? appDataRoot) {
    if (appDataRoot == null || appDataRoot.trim().isEmpty) {
      throw const MissingAppDataException();
    }

    return File(p.join(appDataRoot, directoryName, fileName));
  }

  File resolveDemo(String? appDataRoot) {
    if (appDataRoot == null || appDataRoot.trim().isEmpty) {
      throw const MissingAppDataException();
    }

    return File(p.join(appDataRoot, directoryName, demoFileName));
  }

  File resolveProduction() {
    final directory = _applicationSupportDirectory;
    if (directory != null) {
      return File(p.join(directory.path, fileName));
    }
    return resolve(Platform.environment['APPDATA']);
  }

  File resolveDemoFromEnvironment() {
    final directory = _applicationSupportDirectory;
    if (directory != null) {
      return File(p.join(directory.path, demoFileName));
    }
    return resolveDemo(Platform.environment['APPDATA']);
  }
}
