import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_piano_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCustomerRepository customers;
  late DriftPianoRepository pianos;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Customer> insertCustomer() async {
    final customer = Customer.create(
      id: CustomerId('11111111-1111-4111-8111-111111111111'),
      lastName: 'Dupont',
      now: now,
    );
    await customers.insert(customer);
    return customer;
  }

  Piano newPiano({
    required CustomerId customerId,
    String id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    String? brand = 'Yamaha',
  }) {
    return Piano.create(
      id: PianoId(id),
      customerId: customerId,
      brand: brand,
      now: now,
    );
  }

  test('insert, findById, update et listing par customer', () async {
    final customer = await insertCustomer();
    final created = newPiano(customerId: customer.id);
    await pianos.insert(created);

    final loaded = await pianos.findById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.brand, 'Yamaha');
    expect(loaded.customerId, customer.id);
    expect(loaded.createdAt, now);
    expect(loaded.remindersEnabled, isTrue);
    expect(loaded.reminderIntervalMonths, 12);

    final renamed = created.changeDetails(
      brand: 'Kawai',
      reminderIntervalMonths: 18,
      remindersEnabled: false,
      now: now.add(const Duration(days: 1)),
    );
    await pianos.update(renamed);

    final updated = await pianos.findById(created.id);
    expect(updated!.brand, 'Kawai');
    expect(updated.reminderIntervalMonths, 18);
    expect(updated.remindersEnabled, isFalse);
    expect(updated.customerId, customer.id);

    final listed = await pianos.findByCustomerId(
      customerId: customer.id,
      filter: PianoStatusFilter.active,
    );
    expect(listed.map((piano) => piano.id), [created.id]);
  });

  test('FK empêche un piano orphelin', () async {
    final orphan = newPiano(
      customerId: CustomerId('99999999-9999-4999-8999-999999999999'),
    );

    await expectLater(pianos.insert(orphan), throwsA(isA<SqliteException>()));
  });

  test('FK RESTRICT empêche de supprimer un customer qui a un piano', () async {
    final customer = await insertCustomer();
    await pianos.insert(newPiano(customerId: customer.id));

    await expectLater(
      database.customStatement(
        "DELETE FROM customers WHERE id = '${customer.id.value}'",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('findByCustomerId distingue actifs et archivés', () async {
    final customer = await insertCustomer();
    final active = newPiano(customerId: customer.id);
    final archived = Piano.create(
      id: PianoId('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
      customerId: customer.id,
      model: 'U1',
      now: now,
    );
    await pianos.insert(active);
    await pianos.insert(archived);
    await pianos.update(archived.archive(now));

    final actives = await pianos.findByCustomerId(
      customerId: customer.id,
      filter: PianoStatusFilter.active,
    );
    expect(actives.map((piano) => piano.id), [active.id]);

    final archivedList = await pianos.findByCustomerId(
      customerId: customer.id,
      filter: PianoStatusFilter.archived,
    );
    expect(archivedList.map((piano) => piano.id), [archived.id]);
  });
}
