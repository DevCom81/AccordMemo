import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le domaine ignore Gmail, OAuth et le stockage secret', () {
    final files = Directory('lib/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source.contains('googleapis'), isFalse, reason: file.path);
      expect(source.contains('gmail'), isFalse, reason: file.path);
      expect(source.contains('OAuth'), isFalse, reason: file.path);
      expect(source.contains('flutter_secure_storage'), isFalse, reason: file.path);
    }
  });

  test('la démo n’utilise jamais Gmail réel', () {
    final source = File('lib/main_demo.dart').readAsStringSync();
    expect(source.contains('FakeEmailSender'), isTrue);
    expect(source.contains('FakeGoogleAuthSession'), isTrue);
    expect(source.contains('GmailEmailSender'), isFalse);
    expect(source.contains('googleapis'), isFalse);
  });

  test('le mode démo branche FakeEmailSender dans les providers', () {
    final source = File('lib/presentation/app_providers.dart').readAsStringSync();
    expect(source.contains('FakeEmailSender'), isTrue);
    expect(source.contains('demoModeProvider'), isTrue);
  });
}
