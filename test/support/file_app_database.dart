import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:drift/native.dart';

AppDatabase openFileAppDatabase(File file) {
  return AppDatabase(
    NativeDatabase(
      file,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL');
      },
    ),
  );
}
