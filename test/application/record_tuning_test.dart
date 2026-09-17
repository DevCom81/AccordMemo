import 'package:accord_memo/application/ports/transaction_runner.dart';
import 'package:accord_memo/application/tuning/record_tuning.dart';
import 'package:accord_memo/application/tuning/tuning_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';
import '../support/in_memory_tuning_repository.dart';

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
  late InMemoryTuningRepository tunings;
  late InMemoryReminderRepository reminders;
  late _CountingTransactionRunner transactions;
  late RecordTuning recordTuning;
  late TuningService tuningService;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    pianos = InMemoryPianoRepository();
    tunings = InMemoryTuningRepository();
    reminders = InMemoryReminderRepository();
    transactions = _CountingTransactionRunner();
    recordTuning = RecordTuning(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        '99999999-9999-4999-8999-999999999999',
      ]),
      transactions: transactions,
      tunings: tunings,
      pianos: pianos,
      reminders: reminders,
    );
    tuningService = TuningService(tunings: tunings);
  });

  Future<Piano> insertPiano({
    bool archived = false,
    bool remindersEnabled = true,
    int interval = Piano.defaultReminderIntervalMonths,
  }) async {
    var piano = Piano.create(
      id: PianoId('piano-1'),
      customerId: CustomerId('customer-1'),
      brand: 'Yamaha',
      reminderIntervalMonths: interval,
      remindersEnabled: remindersEnabled,
      now: now,
    );
    if (archived) {
      piano = piano.archive(now);
    }
    await pianos.insert(piano);
    return piano;
  }

  CalendarDate todayFromClock() {
    final local = now.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  test('génère un id, passe par TransactionRunner et crée le Reminder', () async {
    final piano = await insertPiano();
    final today = todayFromClock();

    final tuning = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: today,
    );

    expect(tuning.id.value, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
    expect(tuning.createdAt, now);
    expect(transactions.calls, 1);

    final reminder = await reminders.findScheduledByPianoId(piano.id);
    expect(reminder, isNotNull);
    expect(reminder!.originTuningId, tuning.id);
    expect(reminder.pianoId, piano.id);
    expect(reminder.pianoId, tuning.pianoId);
    expect(reminder.dueDate, today.addMonths(12));
    expect(reminder.status, ReminderStatus.scheduled);
    expect(reminder.manuallyRescheduled, isFalse);
  });

  test('refuse un piano inexistant', () async {
    await expectLater(
      recordTuning.execute(
        pianoId: PianoId('missing'),
        tuningDate: todayFromClock(),
      ),
      throwsA(isA<PianoNotFound>()),
    );
  });

  test('accepte un piano actif et un piano archivé', () async {
    final active = await insertPiano();
    final activeTuning = await recordTuning.execute(
      pianoId: active.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    expect(activeTuning.pianoId, active.id);
    expect(await tuningService.getById(activeTuning.id), isNotNull);

    final archived = Piano.create(
      id: PianoId('piano-2'),
      customerId: CustomerId('customer-1'),
      brand: 'Kawai',
      now: now,
    ).archive(now);
    await pianos.insert(archived);
    final archivedTuning = await recordTuning.execute(
      pianoId: archived.id,
      tuningDate: CalendarDate(2025, 6, 1),
      notes: 'saisie rétroactive',
    );
    expect(archivedTuning.notes, 'saisie rétroactive');
  });

  test('ne crée pas de Reminder si remindersEnabled est false', () async {
    final piano = await insertPiano(remindersEnabled: false);

    await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );

    expect(await reminders.findScheduledByPianoId(piano.id), isNull);
  });

  test('annule le scheduled précédent puis crée le nouveau si enabled', () async {
    final piano = await insertPiano();
    final first = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2025, 1, 1),
    );
    final firstReminder = await reminders.findByOriginTuningId(first.id);
    expect(firstReminder, isNotNull);

    final second = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 3, 1),
    );

    final cancelled = await reminders.findById(firstReminder!.id);
    expect(cancelled!.status, ReminderStatus.cancelled);
    expect(
      cancelled.cancellationReason,
      ReminderCancellationReason.supersededByTuning,
    );

    final current = await reminders.findScheduledByPianoId(piano.id);
    expect(current, isNotNull);
    expect(current!.originTuningId, second.id);
    expect(current.dueDate, CalendarDate(2026, 3, 1).addMonths(12));
  });

  test('refuse une date future dérivée du Clock applicatif', () async {
    final piano = await insertPiano();

    await expectLater(
      recordTuning.execute(
        pianoId: piano.id,
        tuningDate: CalendarDate(2099, 1, 1),
      ),
      throwsA(isA<TuningDateInFuture>()),
    );
  });
}
