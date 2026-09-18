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

  test('ajoute le CTA et l’URL fixe dans le texte et le HTML', () {
    const composer = ReminderEmailComposer();
    final email = composer.compose(
      to: 'jean@example.com',
      dueDate: CalendarDate(2026, 9, 17),
    );

    expect(email.body, contains(reminderCallbackLabel));
    expect(email.body, contains(reminderCallbackUrl));
    expect(reminderCallbackUrl.contains('?'), isFalse);
    expect(Uri.parse(reminderCallbackUrl).hasQuery, isFalse);
    expect(email.body, isNot(contains('$reminderCallbackUrl?')));

    final html = email.htmlBody!;
    expect(html, contains(reminderCallbackLabel));
    expect(html, contains('href="$reminderCallbackUrl"'));
    expect(html, isNot(contains('$reminderCallbackUrl?')));
    expect(html.contains('<script'), isFalse);
    expect(html.contains('src='), isFalse);
    expect(html.contains('javascript:'), isFalse);
  });
}
