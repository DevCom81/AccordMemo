import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/application/piano/piano_service.dart';
import 'package:accord_memo/application/ports/transaction_runner.dart';
import 'package:accord_memo/application/tuning/record_tuning.dart';
import 'package:accord_memo/domain/customer/civility.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
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
  late InMemoryCustomerRepository repository;
  late InMemoryPianoRepository pianos;
  late InMemoryTuningRepository tunings;
  late InMemoryReminderRepository reminders;
  late _CountingTransactionRunner transactions;
  late CustomerService service;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    repository = InMemoryCustomerRepository();
    pianos = InMemoryPianoRepository();
    tunings = InMemoryTuningRepository();
    reminders = InMemoryReminderRepository();
    transactions = _CountingTransactionRunner();
    service = CustomerService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator(['11111111-1111-4111-8111-111111111111']),
      transactions: transactions,
      repository: repository,
      pianos: pianos,
      reminders: reminders,
    );
  });

  test('crée un customer avec id et dates issus des ports', () async {
    final customer = await service.create(
      civility: Civility.madame,
      lastName: ' Dupont ',
      email: '  imparfait  ',
    );

    expect(customer.id.value, '11111111-1111-4111-8111-111111111111');
    expect(customer.lastName, 'Dupont');
    expect(customer.email, 'imparfait');
    expect(customer.createdAt, now);
    expect(customer.updatedAt, now);
    expect(customer.isArchived, isFalse);
  });

  test('refuse de modifier un customer archivé', () async {
    final created = await service.create(lastName: 'Dupont');
    await service.archive(created.id);

    await expectLater(
      service.update(id: created.id, lastName: 'Martin'),
      throwsA(isA<CustomerArchivedNotModifiable>()),
    );
  });

  test('archive et restore échouent dans le mauvais état', () async {
    final created = await service.create(lastName: 'Dupont');

    await expectLater(
      service.restore(created.id),
      throwsA(isA<CustomerNotArchived>()),
    );

    await service.archive(created.id);
    await expectLater(
      service.archive(created.id),
      throwsA(isA<CustomerAlreadyArchived>()),
    );
  });

  test('signale un customer introuvable', () async {
    await expectLater(
      service.archive(CustomerId('missing')),
      throwsA(isA<CustomerNotFound>()),
    );
  });

  test('recherche les customers actifs', () async {
    await service.create(lastName: 'Dupont', city: 'Toulouse');
    final other = await CustomerService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator(['22222222-2222-4222-8222-222222222222']),
      transactions: transactions,
      repository: repository,
      pianos: pianos,
      reminders: reminders,
    ).create(lastName: 'Martin', city: 'Albi');
    await service.archive(other.id);

    final results = await service.search(
      filter: CustomerStatusFilter.active,
      query: 'toulouse',
    );

    expect(results, hasLength(1));
    expect(results.single.lastName, 'Dupont');
  });

  test('archive désactive les relances de tous les pianos sans les archiver', () async {
    final pianoService = PianoService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ]),
      transactions: transactions,
      pianos: pianos,
      customers: repository,
      reminders: reminders,
    );
    final recordTuning = RecordTuning(
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

    final customer = await service.create(lastName: 'Dupont');
    final first = await pianoService.create(
      customerId: customer.id,
      brand: 'Yamaha',
    );
    final second = await pianoService.create(
      customerId: customer.id,
      brand: 'Kawai',
    );
    await recordTuning.execute(
      pianoId: first.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );
    await recordTuning.execute(
      pianoId: second.id,
      tuningDate: CalendarDate(2026, 2, 5),
    );

    final callsBefore = transactions.calls;
    await service.archive(customer.id);
    expect(transactions.calls, greaterThan(callsBefore));

    final archived = await service.getById(customer.id);
    expect(archived!.isArchived, isTrue);

    for (final pianoId in [first.id, second.id]) {
      final piano = await pianoService.getById(pianoId);
      expect(piano!.isArchived, isFalse);
      expect(piano.remindersEnabled, isFalse);
      expect(await reminders.findScheduledByPianoId(pianoId), isNull);
    }

    final firstReminder = await reminders.findByOriginTuningId(
      (await tunings.findByPianoId(first.id)).single.id,
    );
    expect(firstReminder!.status, ReminderStatus.cancelled);
    expect(
      firstReminder.cancellationReason,
      ReminderCancellationReason.customerArchived,
    );

    await service.restore(customer.id);
    final restoredCustomer = await service.getById(customer.id);
    expect(restoredCustomer!.isArchived, isFalse);
    for (final pianoId in [first.id, second.id]) {
      final piano = await pianoService.getById(pianoId);
      expect(piano!.remindersEnabled, isFalse);
      expect(await reminders.findScheduledByPianoId(pianoId), isNull);
    }

    final actives = await pianoService.findByCustomer(
      customerId: customer.id,
      filter: PianoStatusFilter.active,
    );
    expect(actives, hasLength(2));
  });
}
