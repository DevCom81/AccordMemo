import 'dart:io';

import 'package:path/path.dart' as p;

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

  const SqliteDatabasePath();

  File resolve(String? appDataRoot) {
    if (appDataRoot == null || appDataRoot.trim().isEmpty) {
      throw const MissingAppDataException();
    }

    return File(p.join(appDataRoot, directoryName, fileName));
  }

  File resolveProduction() {
    return resolve(Platform.environment['APPDATA']);
  }
}
