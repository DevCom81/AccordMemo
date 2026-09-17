import 'package:accord_memo/application/ports/transaction_runner.dart';
import 'package:accord_memo/application/tuning/correct_tuning.dart';
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
  late CorrectTuning correctTuning;
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
    correctTuning = CorrectTuning(
      clock: FixedClock(now),
      transactions: transactions,
      tunings: tunings,
      pianos: pianos,
      reminders: reminders,
    );
    tuningService = TuningService(tunings: tunings);
  });

  Future<Piano> insertPiano() async {
    final piano = Piano.create(
      id: PianoId('piano-1'),
      customerId: CustomerId('customer-1'),
      brand: 'Yamaha',
      now: now,
    );
    await pianos.insert(piano);
    return piano;
  }

  test('notes seulement : Reminder inchangé, pas de transaction extra', () async {
    final piano = await insertPiano();
    final tuning = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    final before = await reminders.findScheduledByPianoId(piano.id);
    final callsAfterCreate = transactions.calls;

    final corrected = await correctTuning.execute(
      id: tuning.id,
      tuningDate: CalendarDate(2026, 1, 5),
      notes: 'diapason 440',
    );

    expect(corrected.notes, 'diapason 440');
    expect(corrected.tuningDate, CalendarDate(2026, 1, 5));
    expect(transactions.calls, callsAfterCreate);
    final after = await reminders.findScheduledByPianoId(piano.id);
    expect(after!.dueDate, before!.dueDate);
    expect(after.updatedAt, before.updatedAt);
  });

  test('date changée + automatique → recalcul dans une transaction', () async {
    final piano = await insertPiano();
    final tuning = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    final callsAfterCreate = transactions.calls;

    final corrected = await correctTuning.execute(
      id: tuning.id,
      tuningDate: CalendarDate(2025, 6, 1),
      notes: 'date corrigée',
    );

    expect(corrected.tuningDate, CalendarDate(2025, 6, 1));
    expect(transactions.calls, callsAfterCreate + 1);
    final reminder = await reminders.findScheduledByPianoId(piano.id);
    expect(reminder!.dueDate, CalendarDate(2026, 6, 1));
    expect(reminder.manuallyRescheduled, isFalse);
  });

  test('date changée + manuel → dueDate conservée', () async {
    final piano = await insertPiano();
    final tuning = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    final reminder = await reminders.findScheduledByPianoId(piano.id);
    await reminders.update(
      reminder!.reschedule(
        newDueDate: CalendarDate(2026, 11, 1),
        today: CalendarDate(2026, 9, 17),
        now: now,
      ),
    );

    await correctTuning.execute(
      id: tuning.id,
      tuningDate: CalendarDate(2025, 6, 1),
    );

    final kept = await reminders.findScheduledByPianoId(piano.id);
    expect(kept!.dueDate, CalendarDate(2026, 11, 1));
    expect(kept.manuallyRescheduled, isTrue);
  });

  test('sent et cancelled restent inchangés', () async {
    final piano = await insertPiano();
    final first = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2025, 1, 1),
    );
    final sent = (await reminders.findScheduledByPianoId(piano.id))!.markSent(now);
    await reminders.update(sent);

    await correctTuning.execute(
      id: first.id,
      tuningDate: CalendarDate(2024, 12, 1),
    );
    expect((await reminders.findById(sent.id))!.status, ReminderStatus.sent);
    expect((await reminders.findById(sent.id))!.dueDate, sent.dueDate);

    final second = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 3, 1),
    );
    final scheduled = await reminders.findScheduledByPianoId(piano.id);
    final cancelled = scheduled!.cancel(
      reason: ReminderCancellationReason.remindersDisabled,
      now: now,
    );
    await reminders.update(cancelled);

    await correctTuning.execute(
      id: second.id,
      tuningDate: CalendarDate(2026, 2, 1),
    );
    expect((await reminders.findById(cancelled.id))!.status, ReminderStatus.cancelled);
    expect((await reminders.findById(cancelled.id))!.dueDate, cancelled.dueDate);
  });

  test('refuse la correction d’un accord inexistant', () async {
    await expectLater(
      correctTuning.execute(
        id: TuningId('missing'),
        tuningDate: CalendarDate(2026, 1, 1),
      ),
      throwsA(isA<TuningNotFound>()),
    );
  });

  test('findByPiano liste les accords du plus récent au plus ancien', () async {
    final piano = await insertPiano();
    final older = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2025, 1, 1),
    );
    final newer = await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 3, 1),
    );

    final listed = await tuningService.findByPiano(piano.id);
    expect(listed.map((item) => item.id), [newer.id, older.id]);
  });
}
