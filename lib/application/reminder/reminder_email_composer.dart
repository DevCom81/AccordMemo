import '../../domain/shared/calendar_date.dart';
import '../ports/email_sender.dart';

const reminderEmailSubject =
    'Rappel d’entretien de votre piano - Pianos d’Occitanie';

final class ReminderEmailComposer {
  const ReminderEmailComposer();

  OutgoingEmail compose({
    required String to,
    required CalendarDate dueDate,
  }) {
    return OutgoingEmail(
      to: to,
      subject: reminderEmailSubject,
      body: _body(dueDate),
    );
  }

  String _body(CalendarDate dueDate) {
    return 'Bonjour,\n'
        '\n'
        'Je me permets de vous rappeler que l’entretien / l’accord de votre '
        'piano est à prévoir.\n'
        '\n'
        'Échéance prévue : ${_formatFrenchDueDate(dueDate)}\n'
        '\n'
        'N’hésitez pas à me contacter pour convenir d’une date.\n'
        '\n'
        'Cordialement,\n'
        '\n'
        'Éléonore\n'
        'Pianos d’Occitanie';
  }
}

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _formatFrenchDueDate(CalendarDate date) {
  final weekday = DateTime(date.year, date.month, date.day).weekday;
  final raw =
      '${_weekdays[weekday - 1]} ${date.day} ${_months[date.month - 1]} ${date.year}';
  return '${raw[0].toUpperCase()}${raw.substring(1)}';
}
