import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte une date civile valide', () {
    final date = CalendarDate(2026, 9, 17);

    expect(date.year, 2026);
    expect(date.month, 9);
    expect(date.day, 17);
    expect(date.toIso8601String(), '2026-09-17');
  });

  test('accepte le 29 février d’une année bissextile', () {
    expect(CalendarDate(2024, 2, 29).toIso8601String(), '2024-02-29');
    expect(CalendarDate(2000, 2, 29).toIso8601String(), '2000-02-29');
  });

  test('refuse une date civile impossible', () {
    expect(() => CalendarDate(2026, 2, 30), throwsA(isA<CalendarDateInvalid>()));
    expect(() => CalendarDate(2026, 4, 31), throwsA(isA<CalendarDateInvalid>()));
    expect(() => CalendarDate(2026, 13, 1), throwsA(isA<CalendarDateInvalid>()));
    expect(() => CalendarDate(2026, 0, 1), throwsA(isA<CalendarDateInvalid>()));
    expect(() => CalendarDate(2025, 2, 29), throwsA(isA<CalendarDateInvalid>()));
    expect(() => CalendarDate(1900, 2, 29), throwsA(isA<CalendarDateInvalid>()));
  });

  test('égalité par year/month/day', () {
    expect(CalendarDate(2026, 9, 17), CalendarDate(2026, 9, 17));
    expect(CalendarDate(2026, 9, 17), isNot(CalendarDate(2026, 9, 18)));
  });

  test('compare chronologiquement', () {
    final earlier = CalendarDate(2026, 9, 16);
    final later = CalendarDate(2026, 9, 17);

    expect(earlier < later, isTrue);
    expect(earlier <= later, isTrue);
    expect(later > earlier, isTrue);
    expect(later >= later, isTrue);
    expect(earlier.compareTo(later), lessThan(0));
    expect(CalendarDate(2025, 12, 31) < CalendarDate(2026, 1, 1), isTrue);
  });

  test('ISO round-trip YYYY-MM-DD', () {
    final parsed = CalendarDate.parseIso('2026-09-17');

    expect(parsed, CalendarDate(2026, 9, 17));
    expect(parsed.toIso8601String(), '2026-09-17');
    expect(CalendarDate.parseIso(parsed.toIso8601String()), parsed);
  });

  test('refuse un ISO qui n’est pas YYYY-MM-DD', () {
    expect(
      () => CalendarDate.parseIso('2026-9-17'),
      throwsA(isA<CalendarDateInvalid>()),
    );
    expect(
      () => CalendarDate.parseIso('17/09/2026'),
      throwsA(isA<CalendarDateInvalid>()),
    );
    expect(
      () => CalendarDate.parseIso('2026-09-17T00:00:00Z'),
      throwsA(isA<CalendarDateInvalid>()),
    );
  });
}
