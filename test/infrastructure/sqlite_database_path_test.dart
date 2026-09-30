import 'dart:io';

import 'package:accord_memo/infrastructure/persistence/sqlite_database_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const location = SqliteDatabasePath();

  test('Android utilise uniquement le répertoire privé fourni', () async {
    final directory = Directory(p.join('private', 'application'));
    var directoryCalls = 0;
    final android = await SqliteDatabasePath.forCurrentPlatform(
      isAndroid: true,
      applicationSupportDirectory: () async {
        directoryCalls += 1;
        return directory;
      },
    );

    expect(
      android.resolveProduction().path,
      p.join(directory.path, 'accord_memo.db'),
    );
    expect(
      android.resolveDemoFromEnvironment().path,
      p.join(directory.path, 'accord_memo_demo.db'),
    );
    expect(directoryCalls, 1);
  });

  test('Windows conserve APPDATA sans appeler le plugin Android', () async {
    final windows = await SqliteDatabasePath.forCurrentPlatform(
      isAndroid: false,
      applicationSupportDirectory: () async {
        throw StateError('Le plugin ne doit pas être appelé sur Windows');
      },
    );
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.trim().isEmpty) {
      expect(
        windows.resolveProduction,
        throwsA(isA<MissingAppDataException>()),
      );
      expect(
        windows.resolveDemoFromEnvironment,
        throwsA(isA<MissingAppDataException>()),
      );
    } else {
      expect(windows.resolveProduction().path, location.resolve(appData).path);
      expect(
        windows.resolveDemoFromEnvironment().path,
        location.resolveDemo(appData).path,
      );
    }
  });

  test('un échec du répertoire Android ne bascule jamais vers APPDATA', () async {
    final failure = StateError('Répertoire privé indisponible');
    await expectLater(
      SqliteDatabasePath.forCurrentPlatform(
        isAndroid: true,
        applicationSupportDirectory: () async => throw failure,
      ),
      throwsA(same(failure)),
    );
  });

  test('le domaine ne dépend pas de la persistance ni de la plateforme', () {
    final files = Directory('lib/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final imports = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    for (final file in files) {
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        for (final dependency in [
          'dart:io',
          'package:flutter/',
          'package:path_provider/',
          'package:drift/',
          'package:sqlite3/',
          'infrastructure/',
        ]) {
          expect(uri.contains(dependency), isFalse, reason: '${file.path}: $uri');
        }
      }
    }
  });

  test('construit le chemin sous la racine injectée', () {
    final appDataRoot = p.join('tmp', 'fake-appdata');
    final file = location.resolve(appDataRoot);

    expect(
      file.path,
      p.join(appDataRoot, SqliteDatabasePath.directoryName, SqliteDatabasePath.fileName),
    );
  });

  test('refuse une racine APPDATA absente ou vide', () {
    expect(() => location.resolve(null), throwsA(isA<MissingAppDataException>()));
    expect(() => location.resolve(''), throwsA(isA<MissingAppDataException>()));
    expect(
      () => location.resolve('   '),
      throwsA(isA<MissingAppDataException>()),
    );
  });

  test('résout un fichier démo distinct de la production', () {
    final appDataRoot = p.join('tmp', 'fake-appdata');
    final production = location.resolve(appDataRoot);
    final demo = location.resolveDemo(appDataRoot);

    expect(
      demo.path,
      p.join(
        appDataRoot,
        SqliteDatabasePath.directoryName,
        SqliteDatabasePath.demoFileName,
      ),
    );
    expect(demo.path, isNot(production.path));
  });

  test('refuse une racine APPDATA absente ou vide pour la démo', () {
    expect(
      () => location.resolveDemo(null),
      throwsA(isA<MissingAppDataException>()),
    );
    expect(
      () => location.resolveDemo(''),
      throwsA(isA<MissingAppDataException>()),
    );
    expect(
      () => location.resolveDemo('   '),
      throwsA(isA<MissingAppDataException>()),
    );
  });
}
