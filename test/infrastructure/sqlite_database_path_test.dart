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
}
