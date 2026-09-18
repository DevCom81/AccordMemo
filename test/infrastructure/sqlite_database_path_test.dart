import 'package:accord_memo/infrastructure/persistence/sqlite_database_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const location = SqliteDatabasePath();

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
