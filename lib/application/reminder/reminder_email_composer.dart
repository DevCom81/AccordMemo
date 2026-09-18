import '../../domain/shared/calendar_date.dart';
import '../ports/email_sender.dart';

const reminderEmailSubject =
    'Rappel d’entretien de votre piano - Pianos d’Occitanie';

const reminderCallbackLabel = 'Rappelez-moi pour prendre rendez-vous';

const reminderCallbackUrl = 'https://pianosoccitanie.fr/accordmemo/rappel';

const _reminderHtmlButtonColor = '#1E3A32';
const _reminderHtmlButtonTextColor = '#F6F1E8';

final class ReminderEmailComposer {
  const ReminderEmailComposer();

  OutgoingEmail compose({
    required String to,
    required CalendarDate dueDate,
  }) {
    final dueLabel = _formatFrenchDueDate(dueDate);
    return OutgoingEmail(
      to: to,
      subject: reminderEmailSubject,
      body: _plainBody(dueLabel),
      htmlBody: _htmlBody(dueLabel),
    );
  }

  String _plainBody(String dueLabel) {
    return 'Bonjour,\n'
        '\n'
        'Je me permets de vous rappeler que l’entretien / l’accord de votre '
        'piano est à prévoir.\n'
        '\n'
        'Échéance prévue : $dueLabel\n'
        '\n'
        'N’hésitez pas à me contacter pour convenir d’une date.\n'
        '\n'
        '$reminderCallbackLabel :\n'
        '$reminderCallbackUrl\n'
        '\n'
        'Cordialement,\n'
        '\n'
        'Éléonore\n'
        'Pianos d’Occitanie';
  }

  String _htmlBody(String dueLabel) {
    final due = _escapeHtml(dueLabel);
    return '<!DOCTYPE html>\n'
        '<html>\n'
        '<body style="font-family:Arial,sans-serif;color:#2A2622;line-height:1.5;">\n'
        '<p>Bonjour,</p>\n'
        '<p>Je me permets de vous rappeler que l’entretien / l’accord de votre '
        'piano est à prévoir.</p>\n'
        '<p>Échéance prévue : $due</p>\n'
        '<p>N’hésitez pas à me contacter pour convenir d’une date.</p>\n'
        '<table role="presentation" cellspacing="0" cellpadding="0" border="0">\n'
        '<tr>\n'
        '<td style="background-color:$_reminderHtmlButtonColor;border-radius:6px;">\n'
        '<a href="$reminderCallbackUrl" style="display:inline-block;padding:12px 20px;'
        'font-family:Arial,sans-serif;font-size:16px;color:$_reminderHtmlButtonTextColor;'
        'text-decoration:none;font-weight:bold;">$reminderCallbackLabel</a>\n'
        '</td>\n'
        '</tr>\n'
        '</table>\n'
        '<p>Cordialement,</p>\n'
        '<p>Éléonore<br>Pianos d’Occitanie</p>\n'
        '</body>\n'
        '</html>\n';
  }
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
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
