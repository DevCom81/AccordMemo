import 'package:accord_memo/application/reminder/reminder_email_composer.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compose le sujet et le corps V1 avec la date française', () {
    const composer = ReminderEmailComposer();
    final email = composer.compose(
      to: 'jean@example.com',
      dueDate: CalendarDate(2026, 9, 17),
    );

    expect(email.to, 'jean@example.com');
    expect(email.subject, reminderEmailSubject);
    expect(
      email.body,
      contains('Je me permets de vous rappeler que l’entretien / l’accord'),
    );
    expect(email.body, contains('Échéance prévue : Jeudi 17 septembre 2026'));
    expect(email.body, contains('Éléonore'));
    expect(email.body, contains('Pianos d’Occitanie'));
  });
}
