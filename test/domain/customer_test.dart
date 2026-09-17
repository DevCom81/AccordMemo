import 'package:accord_memo/domain/customer/civility.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);

  Customer createDupont({DateTime? at}) {
    return Customer.create(
      id: CustomerId('customer-1'),
      civility: Civility.monsieur,
      lastName: '  Dupont  ',
      firstName: '  Jean  ',
      now: at ?? now,
    );
  }

  test('normalise le nom obligatoire et les champs optionnels', () {
    final customer = Customer.create(
      id: CustomerId('customer-1'),
      lastName: '  Dupont  ',
      firstName: '  ',
      address: '  1 rue des Pianos  ',
      postalCode: '',
      city: '  Toulouse  ',
      email: '  historique@invalide  ',
      phone: '   ',
      now: now,
    );

    expect(customer.lastName, 'Dupont');
    expect(customer.firstName, isNull);
    expect(customer.address, '1 rue des Pianos');
    expect(customer.postalCode, isNull);
    expect(customer.city, 'Toulouse');
    expect(customer.email, 'historique@invalide');
    expect(customer.phone, isNull);
    expect(customer.archivedAt, isNull);
    expect(customer.createdAt, now);
    expect(customer.updatedAt, now);
  });

  test('refuse un nom vide', () {
    expect(
      () => Customer.create(id: CustomerId('customer-1'), lastName: '   ', now: now),
      throwsA(isA<CustomerLastNameRequired>()),
    );
  });

  test('conserve un email imparfait sans validation syntaxique', () {
    final customer = Customer.create(
      id: CustomerId('customer-1'),
      lastName: 'Dupont',
      email: 'pas une adresse',
      now: now,
    );

    expect(customer.email, 'pas une adresse');
  });

  test('changeDetails met à jour updatedAt sans toucher createdAt', () {
    final created = createDupont();
    final later = now.add(const Duration(days: 1));

    final updated = created.changeDetails(
      civility: Civility.madame,
      lastName: 'Martin',
      firstName: 'Marie',
      now: later,
    );

    expect(updated.lastName, 'Martin');
    expect(updated.firstName, 'Marie');
    expect(updated.civility, Civility.madame);
    expect(updated.createdAt, now);
    expect(updated.updatedAt, later);
    expect(updated.isArchived, isFalse);
  });

  test('changeDetails refuse un customer archivé', () {
    final archived = createDupont().archive(now);

    expect(
      () => archived.changeDetails(lastName: 'Martin', now: now),
      throwsA(isA<CustomerArchivedNotModifiable>()),
    );
  });

  test('archive et restore sont les seules transitions de archivedAt', () {
    final created = createDupont();
    final archivedAt = now.add(const Duration(hours: 1));
    final restoredAt = now.add(const Duration(hours: 2));

    final archived = created.archive(archivedAt);
    expect(archived.archivedAt, archivedAt);
    expect(archived.updatedAt, archivedAt);
    expect(archived.createdAt, now);

    expect(
      () => archived.archive(restoredAt),
      throwsA(isA<CustomerAlreadyArchived>()),
    );
    expect(
      () => created.restore(restoredAt),
      throwsA(isA<CustomerNotArchived>()),
    );

    final restored = archived.restore(restoredAt);
    expect(restored.archivedAt, isNull);
    expect(restored.updatedAt, restoredAt);
    expect(restored.createdAt, now);
  });
}
