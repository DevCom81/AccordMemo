import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_clock.dart';
import '../support/in_memory_reminder_repository.dart';

void main() {
  late InMemoryReminderRepository reminders;
  late ReminderService service;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    reminders = InMemoryReminderRepository();
    service = ReminderService(
      clock: FixedClock(now),
      reminders: reminders,
    );
  });

  CalendarDate todayFromClock() {
    final local = now.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  Future<Reminder> insertScheduled() async {
    final reminder = Reminder.schedule(
      id: ReminderId('reminder-1'),
      pianoId: PianoId('piano-1'),
      originTuningId: TuningId('tuning-1'),
      dueDate: CalendarDate(2027, 9, 17),
      now: now,
    );
    await reminders.insert(reminder);
    return reminder;
  }

  test('reschedule aujourd’hui et futur, refuse le passé', () async {
    final created = await insertScheduled();
    final today = todayFromClock();

    final sameDay = await service.reschedule(
      id: created.id,
      newDueDate: today,
    );
    expect(sameDay.dueDate, today);
    expect(sameDay.manuallyRescheduled, isTrue);

    final future = await service.reschedule(
      id: created.id,
      newDueDate: CalendarDate(2026, 12, 1),
    );
    expect(future.dueDate, CalendarDate(2026, 12, 1));

    await expectLater(
      service.reschedule(
        id: created.id,
        newDueDate: CalendarDate(2020, 1, 1),
      ),
      throwsA(isA<ReminderDueDateInPast>()),
    );
  });

  test('markSent et cancel', () async {
    final created = await insertScheduled();
    final sent = await service.markSent(created.id);
    expect(sent.status, ReminderStatus.sent);
    expect(sent.sentAt, now);

    final other = Reminder.schedule(
      id: ReminderId('reminder-2'),
      pianoId: PianoId('piano-1'),
      originTuningId: TuningId('tuning-2'),
      dueDate: CalendarDate(2027, 9, 17),
      now: now,
    );
    await reminders.insert(other);
    final cancelled = await service.cancel(
      id: other.id,
      reason: ReminderCancellationReason.remindersDisabled,
    );
    expect(cancelled.status, ReminderStatus.cancelled);
    expect(
      cancelled.cancellationReason,
      ReminderCancellationReason.remindersDisabled,
    );
    expect(await service.findScheduledByPiano(PianoId('piano-1')), isNull);
  });

  test('signale un reminder introuvable', () async {
    await expectLater(
      service.markSent(ReminderId('missing')),
      throwsA(isA<ReminderNotFound>()),
    );
  });
}
