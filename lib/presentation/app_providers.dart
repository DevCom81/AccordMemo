import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/persistence/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = openProductionAppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});
