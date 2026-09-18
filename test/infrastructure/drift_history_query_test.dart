import 'package:accord_memo/application/history/history_kind.dart';
import 'package:accord_memo/application/history/history_query.dart';
import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_activity_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_history_query.dart';
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
  late DriftHistoryQuery query;
  final now = DateTime.utc(2026, 9, 17, 10);
  final today = CalendarDate(2026, 9, 17);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
    reminders = DriftReminderRepository(database);
    activities = DriftActivityRepository(database);
    query = DriftHistoryQuery(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Customer> insertCustomer({
    String id = '11111111-1111-4111-8111-111111111111',
    String lastName = 'Dupont',
    String? firstName = 'Jean',
    bool archived = false,
  }) async {
    var customer = Customer.create(
      id: CustomerId(id),
      lastName: lastName,
      firstName: firstName,
      now: now,
    );
    if (archived) {
      customer = customer.archive(now);
    }
    await customers.insert(customer);
    return customer;
  }

  Future<Piano> insertPiano({
    required CustomerId customerId,
    String pianoId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    String? brand = 'Yamaha',
    String? model = 'U1',
    bool archived = false,
  }) async {
    var piano = Piano.create(
      id: PianoId(pianoId),
      customerId: customerId,
      brand: brand,
      model: model,
      now: now,
    );
    if (archived) {
      piano = piano.archive(now);
    }
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

  Future<Reminder> insertReminder({
    required Piano piano,
    required Tuning tuning,
    String id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    CalendarDate? dueDate,
  }) async {
    final reminder = Reminder.schedule(
      id: ReminderId(id),
      pianoId: piano.id,
      originTuningId: tuning.id,
      dueDate: dueDate ?? CalendarDate(2027, 9, 17),
      now: now,
    );
    await reminders.insert(reminder);
    return reminder;
  }

  test('ordre occurredAt DESC puis id DESC, limit demandée', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(pianoId: piano.id);
    await activities.insert(
      Activity.tuningCreated(
        id: ActivityId('activity-a'),
        pianoId: piano.id,
        tuningId: tuning.id,
        now: DateTime.utc(2026, 9, 17, 8),
      ),
    );
    await activities.insert(
      Activity.reminderDisabled(
        id: ActivityId('activity-c'),
        pianoId: piano.id,
        now: DateTime.utc(2026, 9, 17, 10),
      ),
    );
    await activities.insert(
      Activity.reminderReenabled(
        id: ActivityId('activity-b'),
        pianoId: piano.id,
        now: DateTime.utc(2026, 9, 17, 10),
      ),
    );

    final recent = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.all,
    );
    expect(recent.map((item) => item.activityId.value), [
      'activity-c',
      'activity-b',
      'activity-a',
    ]);

    final limited = await query.findRecent(
      limit: 2,
      filter: HistoryKindFilter.all,
    );
    expect(limited.map((item) => item.activityId.value), [
      'activity-c',
      'activity-b',
    ]);
    expect(historyDefaultLimit, 100);
  });

  test('enrichit Customer et Piano, y compris archivés', () async {
    final customer = await insertCustomer(archived: true);
    final piano = await insertPiano(customerId: customer.id, archived: true);
    final tuning = await insertTuning(pianoId: piano.id);
    await activities.insert(
      Activity.tuningCreated(
        id: ActivityId('activity-1'),
        pianoId: piano.id,
        tuningId: tuning.id,
        now: now,
      ),
    );

    final recent = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.all,
    );
    expect(recent, hasLength(1));
    expect(recent.single.customerLastName, 'Dupont');
    expect(recent.single.customerFirstName, 'Jean');
    expect(recent.single.customerArchived, isTrue);
    expect(recent.single.pianoBrand, 'Yamaha');
    expect(recent.single.pianoModel, 'U1');
    expect(recent.single.pianoArchived, isTrue);
    expect(recent.single.kind, HistoryKind.tuningCreated);
  });

  test('tuningCreated expose tuningDate ISO sans dérive timezone', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 9, 17),
    );
    await activities.insert(
      Activity.tuningCreated(
        id: ActivityId('activity-1'),
        pianoId: piano.id,
        tuningId: tuning.id,
        now: now,
      ),
    );

    final stored = await database
        .customSelect('SELECT tuning_date FROM tunings')
        .getSingle();
    expect(stored.read<String>('tuning_date'), '2026-09-17');

    final recent = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.all,
    );
    expect(recent.single.tuningDate, CalendarDate(2026, 9, 17));
    expect(recent.single.tuningDate!.toIso8601String(), '2026-09-17');
  });

  test('reminderSent expose dueDate, LEFT JOIN nullable sinon', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(pianoId: piano.id);
    final reminder = await insertReminder(
      piano: piano,
      tuning: tuning,
      dueDate: CalendarDate(2027, 3, 1),
    );
    await activities.insert(
      Activity.reminderSent(
        id: ActivityId('activity-sent'),
        pianoId: piano.id,
        reminderId: reminder.id,
        now: now,
      ),
    );
    await activities.insert(
      Activity.reminderDisabled(
        id: ActivityId('activity-disabled'),
        pianoId: piano.id,
        now: DateTime.utc(2026, 9, 17, 11),
      ),
    );

    final stored = await database
        .customSelect('SELECT due_date FROM reminders')
        .getSingle();
    expect(stored.read<String>('due_date'), '2027-03-01');

    final recent = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.all,
    );
    expect(recent.first.kind, HistoryKind.reminderDisabled);
    expect(recent.first.tuningDate, isNull);
    expect(recent.first.reminderDueDate, isNull);
    expect(recent.last.kind, HistoryKind.reminderSent);
    expect(recent.last.reminderDueDate, CalendarDate(2027, 3, 1));
  });

  test('filtre Tous, Accords et Rappels dans la query', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(pianoId: piano.id);
    final reminder = await insertReminder(piano: piano, tuning: tuning);
    await activities.insert(
      Activity.tuningCreated(
        id: ActivityId('activity-created'),
        pianoId: piano.id,
        tuningId: tuning.id,
        now: DateTime.utc(2026, 9, 17, 8),
      ),
    );
    await activities.insert(
      Activity.tuningUpdated(
        id: ActivityId('activity-updated'),
        pianoId: piano.id,
        tuningId: tuning.id,
        previousDate: CalendarDate(2026, 1, 1),
        newDate: CalendarDate(2026, 2, 1),
        now: DateTime.utc(2026, 9, 17, 9),
      ),
    );
    await activities.insert(
      Activity.reminderRescheduled(
        id: ActivityId('activity-rescheduled'),
        pianoId: piano.id,
        reminderId: reminder.id,
        previousDate: CalendarDate(2027, 9, 17),
        newDate: CalendarDate(2027, 10, 1),
        now: DateTime.utc(2026, 9, 17, 10),
      ),
    );

    final all = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.all,
    );
    expect(all.map((item) => item.kind), [
      HistoryKind.reminderRescheduled,
      HistoryKind.tuningUpdated,
      HistoryKind.tuningCreated,
    ]);

    final tuningsOnly = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.tunings,
    );
    expect(tuningsOnly.map((item) => item.kind), [
      HistoryKind.tuningUpdated,
      HistoryKind.tuningCreated,
    ]);
    expect(
      tuningsOnly
          .singleWhere((item) => item.kind == HistoryKind.tuningUpdated)
          .previousDate,
      CalendarDate(2026, 1, 1),
    );
    expect(
      tuningsOnly
          .singleWhere((item) => item.kind == HistoryKind.tuningUpdated)
          .newDate,
      CalendarDate(2026, 2, 1),
    );

    final remindersOnly = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.reminders,
    );
    expect(remindersOnly.map((item) => item.kind), [
      HistoryKind.reminderRescheduled,
    ]);
  });

  test('refuse un limit <= 0', () async {
    await expectLater(
      query.findRecent(limit: 0, filter: HistoryKindFilter.all),
      throwsA(isA<ActivityLimitInvalid>()),
    );
  });

  test('une seule lecture JOIN retourne toutes les données d’affichage', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(pianoId: piano.id);
    await activities.insert(
      Activity.tuningCreated(
        id: ActivityId('activity-join'),
        pianoId: piano.id,
        tuningId: tuning.id,
        now: now,
      ),
    );

    final recent = await query.findRecent(
      limit: 10,
      filter: HistoryKindFilter.all,
    );
    expect(recent, hasLength(1));
    expect(recent.single.customerLastName, isNotEmpty);
    expect(recent.single.pianoBrand, isNotEmpty);
    expect(recent.single.tuningDate, isNotNull);
    expect(recent.single.kind, HistoryKind.tuningCreated);
  });
}
