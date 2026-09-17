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

  test('addMonths conserve le jour quand il existe', () {
    expect(
      CalendarDate(2026, 1, 15).addMonths(1),
      CalendarDate(2026, 2, 15),
    );
  });

  test('addMonths ramène le 31 janvier au dernier jour de février', () {
    expect(
      CalendarDate(2026, 1, 31).addMonths(1),
      CalendarDate(2026, 2, 28),
    );
    expect(
      CalendarDate(2028, 1, 31).addMonths(1),
      CalendarDate(2028, 2, 29),
    );
  });

  test('addMonths ramène le 31 mars au 30 avril', () {
    expect(
      CalendarDate(2026, 3, 31).addMonths(1),
      CalendarDate(2026, 4, 30),
    );
  });

  test('addMonths depuis le 29 février + 12 mois', () {
    expect(
      CalendarDate(2028, 2, 29).addMonths(12),
      CalendarDate(2029, 2, 28),
    );
  });

  test('addMonths traverse une année et accepte +60', () {
    expect(
      CalendarDate(2026, 12, 15).addMonths(1),
      CalendarDate(2027, 1, 15),
    );
    expect(
      CalendarDate(2026, 1, 15).addMonths(60),
      CalendarDate(2031, 1, 15),
    );
  });

  test('addMonths refuse un nombre de mois inférieur à 1', () {
    expect(
      () => CalendarDate(2026, 1, 15).addMonths(0),
      throwsA(isA<CalendarDateInvalid>()),
    );
  });

  test('fromLocalInstant lit year/month/day de l’instant local', () {
    final local = DateTime(2026, 9, 17, 8, 30);
    expect(CalendarDate.fromLocalInstant(local), CalendarDate(2026, 9, 17));

    final utc = DateTime.utc(2026, 9, 17, 10);
    final asLocal = utc.toLocal();
    expect(
      CalendarDate.fromLocalInstant(utc),
      CalendarDate(asLocal.year, asLocal.month, asLocal.day),
    );
  });

  test('addDays(0) renvoie la même date', () {
    final date = CalendarDate(2026, 9, 17);
    expect(date.addDays(0), date);
  });

  test('addDays traverse un mois, une année, février et une année bissextile', () {
    expect(CalendarDate(2026, 1, 31).addDays(1), CalendarDate(2026, 2, 1));
    expect(CalendarDate(2026, 12, 31).addDays(1), CalendarDate(2027, 1, 1));
    expect(CalendarDate(2026, 2, 28).addDays(1), CalendarDate(2026, 3, 1));
    expect(CalendarDate(2028, 2, 28).addDays(1), CalendarDate(2028, 2, 29));
    expect(CalendarDate(2028, 2, 29).addDays(1), CalendarDate(2028, 3, 1));
    expect(CalendarDate(2026, 9, 17).addDays(-1), CalendarDate(2026, 9, 16));
  });

  test('daysUntil est positif, négatif ou nul', () {
    final today = CalendarDate(2026, 9, 17);
    expect(today.daysUntil(CalendarDate(2026, 9, 24)), 7);
    expect(today.daysUntil(CalendarDate(2026, 9, 17)), 0);
    expect(today.daysUntil(CalendarDate(2026, 9, 15)), -2);
    expect(CalendarDate(2026, 2, 28).daysUntil(CalendarDate(2026, 3, 1)), 1);
    expect(CalendarDate(2028, 2, 28).daysUntil(CalendarDate(2028, 3, 1)), 2);
  });
}
