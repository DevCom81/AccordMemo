import 'package:accord_memo/application/reminder/recipient_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte une adresse utilisable', () {
    expect(RecipientEmail.tryParse('jean@example.com')?.value, 'jean@example.com');
    expect(RecipientEmail.tryParse('  marie@pianos.fr  ')?.value, 'marie@pianos.fr');
  });

  test('refuse vide, espaces, et chaîne non utilisable', () {
    expect(RecipientEmail.tryParse(null), isNull);
    expect(RecipientEmail.tryParse(''), isNull);
    expect(RecipientEmail.tryParse('   '), isNull);
    expect(RecipientEmail.tryParse('pas une adresse'), isNull);
    expect(RecipientEmail.tryParse('historique@invalide'), isNull);
    expect(RecipientEmail.isBlank(null), isTrue);
    expect(RecipientEmail.isBlank('  '), isTrue);
  });
}
