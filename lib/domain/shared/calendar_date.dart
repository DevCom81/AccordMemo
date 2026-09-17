final class CalendarDateInvalid implements Exception {
  const CalendarDateInvalid();

  @override
  String toString() => 'CalendarDateInvalid';
}

/// Date civile (année, mois, jour). Ce n'est pas un instant UTC.
final class CalendarDate implements Comparable<CalendarDate> {
  factory CalendarDate(int year, int month, int day) {
    if (year < 1 || year > 9999) {
      throw const CalendarDateInvalid();
    }
    if (month < 1 || month > 12) {
      throw const CalendarDateInvalid();
    }
    if (day < 1 || day > _daysInMonth(year, month)) {
      throw const CalendarDateInvalid();
    }
    return CalendarDate._(year, month, day);
  }

  factory CalendarDate.parseIso(String raw) {
    final value = raw.trim();
    final match = _isoPattern.firstMatch(value);
    if (match == null) {
      throw const CalendarDateInvalid();
    }
    return CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  const CalendarDate._(this.year, this.month, this.day);

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  String toIso8601String() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Ajoute [months] mois civils. Si le jour n'existe pas dans le mois cible,
  /// le dernier jour valide de ce mois est retenu.
  CalendarDate addMonths(int months) {
    if (months < 1) {
      throw const CalendarDateInvalid();
    }
    final totalMonths = year * 12 + (month - 1) + months;
    final newYear = totalMonths ~/ 12;
    final newMonth = (totalMonths % 12) + 1;
    if (newYear > 9999) {
      throw const CalendarDateInvalid();
    }
    final lastDay = _daysInMonth(newYear, newMonth);
    final newDay = day <= lastDay ? day : lastDay;
    return CalendarDate(newYear, newMonth, newDay);
  }

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  bool operator <(CalendarDate other) => compareTo(other) < 0;

  bool operator <=(CalendarDate other) => compareTo(other) <= 0;

  bool operator >(CalendarDate other) => compareTo(other) > 0;

  bool operator >=(CalendarDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601String();
}

int _daysInMonth(int year, int month) {
  const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _isLeapYear(year)) {
    return 29;
  }
  return lengths[month - 1];
}

bool _isLeapYear(int year) {
  return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}
