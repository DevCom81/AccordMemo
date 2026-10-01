import 'package:accord_memo/infrastructure/files/android_backup_file_access.dart';
import 'package:accord_memo/infrastructure/files/file_selector_location_picker.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('accordmemo/backup_documents');
  const access = AndroidBackupFileAccess();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() => calls.clear());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('export : nom proposé, fichier privé, publication puis nettoyage', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'create') {
        return {'id': 'selection', 'path': '/private/staging/backup.db'};
      }
      return null;
    });

    final selection = await access.selectSave(
      suggestedFileName: 'AccordMemo_backup_2026-10-01_14-30.db',
    );
    expect(selection, isNotNull);
    expect(selection!.localPath, '/private/staging/backup.db');
    expect(calls.single.arguments, {
      'name': 'AccordMemo_backup_2026-10-01_14-30.db',
    });
    await selection.commit();
    await selection.dispose();
    expect(calls.map((call) => call.method), ['create', 'commit', 'dispose']);
    expect(calls[1].arguments, {'id': 'selection'});
    expect(calls[2].arguments, {'id': 'selection'});
  });

  test('import : sélection privée puis nettoyage, sans publication', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'open'
          ? {'id': 'import', 'path': '/private/staging/backup.db'}
          : null;
    });
    final selection = await access.selectOpen();
    expect(selection!.localPath, '/private/staging/backup.db');
    await selection.dispose();
    expect(calls.map((call) => call.method), ['open', 'dispose']);
    expect(calls.last.arguments, {'id': 'import'});
  });

  test('annulations du sélecteur natif', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await access.selectSave(suggestedFileName: 'copy.db'), isNull);
    expect(await access.selectOpen(), isNull);
  });

  test('erreurs de sélection et écriture propagées au service', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'create') {
        return {'id': 'export', 'path': '/private/staging/backup.db'};
      }
      throw PlatformException(code: 'provider_unavailable');
    });
    await expectLater(access.selectOpen(), throwsA(isA<PlatformException>()));
    final selection = await access.selectSave(suggestedFileName: 'copy.db');
    await expectLater(selection!.commit(), throwsA(isA<PlatformException>()));
  });

  for (final android in [false, true]) {
    test('infrastructure ${android ? 'Android' : 'Windows'} sélectionnée', () {
      final container = ProviderContainer(overrides: [
        backupOnAndroidProvider.overrideWith((ref) => android),
      ]);
      addTearDown(container.dispose);
      expect(
        container.read(backupFileAccessProvider),
        android ? isA<AndroidBackupFileAccess>() : isNull,
      );
      expect(
        container.read(fileLocationPickerProvider),
        isA<FileSelectorLocationPicker>(),
      );
    });
  }
}
