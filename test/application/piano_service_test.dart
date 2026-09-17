import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/application/piano/piano_service.dart';
import 'package:accord_memo/application/ports/transaction_runner.dart';
import 'package:accord_memo/application/tuning/record_tuning.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/domain/piano/piano_type.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_customer_repository.dart';
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
  late InMemoryCustomerRepository customers;
  late InMemoryPianoRepository pianos;
  late InMemoryTuningRepository tunings;
  late InMemoryReminderRepository reminders;
  late InMemoryActivityRepository activities;
  late _CountingTransactionRunner transactions;
  late CustomerService customerService;
  late PianoService pianoService;
  late RecordTuning recordTuning;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    customers = InMemoryCustomerRepository();
    pianos = InMemoryPianoRepository();
    tunings = InMemoryTuningRepository();
    reminders = InMemoryReminderRepository();
    activities = InMemoryActivityRepository(pianos);
    transactions = _CountingTransactionRunner();
    customerService = CustomerService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        '11111111-1111-4111-8111-111111111111',
        ...spareIds(),
      ]),
      transactions: transactions,
      repository: customers,
      pianos: pianos,
      reminders: reminders,
      activities: activities,
    );
    pianoService = PianoService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ...spareIds(),
      ]),
      transactions: transactions,
      pianos: pianos,
      customers: customers,
      reminders: reminders,
      activities: activities,
    );
    recordTuning = RecordTuning(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        'ffffffff-ffff-4fff-8fff-ffffffffffff',
        '99999999-9999-4999-8999-999999999999',
        ...spareIds(),
      ]),
      transactions: transactions,
      tunings: tunings,
      pianos: pianos,
      reminders: reminders,
      activities: activities,
    );
  });

  Future<Customer> createCustomer() {
    return customerService.create(lastName: 'Dupont');
  }

  test('crée un piano avec défauts 12 mois et remindersEnabled true', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );

    expect(piano.id.value, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(piano.customerId, customer.id);
    expect(piano.reminderIntervalMonths, 12);
    expect(piano.remindersEnabled, isTrue);
  });

  test('refuse un customer inexistant', () async {
    await expectLater(
      pianoService.create(
        customerId: CustomerId('missing'),
        brand: 'Yamaha',
      ),
      throwsA(isA<CustomerNotFound>()),
    );
  });

  test('refuse un customer archivé', () async {
    final customer = await createCustomer();
    await customerService.archive(customer.id);

    await expectLater(
      pianoService.create(customerId: customer.id, brand: 'Yamaha'),
      throwsA(isA<PianoCustomerArchived>()),
    );
  });

  test('archiver un customer n’archive pas ses pianos', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      type: PianoType.queue,
    );

    await customerService.archive(customer.id);

    final loaded = await pianoService.getById(piano.id);
    expect(loaded, isNotNull);
    expect(loaded!.isArchived, isFalse);
    expect(loaded.remindersEnabled, isFalse);

    final listed = await pianoService.findByCustomer(
      customerId: customer.id,
      filter: PianoStatusFilter.active,
    );
    expect(listed.map((item) => item.id), [piano.id]);
  });

  test('refuse de modifier un piano archivé', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    await pianoService.archive(piano.id);

    await expectLater(
      pianoService.update(
        id: piano.id,
        brand: 'Kawai',
        reminderIntervalMonths: 12,
        remindersEnabled: true,
      ),
      throwsA(isA<PianoArchivedNotModifiable>()),
    );
  });

  test('true → false annule le scheduled, false → true ne crée rien', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    expect(await reminders.findScheduledByPianoId(piano.id), isNotNull);

    final disabled = await pianoService.update(
      id: piano.id,
      brand: 'Yamaha',
      reminderIntervalMonths: 12,
      remindersEnabled: false,
    );
    expect(disabled.remindersEnabled, isFalse);
    final cancelled = await reminders.findByOriginTuningId(
      (await tunings.findByPianoId(piano.id)).single.id,
    );
    expect(cancelled!.status, ReminderStatus.cancelled);
    expect(
      cancelled.cancellationReason,
      ReminderCancellationReason.remindersDisabled,
    );

    await pianoService.update(
      id: piano.id,
      brand: 'Yamaha',
      reminderIntervalMonths: 12,
      remindersEnabled: true,
    );
    expect(await reminders.findScheduledByPianoId(piano.id), isNull);
  });

  test('true → false crée reminderDisabled, false → true crée reminderReenabled', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    final callsBeforeDisable = transactions.calls;

    await pianoService.update(
      id: piano.id,
      brand: 'Yamaha',
      reminderIntervalMonths: 12,
      remindersEnabled: false,
    );
    expect(transactions.calls, callsBeforeDisable + 1);
    final afterDisable = await activities.findByPianoId(
      pianoId: piano.id,
      limit: 10,
    );
    expect(afterDisable, hasLength(1));
    expect(afterDisable.single.type, ActivityType.reminderDisabled);
    expect(afterDisable.single.occurredAt, now);

    await pianoService.update(
      id: piano.id,
      brand: 'Yamaha',
      reminderIntervalMonths: 12,
      remindersEnabled: true,
    );
    final journal = await activities.findByPianoId(pianoId: piano.id, limit: 10);
    expect(journal, hasLength(2));
    expect(journal.map((item) => item.type).toSet(), {
      ActivityType.reminderDisabled,
      ActivityType.reminderReenabled,
    });
  });

  test('aucune Activity si remindersEnabled est inchangé', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    final callsBefore = transactions.calls;

    await pianoService.update(
      id: piano.id,
      brand: 'Yamaha',
      reminderIntervalMonths: 6,
      remindersEnabled: true,
    );

    expect(transactions.calls, callsBefore);
    expect(await activities.findByPianoId(pianoId: piano.id, limit: 10), isEmpty);

    final disabled = await pianoService.create(
      customerId: customer.id,
      brand: 'Kawai',
      remindersEnabled: false,
    );
    await pianoService.update(
      id: disabled.id,
      brand: 'Kawai',
      reminderIntervalMonths: 12,
      remindersEnabled: false,
    );
    expect(
      await activities.findByPianoId(pianoId: disabled.id, limit: 10),
      isEmpty,
    );
  });

  test('changer l’intervalle ne recalcule pas le Reminder existant', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    final before = await reminders.findScheduledByPianoId(piano.id);

    await pianoService.update(
      id: piano.id,
      brand: 'Yamaha',
      reminderIntervalMonths: 6,
      remindersEnabled: true,
    );

    final after = await reminders.findScheduledByPianoId(piano.id);
    expect(after!.dueDate, before!.dueDate);
  });

  test('archive annule le scheduled, restore ne recrée rien', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    final callsBeforeArchive = transactions.calls;

    await pianoService.archive(piano.id);
    expect(transactions.calls, greaterThan(callsBeforeArchive));

    final reminder = await reminders.findByOriginTuningId(
      (await tunings.findByPianoId(piano.id)).single.id,
    );
    expect(reminder!.status, ReminderStatus.cancelled);
    expect(reminder.cancellationReason, ReminderCancellationReason.pianoArchived);

    await pianoService.restore(piano.id);
    expect(await reminders.findScheduledByPianoId(piano.id), isNull);
    final restored = await pianoService.getById(piano.id);
    expect(restored!.isArchived, isFalse);
    expect(restored.remindersEnabled, isTrue);
  });

  test('archive ne crée pas de reminderDisabled si le flag ne change pas', () async {
    final customer = await createCustomer();
    final piano = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    await recordTuning.execute(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );

    await pianoService.archive(piano.id);

    final journal = await activities.findByPianoId(pianoId: piano.id, limit: 10);
    expect(
      journal.where((item) => item.type == ActivityType.reminderDisabled),
      isEmpty,
    );
    expect(journal.single.type, ActivityType.tuningCreated);
  });
}
