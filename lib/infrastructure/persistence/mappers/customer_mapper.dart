import 'package:drift/drift.dart';

import '../../../domain/customer/civility.dart';
import '../../../domain/customer/customer.dart';
import '../app_database.dart';

final class CustomerMapper {
  const CustomerMapper();

  Customer toDomain(CustomerRecord row) {
    return Customer.reconstitute(
      id: CustomerId(row.id),
      civility: row.civility == null ? null : Civility.values.byName(row.civility!),
      lastName: row.lastName,
      firstName: row.firstName,
      address: row.address,
      postalCode: row.postalCode,
      city: row.city,
      email: row.email,
      phone: row.phone,
      archivedAt: row.archivedAt?.toUtc(),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  CustomersCompanion toCompanion(Customer customer) {
    return CustomersCompanion(
      id: Value(customer.id.value),
      civility: Value(customer.civility?.name),
      lastName: Value(customer.lastName),
      firstName: Value(customer.firstName),
      address: Value(customer.address),
      postalCode: Value(customer.postalCode),
      city: Value(customer.city),
      email: Value(customer.email),
      phone: Value(customer.phone),
      archivedAt: Value(customer.archivedAt?.toUtc()),
      createdAt: Value(customer.createdAt.toUtc()),
      updatedAt: Value(customer.updatedAt.toUtc()),
    );
  }
}
