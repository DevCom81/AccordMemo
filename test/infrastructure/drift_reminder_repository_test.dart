import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_reminder_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_tuning_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCustomerRepository customers;
  late DriftPianoRepository pianos;
  late DriftTuningRepository tunings;
  late DriftReminderRepository reminders;
  final now = DateTime.utc(2026, 9, 17, 10);
  final today = CalendarDate(2026, 9, 17);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
    reminders = DriftReminderRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Piano> insertPiano({
    String pianoId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  }) async {
    final customer = Customer.create(
      id: CustomerId('11111111-1111-4111-8111-111111111111'),
      lastName: 'Dupont',
      now: now,
    );
    await customers.insert(customer);
    final piano = Piano.create(
      id: PianoId(pianoId),
      customerId: customer.id,
      brand: 'Yamaha',
      now: now,
    );
    await pianos.insert(piano);
    return piano;
  }

  Future<Tuning> insertTuning({
    required PianoId pianoId,
    String id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    CalendarDate? tuningDate,
  }) async {
    final tuning = Tuning.create(
      id: TuningId(id),
      pianoId: pianoId,
      tuningDate: tuningDate ?? today,
      today: today,
      now: now,
    );
    await tunings.insert(tuning);
    return tuning;
  }

  Reminder scheduledOf({
    required Piano piano,
    required Tuning tuning,
    String id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  }) {
    return Reminder.schedule(
      id: ReminderId(id),
      pianoId: piano.id,
      originTuningId: tuning.id,
      dueDate: tuning.tuningDate.addMonths(12),
      now: now,
    );
  }

  test('insert, findById, update, ISO dueDate, relations cohérentes', () async {
    final piano = await insertPiano();
    final tuning = await insertTuning(pianoId: piano.id);
    final created = scheduledOf(piano: piano, tuning: tuning);
    await reminders.insert(created);

    final loaded = await reminders.findById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.pianoId, piano.id);
    expect(loaded.originTuningId, tuning.id);
    expect(loaded.pianoId, tuning.pianoId);
    expect(loaded.dueDate, CalendarDate(2027, 9, 17));
    expect(loaded.status, ReminderStatus.scheduled);

    final stored = await database
        .customSelect('SELECT due_date FROM reminders')
        .getSingle();
    expect(stored.read<String>('due_date'), '2027-09-17');

    final sent = created.markSent(now.add(const Duration(days: 1)));
    await reminders.update(sent);
    expect((await reminders.findById(created.id))!.status, ReminderStatus.sent);
  });

  test('FK empêche un reminder orphelin de piano ou de tuning', () async {
    final piano = await insertPiano();
    final tuning = await insertTuning(pianoId: piano.id);

    await expectLater(
      reminders.insert(
        Reminder.schedule(
          id: ReminderId('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
          pianoId: PianoId('99999999-9999-4999-8999-999999999999'),
          originTuningId: tuning.id,
          dueDate: CalendarDate(2027, 9, 17),
          now: now,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );

    await expectLater(
      reminders.insert(
        Reminder.schedule(
          id: ReminderId('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
          pianoId: piano.id,
          originTuningId: TuningId('99999999-9999-4999-8999-999999999999'),
          dueDate: CalendarDate(2027, 9, 17),
          now: now,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('unique scheduled par piano, historiques multiples autorisés', () async {
    final piano = await insertPiano();
    final firstTuning = await insertTuning(pianoId: piano.id);
    final secondTuning = await insertTuning(
      pianoId: piano.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      tuningDate: CalendarDate(2026, 3, 1),
    );

    await reminders.insert(scheduledOf(piano: piano, tuning: firstTuning));
    await expectLater(
      reminders.insert(
        scheduledOf(
          piano: piano,
          tuning: secondTuning,
          id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        ),
      ),
      throwsA(isA<SqliteException>()),
    );

    final first = await reminders.findScheduledByPianoId(piano.id);
    await reminders.update(first!.markSent(now));
    await reminders.insert(
      scheduledOf(
        piano: piano,
        tuning: secondTuning,
        id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      ),
    );
    expect(await reminders.findScheduledByPianoId(piano.id), isNotNull);

    final current = await reminders.findScheduledByPianoId(piano.id);
    await reminders.update(
      current!.cancel(
        reason: ReminderCancellationReason.remindersDisabled,
        now: now,
      ),
    );
    final thirdTuning = await insertTuning(
      pianoId: piano.id,
      id: '12121212-1212-4121-8121-121212121212',
      tuningDate: CalendarDate(2026, 6, 1),
    );
    await reminders.insert(
      scheduledOf(
        piano: piano,
        tuning: thirdTuning,
        id: '34343434-3434-4343-8343-343434343434',
      ),
    );
    expect(await reminders.findByOriginTuningId(firstTuning.id), isNotNull);
    expect(await reminders.findByOriginTuningId(secondTuning.id), isNotNull);
  });

  test('deux pianos peuvent chacun avoir un scheduled', () async {
    final firstPiano = await insertPiano();
    final firstTuning = await insertTuning(pianoId: firstPiano.id);
    await reminders.insert(
      scheduledOf(piano: firstPiano, tuning: firstTuning),
    );

    final secondCustomer = Customer.create(
      id: CustomerId('22222222-2222-4222-8222-222222222222'),
      lastName: 'Martin',
      now: now,
    );
    await customers.insert(secondCustomer);
    final secondPiano = Piano.create(
      id: PianoId('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
      customerId: secondCustomer.id,
      brand: 'Kawai',
      now: now,
    );
    await pianos.insert(secondPiano);
    final secondTuning = await insertTuning(
      pianoId: secondPiano.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    );
    await reminders.insert(
      scheduledOf(
        piano: secondPiano,
        tuning: secondTuning,
        id: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      ),
    );

    expect(await reminders.findScheduledByPianoId(firstPiano.id), isNotNull);
    expect(await reminders.findScheduledByPianoId(secondPiano.id), isNotNull);
  });

  test('FK RESTRICT empêche de supprimer un piano ou un tuning lié', () async {
    final piano = await insertPiano();
    final tuning = await insertTuning(pianoId: piano.id);
    await reminders.insert(scheduledOf(piano: piano, tuning: tuning));

    await expectLater(
      database.customStatement(
        "DELETE FROM tunings WHERE id = '${tuning.id.value}'",
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      database.customStatement(
        "DELETE FROM pianos WHERE id = '${piano.id.value}'",
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
