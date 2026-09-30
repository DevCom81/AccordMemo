import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup/app_database_session.dart';
import '../infrastructure/persistence/app_database.dart';
import '../infrastructure/persistence/sqlite_database_path.dart';

final sqliteDatabasePathProvider = Provider<SqliteDatabasePath>((ref) {
  return const SqliteDatabasePath();
});

final appDatabaseOpenerProvider = Provider<AppDatabase Function()>((ref) {
  final location = ref.watch(sqliteDatabasePathProvider);
  return () => openProductionAppDatabase(location: location);
});

final class AppDatabaseHolder extends Notifier<AppDatabase>
    implements AppDatabaseSession {
  AppDatabase? _current;
  late AppDatabase Function() _opener;

  @override
  AppDatabase build() {
    _opener = ref.watch(appDatabaseOpenerProvider);
    _current = _opener();
    ref.onDispose(() {
      final database = _current;
      _current = null;
      database?.close();
    });
    return _current!;
  }

  @override
  Future<void> exportSnapshot(String destinationPath) {
    final database = _current;
    if (database == null) {
      throw StateError('AppDatabaseHolder.exportSnapshot sans base ouverte');
    }
    return database.customStatement('VACUUM INTO ?', [destinationPath]);
  }

  @override
  Future<void> closeForReplacement() async {
    final database = _current;
    if (database != null) {
      await database.close();
    }
    _current = null;
  }

  @override
  Future<void> openAfterReplacement() async {
    if (_current != null) {
      throw StateError(
        'AppDatabaseHolder.openAfterReplacement alors qu’une base est encore ouverte',
      );
    }
    final database = _opener();
    try {
      await database.customSelect('SELECT 1').getSingle();
    } catch (error) {
      await database.close();
      rethrow;
    }
    _current = database;
    state = database;
  }
}
