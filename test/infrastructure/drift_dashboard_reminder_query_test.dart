import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_dashboard_reminder_query.dart';
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
  late DriftDashboardReminderQuery query;
  final now = DateTime.utc(2026, 9, 17, 10);
  final today = CalendarDate(2026, 9, 17);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
    reminders = DriftReminderRepository(database);
    query = DriftDashboardReminderQuery(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Customer> insertCustomer({
    String id = '11111111-1111-4111-8111-111111111111',
    String lastName = 'Dupont',
    bool archived = false,
    String? phone,
    String? email,
  }) async {
    var customer = Customer.create(
      id: CustomerId(id),
      lastName: lastName,
      firstName: 'Jean',
      city: 'Toulouse',
      phone: phone,
      email: email,
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
    bool archived = false,
    bool remindersEnabled = true,
    String? brand = 'Yamaha',
    String? model = 'U1',
  }) async {
    var piano = Piano.create(
      id: PianoId(pianoId),
      customerId: customerId,
      brand: brand,
      model: model,
      remindersEnabled: remindersEnabled,
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

  Future<Reminder> insertScheduled({
    required Piano piano,
    required Tuning tuning,
    required CalendarDate dueDate,
    String id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  }) async {
    final reminder = Reminder.schedule(
      id: ReminderId(id),
      pianoId: piano.id,
      originTuningId: tuning.id,
      dueDate: dueDate,
      now: now,
    );
    await reminders.insert(reminder);
    return reminder;
  }

  test('JOIN unique, scheduled, fenêtre, ordre dueDate ASC', () async {
    final customer = await insertCustomer();
    final piano = await insertPiano(customerId: customer.id);
    final tuning = await insertTuning(pianoId: piano.id);
    await insertScheduled(
      piano: piano,
      tuning: tuning,
      dueDate: today.addDays(10),
      id: 'later',
    );
    final secondTuning = await insertTuning(
      pianoId: piano.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    );
    await reminders.update(
      (await reminders.findScheduledByPianoId(piano.id))!.cancel(
        reason: ReminderCancellationReason.supersededByTuning,
        now: now,
      ),
    );
    await insertScheduled(
      piano: piano,
      tuning: secondTuning,
      dueDate: today.addDays(2),
      id: 'sooner',
    );

    final found = await query.findScheduledDueOnOrBefore(
      until: today.addDays(30),
    );
    expect(found.map((item) => item.reminderId.value), ['sooner']);
    expect(found.single.customerId, customer.id);
    expect(found.single.lastName, 'Dupont');
    expect(found.single.firstName, 'Jean');
    expect(found.single.city, 'Toulouse');
    expect(found.single.phone, isNull);
    expect(found.single.email, isNull);
    expect(found.single.brand, 'Yamaha');
    expect(found.single.model, 'U1');
    expect(found.single.dueDate, today.addDays(2));
  });

  test('exclut hors fenêtre, sent, archivés et remindersEnabled false', () async {
    final activeCustomer = await insertCustomer();
    final activePiano = await insertPiano(customerId: activeCustomer.id);
    final activeTuning = await insertTuning(pianoId: activePiano.id);
    await insertScheduled(
      piano: activePiano,
      tuning: activeTuning,
      dueDate: today.addDays(31),
      id: 'too-late',
    );

    final sentCustomer = await insertCustomer(
      id: '22222222-2222-4222-8222-222222222222',
    );
    final sentPiano = await insertPiano(
      customerId: sentCustomer.id,
      pianoId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    final sentTuning = await insertTuning(
      pianoId: sentPiano.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    );
    final sent = await insertScheduled(
      piano: sentPiano,
      tuning: sentTuning,
      dueDate: today.addDays(3),
      id: 'sent',
    );
    await reminders.update(sent.markSent(now));

    final archivedCustomer = await insertCustomer(
      id: '33333333-3333-4333-8333-333333333333',
      archived: true,
    );
    final pianoOfArchived = await insertPiano(
      customerId: archivedCustomer.id,
      pianoId: '44444444-4444-4444-8444-444444444444',
    );
    final tuningArchivedCustomer = await insertTuning(
      pianoId: pianoOfArchived.id,
      id: '55555555-5555-4555-8555-555555555555',
    );
    await insertScheduled(
      piano: pianoOfArchived,
      tuning: tuningArchivedCustomer,
      dueDate: today.addDays(4),
      id: 'cust-archived',
    );

    final otherCustomer = await insertCustomer(
      id: '66666666-6666-4666-8666-666666666666',
    );
    final archivedPiano = await insertPiano(
      customerId: otherCustomer.id,
      pianoId: '77777777-7777-4777-8777-777777777777',
      archived: true,
    );
    final tuningArchivedPiano = await insertTuning(
      pianoId: archivedPiano.id,
      id: '88888888-8888-4888-8888-888888888888',
    );
    await insertScheduled(
      piano: archivedPiano,
      tuning: tuningArchivedPiano,
      dueDate: today.addDays(5),
      id: 'piano-archived',
    );

    final disabledPiano = await insertPiano(
      customerId: otherCustomer.id,
      pianoId: '99999999-9999-4999-8999-999999999999',
      remindersEnabled: false,
    );
    final tuningDisabled = await insertTuning(
      pianoId: disabledPiano.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab',
    );
    await insertScheduled(
      piano: disabledPiano,
      tuning: tuningDisabled,
      dueDate: today.addDays(6),
      id: 'disabled',
    );

    final visible = await insertPiano(
      customerId: otherCustomer.id,
      pianoId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbc',
      brand: 'Kawai',
      model: null,
    );
    final visibleTuning = await insertTuning(
      pianoId: visible.id,
      id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccd',
    );
    await insertScheduled(
      piano: visible,
      tuning: visibleTuning,
      dueDate: today.addDays(1),
      id: 'visible',
    );

    final found = await query.findScheduledDueOnOrBefore(
      until: today.addDays(30),
    );
    expect(found.map((item) => item.reminderId.value), ['visible']);
    expect(found.single.brand, 'Kawai');
    expect(found.single.model, isNull);
  });

  test('plusieurs pianos : dueDate ASC, pas d’ordre secondaire contractuel', () async {
    final customer = await insertCustomer();
    final firstPiano = await insertPiano(customerId: customer.id);
    final secondPiano = await insertPiano(
      customerId: customer.id,
      pianoId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      brand: 'Kawai',
    );
    final firstTuning = await insertTuning(pianoId: firstPiano.id);
    final secondTuning = await insertTuning(
      pianoId: secondPiano.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    );
    await insertScheduled(
      piano: secondPiano,
      tuning: secondTuning,
      dueDate: today.addDays(9),
      id: 'second',
    );
    await insertScheduled(
      piano: firstPiano,
      tuning: firstTuning,
      dueDate: today.addDays(3),
      id: 'first',
    );

    final found = await query.findScheduledDueOnOrBefore(
      until: today.addDays(30),
    );
    expect(found.map((item) => item.reminderId.value), ['first', 'second']);
  });

  test('projette téléphone et email depuis la JOIN unique', () async {
    Future<void> insertContactCase({
      required String customerId,
      required String pianoId,
      required String tuningId,
      required String reminderId,
      required String lastName,
      required CalendarDate dueDate,
      String? phone,
      String? email,
    }) async {
      final customer = await insertCustomer(
        id: customerId,
        lastName: lastName,
        phone: phone,
        email: email,
      );
      final piano = await insertPiano(
        customerId: customer.id,
        pianoId: pianoId,
      );
      final tuning = await insertTuning(pianoId: piano.id, id: tuningId);
      await insertScheduled(
        piano: piano,
        tuning: tuning,
        dueDate: dueDate,
        id: reminderId,
      );
    }

    await insertContactCase(
      customerId: '11111111-1111-4111-8111-111111111111',
      pianoId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      tuningId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      reminderId: 'both',
      lastName: 'Both',
      dueDate: today.addDays(1),
      phone: '0612345678',
      email: 'both@example.com',
    );
    await insertContactCase(
      customerId: '22222222-2222-4222-8222-222222222222',
      pianoId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      tuningId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      reminderId: 'phone',
      lastName: 'PhoneOnly',
      dueDate: today.addDays(2),
      phone: '0600000000',
    );
    await insertContactCase(
      customerId: '33333333-3333-4333-8333-333333333333',
      pianoId: '44444444-4444-4444-8444-444444444444',
      tuningId: '55555555-5555-4555-8555-555555555555',
      reminderId: 'email',
      lastName: 'EmailOnly',
      dueDate: today.addDays(3),
      email: 'email@example.com',
    );
    await insertContactCase(
      customerId: '66666666-6666-4666-8666-666666666666',
      pianoId: '77777777-7777-4777-8777-777777777777',
      tuningId: '88888888-8888-4888-8888-888888888888',
      reminderId: 'none',
      lastName: 'Neither',
      dueDate: today.addDays(4),
    );

    final found = await query.findScheduledDueOnOrBefore(
      until: today.addDays(30),
    );
    expect(found, hasLength(4));
    expect(
      found.map(
        (item) => (
          item.reminderId.value,
          item.lastName,
          item.phone,
          item.email,
        ),
      ),
      [
        ('both', 'Both', '0612345678', 'both@example.com'),
        ('phone', 'PhoneOnly', '0600000000', null),
        ('email', 'EmailOnly', null, 'email@example.com'),
        ('none', 'Neither', null, null),
      ],
    );
  });
}
