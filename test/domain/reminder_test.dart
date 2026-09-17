import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);
  final today = CalendarDate(2026, 9, 17);
  final pianoId = PianoId('piano-1');
  final tuningId = TuningId('tuning-1');
  final dueDate = CalendarDate(2027, 9, 17);

  Reminder scheduled() {
    return Reminder.schedule(
      id: ReminderId('reminder-1'),
      pianoId: pianoId,
      originTuningId: tuningId,
      dueDate: dueDate,
      now: now,
    );
  }

  test('crée une relance scheduled automatique', () {
    final reminder = scheduled();

    expect(reminder.status, ReminderStatus.scheduled);
    expect(reminder.manuallyRescheduled, isFalse);
    expect(reminder.dueDate, dueDate);
    expect(reminder.pianoId, pianoId);
    expect(reminder.originTuningId, tuningId);
    expect(reminder.sentAt, isNull);
    expect(reminder.cancelledAt, isNull);
    expect(reminder.cancellationReason, isNull);
    expect(reminder.createdAt, now);
    expect(reminder.updatedAt, now);
    expect(reminder.createdAt.isUtc, isTrue);
  });

  test('reschedule accepte aujourd’hui et le futur, et devient manuel', () {
    final todayRescheduled = scheduled().reschedule(
      newDueDate: today,
      today: today,
      now: now.add(const Duration(hours: 1)),
    );
    expect(todayRescheduled.dueDate, today);
    expect(todayRescheduled.manuallyRescheduled, isTrue);
    expect(todayRescheduled.status, ReminderStatus.scheduled);

    final future = scheduled().reschedule(
      newDueDate: CalendarDate(2026, 10, 1),
      today: today,
      now: now,
    );
    expect(future.dueDate, CalendarDate(2026, 10, 1));
    expect(future.manuallyRescheduled, isTrue);
  });

  test('reschedule refuse une date passée', () {
    expect(
      () => scheduled().reschedule(
        newDueDate: CalendarDate(2026, 9, 16),
        today: today,
        now: now,
      ),
      throwsA(isA<ReminderDueDateInPast>()),
    );
  });

  test('markSent pose sentAt UTC et fige le cycle', () {
    final local = DateTime(2026, 9, 17, 12);
    final sent = scheduled().markSent(local);

    expect(sent.status, ReminderStatus.sent);
    expect(sent.sentAt, local.toUtc());
    expect(sent.sentAt!.isUtc, isTrue);
    expect(sent.updatedAt.isUtc, isTrue);
    expect(sent.cancelledAt, isNull);
    expect(
      () => sent.reschedule(newDueDate: today, today: today, now: now),
      throwsA(isA<ReminderAlreadySent>()),
    );
    expect(
      () => sent.markSent(now),
      throwsA(isA<ReminderAlreadySent>()),
    );
    expect(
      () => sent.cancel(
        reason: ReminderCancellationReason.remindersDisabled,
        now: now,
      ),
      throwsA(isA<ReminderAlreadySent>()),
    );
  });

  test('cancel pose cancelledAt, la reason, et fige le cycle', () {
    final local = DateTime(2026, 9, 17, 12);
    final cancelled = scheduled().cancel(
      reason: ReminderCancellationReason.pianoArchived,
      now: local,
    );

    expect(cancelled.status, ReminderStatus.cancelled);
    expect(cancelled.cancellationReason, ReminderCancellationReason.pianoArchived);
    expect(cancelled.cancelledAt, local.toUtc());
    expect(cancelled.cancelledAt!.isUtc, isTrue);
    expect(cancelled.updatedAt.isUtc, isTrue);
    expect(cancelled.sentAt, isNull);
    expect(
      () => cancelled.reschedule(newDueDate: today, today: today, now: now),
      throwsA(isA<ReminderAlreadyCancelled>()),
    );
    expect(
      () => cancelled.markSent(now),
      throwsA(isA<ReminderAlreadyCancelled>()),
    );
    expect(
      () => cancelled.cancel(
        reason: ReminderCancellationReason.remindersDisabled,
        now: now,
      ),
      throwsA(isA<ReminderAlreadyCancelled>()),
    );
  });
}
