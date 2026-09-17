import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/application/piano/piano_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/domain/piano/piano_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/in_memory_customer_repository.dart';
import '../support/in_memory_piano_repository.dart';

void main() {
  late InMemoryCustomerRepository customers;
  late InMemoryPianoRepository pianos;
  late CustomerService customerService;
  late PianoService pianoService;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    customers = InMemoryCustomerRepository();
    pianos = InMemoryPianoRepository();
    customerService = CustomerService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        '11111111-1111-4111-8111-111111111111',
      ]),
      repository: customers,
    );
    pianoService = PianoService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ]),
      pianos: pianos,
      customers: customers,
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
}
