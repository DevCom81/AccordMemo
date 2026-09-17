import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_activity_repository.dart';
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
  late DriftActivityRepository activities;
  final now = DateTime.utc(2026, 9, 17, 10);
  final today = CalendarDate(2026, 9, 17);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
    reminders = DriftReminderRepository(database);
    activities = DriftActivityRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Customer> insertCustomer({
    String id = '11111111-1111-4111-8111-111111111111',
  }) async {
    final customer = Customer.create(
      id: CustomerId(id),
      lastName: 'Dupont',
      now: now,
    );
    await customers.insert(customer);
    return customer;
  }

  Future<Piano> insertPiano({
    required CustomerId customerId,
    String pianoId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  }) async {
    final piano = Piano.create(
      id: PianoId(pianoId),
      customerId: customerId,
      brand: 'Yamaha',
      now: now,
    );
    await pianos.insert(piano);
    return piano;
  }

  Future<Tuning> insertTuning({
    required PianoId pianoId,
    String id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  }) async {
    final tuning = Tuning.create(
      id: TuningId(id),
      pianoId: pianoId,
      tuningDate: today,
      today: today,
      now: now,
    );
    await tunings.insert(tuning);
    return tuning;
  }

  Future<Reminder> insertReminder({
    required Piano piano,
    required Tuning tuning,
    String id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  }) async {
    final reminder = Reminder.schedule(
      id: ReminderId(id),
      pianoId: piano.id,
      originTuningId: tuning.id,
      dueDate: CalendarDate(2027, 9, 17),
      now: now,
    );
    await reminders.insert(reminder);
    return reminder;
  }

  test('insert, lectures, limit et tri occurredAt DESC', () async {
    final firstCustomer = await insertCustomer();
    final secondCustomer = await insertCustomer(
      id: '22222222-2222-4222-8222-222222222222',
    );
    final firstPiano = await insertPiano(customerId: firstCustomer.id);
    final secondPiano = await insertPiano(
      customerId: secondCustomer.id,
      pianoId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    final firstTuning = await insertTuning(pianoId: firstPiano.id);
    final secondTuning = await insertTuning(
      pianoId: secondPiano.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    );
    final reminder = await insertReminder(
      piano: firstPiano,
      tuning: firstTuning,
    );

    final oldest = Activity.tuningCreated(
      id: ActivityId('activity-1'),
      pianoId: firstPiano.id,
      tuningId: firstTuning.id,
      now: DateTime.utc(2026, 9, 17, 8),
    );
    final middle = Activity.reminderRescheduled(
      id: ActivityId('activity-2'),
      pianoId: firstPiano.id,
      reminderId: reminder.id,
      previousDate: CalendarDate(2027, 9, 17),
      newDate: CalendarDate(2027, 10, 1),
      now: DateTime.utc(2026, 9, 17, 10),
    );
    final newestOtherCustomer = Activity.tuningCreated(
      id: ActivityId('activity-3'),
      pianoId: secondPiano.id,
      tuningId: secondTuning.id,
      now: DateTime.utc(2026, 9, 17, 12),
    );
    await activities.insert(oldest);
    await activities.insert(middle);
    await activities.insert(newestOtherCustomer);

    final storedDates = await database
        .customSelect(
          "SELECT previous_date, new_date FROM activities WHERE id = 'activity-2'",
        )
        .getSingle();
    expect(storedDates.read<String>('previous_date'), '2027-09-17');
    expect(storedDates.read<String>('new_date'), '2027-10-01');

    final recent = await activities.findRecent(limit: 10);
    expect(recent.map((item) => item.id.value), [
      'activity-3',
      'activity-2',
      'activity-1',
    ]);

    final limited = await activities.findRecent(limit: 2);
    expect(limited.map((item) => item.id.value), ['activity-3', 'activity-2']);

    final byPiano = await activities.findByPianoId(
      pianoId: firstPiano.id,
      limit: 10,
    );
    expect(byPiano.map((item) => item.id.value), ['activity-2', 'activity-1']);
    expect(byPiano.first.type, ActivityType.reminderRescheduled);

    final byCustomer = await activities.findByCustomerId(
      customerId: firstCustomer.id,
      limit: 10,
    );
    expect(byCustomer.map((item) => item.id.value), [
      'activity-2',
      'activity-1',
    ]);

    final limitedByCustomer = await activities.findByCustomerId(
      customerId: firstCustomer.id,
      limit: 1,
    );
    expect(limitedByCustomer.single.id.value, 'activity-2');
  });

  test('refuse un limit <= 0', () async {
    await expectLater(
      activities.findRecent(limit: 0),
      throwsA(isA<ActivityLimitInvalid>()),
    );
    await expectLater(
      activities.findByPianoId(
        pianoId: PianoId('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
        limit: -1,
      ),
      throwsA(isA<ActivityLimitInvalid>()),
    );
    await expectLater(
      activities.findByCustomerId(
        customerId: CustomerId('11111111-1111-4111-8111-111111111111'),
        limit: 0,
      ),
      throwsA(isA<ActivityLimitInvalid>()),
    );
  });

  test('FK empêche une Activity orpheline de piano, tuning ou reminder', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(pianoId: piano.id);

    await expectLater(
      activities.insert(
        Activity.tuningCreated(
          id: ActivityId('activity-1'),
          pianoId: PianoId('99999999-9999-4999-8999-999999999999'),
          tuningId: tuning.id,
          now: now,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );

    await expectLater(
      activities.insert(
        Activity.tuningCreated(
          id: ActivityId('activity-2'),
          pianoId: piano.id,
          tuningId: TuningId('99999999-9999-4999-8999-999999999999'),
          now: now,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );

    await expectLater(
      activities.insert(
        Activity.reminderSent(
          id: ActivityId('activity-3'),
          pianoId: piano.id,
          reminderId: ReminderId('99999999-9999-4999-8999-999999999999'),
          now: now,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
