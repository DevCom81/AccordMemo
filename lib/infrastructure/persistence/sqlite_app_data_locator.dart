import 'dart:io';

import '../../application/backup/app_data_locator.dart';
import 'sqlite_database_path.dart';

final class SqliteAppDataLocator implements AppDataLocator {
  SqliteAppDataLocator({required this._resolveLive});

  final File Function() _resolveLive;

  factory SqliteAppDataLocator.production({
    SqliteDatabasePath location = const SqliteDatabasePath(),
  }) {
    return SqliteAppDataLocator(resolveLive: location.resolveProduction);
  }

  factory SqliteAppDataLocator.demo({
    SqliteDatabasePath location = const SqliteDatabasePath(),
  }) {
    return SqliteAppDataLocator(
      resolveLive: location.resolveDemoFromEnvironment,
    );
  }

  @override
  String get liveDatabasePath => _resolveLive().path;

  @override
  String get liveDirectoryPath => _resolveLive().parent.path;

  @override
  String get displayLocation => liveDirectoryPath;
}
