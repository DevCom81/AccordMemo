import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/application/ports/transaction_runner.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';

final class _CountingTransactionRunner implements TransactionRunner {
  var calls = 0;

  @override
  Future<T> run<T>(Future<T> Function() action) {
    calls += 1;
    return action();
  }
}

void main() {
  late InMemoryPianoRepository pianos;
  late InMemoryReminderRepository reminders;
  late InMemoryActivityRepository activities;
  late _CountingTransactionRunner transactions;
  late ReminderService service;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    pianos = InMemoryPianoRepository();
    reminders = InMemoryReminderRepository();
    activities = InMemoryActivityRepository(pianos);
    transactions = _CountingTransactionRunner();
    service = ReminderService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator(spareIds()),
      transactions: transactions,
      reminders: reminders,
      activities: activities,
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

  test('reschedule crée une Activity reminderRescheduled via TransactionRunner', () async {
    final created = await insertScheduled();
    final callsBefore = transactions.calls;
    await service.reschedule(
      id: created.id,
      newDueDate: CalendarDate(2026, 12, 1),
    );

    expect(transactions.calls, callsBefore + 1);
    final journal = await activities.findRecent(limit: 10);
    expect(journal, hasLength(1));
    expect(journal.single.type, ActivityType.reminderRescheduled);
    expect(journal.single.reminderId, created.id);
    expect(journal.single.previousDate, CalendarDate(2027, 9, 17));
    expect(journal.single.newDate, CalendarDate(2026, 12, 1));
  });

  test('markSent crée reminderSent, cancel ne crée aucune Activity', () async {
    final created = await insertScheduled();
    final callsBeforeSent = transactions.calls;
    final sent = await service.markSent(created.id);
    expect(sent.status, ReminderStatus.sent);
    expect(sent.sentAt, now);
    expect(transactions.calls, callsBeforeSent + 1);

    final sentJournal = await activities.findRecent(limit: 10);
    expect(sentJournal, hasLength(1));
    expect(sentJournal.single.type, ActivityType.reminderSent);

    final other = Reminder.schedule(
      id: ReminderId('reminder-2'),
      pianoId: PianoId('piano-1'),
      originTuningId: TuningId('tuning-2'),
      dueDate: CalendarDate(2027, 9, 17),
      now: now,
    );
    await reminders.insert(other);
    final callsBeforeCancel = transactions.calls;
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
    expect(transactions.calls, callsBeforeCancel);
    expect(await activities.findRecent(limit: 10), hasLength(1));
  });

  test('signale un reminder introuvable', () async {
    await expectLater(
      service.markSent(ReminderId('missing')),
      throwsA(isA<ReminderNotFound>()),
    );
  });
}
