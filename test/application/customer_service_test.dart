import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/domain/customer/civility.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/in_memory_customer_repository.dart';

void main() {
  late InMemoryCustomerRepository repository;
  late CustomerService service;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    repository = InMemoryCustomerRepository();
    service = CustomerService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator(['11111111-1111-4111-8111-111111111111']),
      repository: repository,
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
      repository: repository,
    ).create(lastName: 'Martin', city: 'Albi');
    await service.archive(other.id);

    final results = await service.search(
      filter: CustomerStatusFilter.active,
      query: 'toulouse',
    );

    expect(results, hasLength(1));
    expect(results.single.lastName, 'Dupont');
  });
}
