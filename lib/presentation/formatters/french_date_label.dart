import '../../domain/shared/calendar_date.dart';

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

const _shortMonths = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juill.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String formatFrenchLongDate(CalendarDate date) {
  final weekday = DateTime(date.year, date.month, date.day).weekday;
  final raw =
      '${_weekdays[weekday - 1]} ${date.day} ${_months[date.month - 1]} ${date.year}';
  return '${raw[0].toUpperCase()}${raw.substring(1)}';
}

String formatFrenchShortDate(CalendarDate date) {
  return '${date.day} ${_shortMonths[date.month - 1]} ${date.year}';
}

String formatDueRelative({
  required CalendarDate today,
  required CalendarDate dueDate,
}) {
  final days = today.daysUntil(dueDate);
  if (days < 0) {
    final late = -days;
    return late == 1 ? '1 jour de retard' : '$late jours de retard';
  }
  if (days == 0) {
    return 'aujourd’hui';
  }
  if (days == 1) {
    return 'dans 1 jour';
  }
  return 'dans $days jours';
}
