import 'package:accord_memo/domain/customer/civility.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCustomerRepository repository;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftCustomerRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Customer newCustomer({
    required String id,
    required String lastName,
    String? firstName,
    String? city,
    String? email,
    Civility? civility = Civility.monsieur,
  }) {
    return Customer.create(
      id: CustomerId(id),
      civility: civility,
      lastName: lastName,
      firstName: firstName,
      city: city,
      email: email,
      now: now,
    );
  }

  test('insert, findById et update persistent l’entité telle quelle', () async {
    final created = newCustomer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
      city: 'Toulouse',
      email: 'pas une adresse',
    );
    await repository.insert(created);

    final loaded = await repository.findById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.lastName, 'Dupont');
    expect(loaded.firstName, 'Jean');
    expect(loaded.city, 'Toulouse');
    expect(loaded.email, 'pas une adresse');
    expect(loaded.civility, Civility.monsieur);

    final renamed = created.changeDetails(
      civility: Civility.madame,
      lastName: 'Martin',
      firstName: 'Marie',
      city: 'Albi',
      email: loaded.email,
      now: now.add(const Duration(days: 1)),
    );
    await repository.update(renamed);

    final updated = await repository.findById(created.id);
    expect(updated!.lastName, 'Martin');
    expect(updated.civility, Civility.madame);
    expect(updated.createdAt, now);
  });

  test('search filtre les actifs et est insensible à la casse ASCII', () async {
    await repository.insert(
      newCustomer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        city: 'Toulouse',
      ),
    );
    final martin = newCustomer(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      lastName: 'Martin',
      email: 'marie@example.com',
    );
    await repository.insert(martin);
    await repository.update(martin.archive(now));

    final byCity = await repository.search(
      filter: CustomerStatusFilter.active,
      query: 'TOULOUSE',
    );
    expect(byCity.map((c) => c.lastName), ['Dupont']);

    final archived = await repository.search(
      filter: CustomerStatusFilter.archived,
      query: '',
    );
    expect(archived.map((c) => c.lastName), ['Martin']);

    final byEmail = await repository.search(
      filter: CustomerStatusFilter.archived,
      query: 'MARIE@EXAMPLE.COM',
    );
    expect(byEmail, hasLength(1));
  });

  test('update d’un id inconnu lève CustomerNotFound', () async {
    final missing = newCustomer(
      id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      lastName: 'Inconnu',
    );

    await expectLater(
      repository.update(missing),
      throwsA(isA<CustomerNotFound>()),
    );
  });
}
