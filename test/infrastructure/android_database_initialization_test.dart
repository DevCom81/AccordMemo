import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/sqlite_database_path.dart';
import 'package:accord_memo/presentation/app_database_holder.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/dev/demo_mode.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('une installation vierge crée le schéma commun sans données', () async {
    final root = await Directory.systemTemp.createTemp('accordmemo-android-');
    addTearDown(() => root.delete(recursive: true));
    final privateDirectory = Directory(p.join(root.path, 'private', 'files'));
    final location = await SqliteDatabasePath.forCurrentPlatform(
      isAndroid: true,
      applicationSupportDirectory: () async => privateDirectory,
    );
    final file = location.resolveProduction();
    final database = openProductionAppDatabase(location: location);
    final reference = AppDatabase(NativeDatabase.memory());
    try {
      expect(await privateDirectory.exists(), isFalse);
      expect(await file.exists(), isFalse);

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), reference.schemaVersion);
      expect(await privateDirectory.exists(), isTrue);
      expect(await file.exists(), isTrue);
      expect(await _schema(database), await _schema(reference));

      for (final table in [
        'customers',
        'pianos',
        'tunings',
        'reminders',
        'activities',
      ]) {
        final count = await database
            .customSelect('SELECT COUNT(*) AS total FROM $table')
            .getSingle();
        expect(count.read<int>('total'), 0, reason: table);
      }
      final journal = await database
          .customSelect('PRAGMA journal_mode')
          .getSingle();
      expect(journal.read<String>('journal_mode'), 'wal');
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);

      final now = DateTime.utc(2026, 10, 1);
      await database.into(database.customers).insert(
            CustomersCompanion.insert(
              id: 'customer-test',
              lastName: 'Éléonore',
              createdAt: now,
              updatedAt: now,
            ),
          );
    } finally {
      await database.close();
      await reference.close();
    }

    final reopened = openProductionAppDatabase(location: location);
    try {
      final customer = await reopened.select(reopened.customers).getSingle();
      expect(customer.lastName, 'Éléonore');
      expect(await location.resolveDemoFromEnvironment().exists(), isFalse);
    } finally {
      await reopened.close();
    }
  });

  test('SQLite et les paramètres partagent le chemin Android injecté', () async {
    final root = await Directory.systemTemp.createTemp('accordmemo-path-di-');
    addTearDown(() => root.delete(recursive: true));
    final location = await SqliteDatabasePath.forCurrentPlatform(
      isAndroid: true,
      applicationSupportDirectory: () async => root,
    );
    final container = ProviderContainer(
      overrides: [
        sqliteDatabasePathProvider.overrideWith((ref) => location),
      ],
    );
    try {
      final locator = container.read(appDataLocatorProvider);
      expect(locator.liveDatabasePath, location.resolveProduction().path);
      expect(locator.displayLocation, root.path);
      final database = container.read(appDatabaseProvider);
      final files = await database.customSelect('PRAGMA database_list').get();
      final main = files.singleWhere((row) => row.read<String>('name') == 'main');
      expect(main.read<String>('file'), locator.liveDatabasePath);

      await container.read(appDatabaseSessionProvider).closeForReplacement();
      await container.read(appDatabaseSessionProvider).openAfterReplacement();
      final reopenedFiles = await container
          .read(appDatabaseProvider)
          .customSelect('PRAGMA database_list')
          .get();
      final reopenedMain = reopenedFiles.singleWhere(
        (row) => row.read<String>('name') == 'main',
      );
      expect(reopenedMain.read<String>('file'), locator.liveDatabasePath);
    } finally {
      await container.read(appDatabaseSessionProvider).closeForReplacement();
      container.dispose();
    }
  });

  test('le locator démo reste distinct sur Android', () async {
    final location = await SqliteDatabasePath.forCurrentPlatform(
      isAndroid: true,
      applicationSupportDirectory: () async => Directory('private'),
    );
    final container = ProviderContainer(
      overrides: [
        sqliteDatabasePathProvider.overrideWith((ref) => location),
        demoModeProvider.overrideWith((ref) => true),
      ],
    );
    try {
      expect(
        container.read(appDataLocatorProvider).liveDatabasePath,
        location.resolveDemoFromEnvironment().path,
      );
    } finally {
      container.dispose();
    }
  });
}

Future<List<Map<String, Object?>>> _schema(AppDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT type, name, tbl_name, sql FROM sqlite_master "
        "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
      )
      .get();
  return rows.map((row) => row.data).toList();
}
