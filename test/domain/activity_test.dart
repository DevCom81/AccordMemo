import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/activity/activity_repository.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);
  final pianoId = PianoId('piano-1');
  final tuningId = TuningId('tuning-1');
  final reminderId = ReminderId('reminder-1');

  test('refuse un ActivityId vide', () {
    expect(() => ActivityId('  '), throwsA(isA<ActivityIdInvalid>()));
  });

  test('tuningCreated a les relations valides', () {
    final activity = Activity.tuningCreated(
      id: ActivityId('activity-1'),
      pianoId: pianoId,
      tuningId: tuningId,
      now: now,
    );

    expect(activity.type, ActivityType.tuningCreated);
    expect(activity.pianoId, pianoId);
    expect(activity.tuningId, tuningId);
    expect(activity.reminderId, isNull);
    expect(activity.previousDate, isNull);
    expect(activity.newDate, isNull);
    expect(activity.occurredAt, now);
    expect(activity.occurredAt.isUtc, isTrue);
  });

  test('tuningUpdated avec dates et notes seules', () {
    final withDates = Activity.tuningUpdated(
      id: ActivityId('activity-1'),
      pianoId: pianoId,
      tuningId: tuningId,
      previousDate: CalendarDate(2026, 9, 17),
      newDate: CalendarDate(2026, 9, 18),
      now: now,
    );
    expect(withDates.previousDate, CalendarDate(2026, 9, 17));
    expect(withDates.newDate, CalendarDate(2026, 9, 18));
    expect(withDates.reminderId, isNull);

    final notesOnly = Activity.tuningUpdated(
      id: ActivityId('activity-2'),
      pianoId: pianoId,
      tuningId: tuningId,
      now: now,
    );
    expect(notesOnly.previousDate, isNull);
    expect(notesOnly.newDate, isNull);
  });

  test('tuningUpdated refuse une seule date renseignée', () {
    expect(
      () => Activity.tuningUpdated(
        id: ActivityId('activity-1'),
        pianoId: pianoId,
        tuningId: tuningId,
        previousDate: CalendarDate(2026, 9, 17),
        now: now,
      ),
      throwsA(isA<ActivityInvariantViolated>()),
    );
  });

  test('reminderRescheduled exige previousDate et newDate', () {
    final activity = Activity.reminderRescheduled(
      id: ActivityId('activity-1'),
      pianoId: pianoId,
      reminderId: reminderId,
      previousDate: CalendarDate(2027, 9, 17),
      newDate: CalendarDate(2027, 10, 1),
      now: now,
    );
    expect(activity.type, ActivityType.reminderRescheduled);
    expect(activity.tuningId, isNull);
    expect(activity.reminderId, reminderId);
    expect(activity.previousDate, CalendarDate(2027, 9, 17));
    expect(activity.newDate, CalendarDate(2027, 10, 1));

    expect(
      () => Activity.reconstitute(
        id: ActivityId('activity-2'),
        type: ActivityType.reminderRescheduled,
        pianoId: pianoId,
        reminderId: reminderId,
        occurredAt: now,
      ),
      throwsA(isA<ActivityInvariantViolated>()),
    );
  });

  test('reminderSent, reminderDisabled et reminderReenabled', () {
    final sent = Activity.reminderSent(
      id: ActivityId('activity-1'),
      pianoId: pianoId,
      reminderId: reminderId,
      now: DateTime(2026, 9, 17, 12),
    );
    expect(sent.type, ActivityType.reminderSent);
    expect(sent.occurredAt.isUtc, isTrue);
    expect(sent.tuningId, isNull);
    expect(sent.previousDate, isNull);

    final disabled = Activity.reminderDisabled(
      id: ActivityId('activity-2'),
      pianoId: pianoId,
      now: now,
    );
    expect(disabled.type, ActivityType.reminderDisabled);
    expect(disabled.reminderId, isNull);

    final reenabled = Activity.reminderReenabled(
      id: ActivityId('activity-3'),
      pianoId: pianoId,
      now: now,
    );
    expect(reenabled.type, ActivityType.reminderReenabled);
    expect(reenabled.tuningId, isNull);
  });

  test('refuse un limit <= 0', () {
    expect(
      () => requirePositiveActivityLimit(0),
      throwsA(isA<ActivityLimitInvalid>()),
    );
    expect(
      () => requirePositiveActivityLimit(-1),
      throwsA(isA<ActivityLimitInvalid>()),
    );
  });

  test('refuse des relations incompatibles avec le type', () {
    expect(
      () => Activity.reconstitute(
        id: ActivityId('activity-1'),
        type: ActivityType.tuningCreated,
        pianoId: pianoId,
        reminderId: reminderId,
        occurredAt: now,
      ),
      throwsA(isA<ActivityInvariantViolated>()),
    );
    expect(
      () => Activity.reconstitute(
        id: ActivityId('activity-2'),
        type: ActivityType.reminderDisabled,
        pianoId: pianoId,
        tuningId: tuningId,
        occurredAt: now,
      ),
      throwsA(isA<ActivityInvariantViolated>()),
    );
  });
}
