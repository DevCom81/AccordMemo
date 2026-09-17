import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);
  final pianoId = PianoId('piano-1');
  final today = CalendarDate(2026, 9, 17);

  Tuning newTuning({
    CalendarDate? tuningDate,
    CalendarDate? todayOverride,
    String? notes,
    DateTime? clock,
  }) {
    return Tuning.create(
      id: TuningId('tuning-1'),
      pianoId: pianoId,
      tuningDate: tuningDate ?? today,
      today: todayOverride ?? today,
      notes: notes,
      now: clock ?? now,
    );
  }

  test('refuse un TuningId vide', () {
    expect(() => TuningId('  '), throwsA(isA<TuningIdInvalid>()));
  });

  test('crée un accord effectué', () {
    final tuning = newTuning(notes: 'Diapason 440 Hz');

    expect(tuning.pianoId, pianoId);
    expect(tuning.tuningDate, today);
    expect(tuning.notes, 'Diapason 440 Hz');
    expect(tuning.createdAt, now);
    expect(tuning.updatedAt, now);
    expect(tuning.createdAt.isUtc, isTrue);
  });

  test('normalise les notes : trim et vide → null', () {
    expect(newTuning(notes: '  corde cassée  ').notes, 'corde cassée');
    expect(newTuning(notes: '   ').notes, isNull);
    expect(newTuning().notes, isNull);
  });

  test('conserve pianoId à la correction', () {
    final corrected = newTuning().changeDetails(
      tuningDate: CalendarDate(2026, 9, 16),
      today: today,
      notes: 'corrigé',
      now: now.add(const Duration(hours: 1)),
    );

    expect(corrected.pianoId, pianoId);
    expect(corrected.id, TuningId('tuning-1'));
    expect(corrected.tuningDate, CalendarDate(2026, 9, 16));
    expect(corrected.notes, 'corrigé');
    expect(corrected.createdAt, now);
    expect(corrected.updatedAt, now.add(const Duration(hours: 1)));
  });

  test('accepte une date passée et aujourd’hui', () {
    expect(
      newTuning(tuningDate: CalendarDate(2025, 1, 15)).tuningDate,
      CalendarDate(2025, 1, 15),
    );
    expect(newTuning(tuningDate: today).tuningDate, today);
  });

  test('refuse une date future à la création et à la correction', () {
    final future = CalendarDate(2026, 9, 18);

    expect(
      () => newTuning(tuningDate: future),
      throwsA(isA<TuningDateInFuture>()),
    );
    expect(
      () => newTuning().changeDetails(
        tuningDate: future,
        today: today,
        now: now,
      ),
      throwsA(isA<TuningDateInFuture>()),
    );
  });

  test('stocke les timestamps techniques en UTC', () {
    final local = DateTime(2026, 9, 17, 12);
    final tuning = newTuning(clock: local);

    expect(tuning.createdAt.isUtc, isTrue);
    expect(tuning.updatedAt.isUtc, isTrue);
    expect(tuning.createdAt, local.toUtc());
  });
}
