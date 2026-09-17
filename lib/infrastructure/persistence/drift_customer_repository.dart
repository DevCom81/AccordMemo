import 'package:drift/drift.dart';

import '../../../domain/customer/customer.dart';
import '../../../domain/customer/customer_repository.dart';
import 'app_database.dart';
import 'mappers/customer_mapper.dart';

final class DriftCustomerRepository implements CustomerRepository {
  DriftCustomerRepository(
    this._database, {
    this._mapper = const CustomerMapper(),
  });

  final AppDatabase _database;
  final CustomerMapper _mapper;

  @override
  Future<Customer?> findById(CustomerId id) async {
    final row = await (_database.select(
      _database.customers,
    )..where((t) => t.id.equals(id.value))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.toDomain(row);
  }

  @override
  Future<void> insert(Customer customer) {
    return _database.into(_database.customers).insert(_mapper.toCompanion(customer));
  }

  @override
  Future<void> update(Customer customer) async {
    final written = await (_database.update(
      _database.customers,
    )..where((t) => t.id.equals(customer.id.value))).write(
      _mapper.toCompanion(customer),
    );
    if (written == 0) {
      throw CustomerNotFound(customer.id);
    }
  }

  @override
  Future<List<Customer>> search({
    required CustomerStatusFilter filter,
    String query = '',
  }) async {
    final trimmedQuery = query.trim();
    final rows =
        await (_database.select(_database.customers)
              ..where((t) => _searchPredicate(t, filter, trimmedQuery))
              ..orderBy([
                (t) => OrderingTerm.asc(t.lastName),
                (t) => OrderingTerm.asc(t.firstName),
              ]))
            .get();
    return rows.map(_mapper.toDomain).toList();
  }

  Expression<bool> _searchPredicate(
    $CustomersTable table,
    CustomerStatusFilter filter,
    String trimmedQuery,
  ) {
    final archivedClause = filter == CustomerStatusFilter.archived
        ? table.archivedAt.isNotNull()
        : table.archivedAt.isNull();
    if (trimmedQuery.isEmpty) {
      return archivedClause;
    }

    final pattern = '%${trimmedQuery.toLowerCase()}%';
    final textClause =
        table.lastName.lower().like(pattern) |
        table.firstName.lower().like(pattern) |
        table.city.lower().like(pattern) |
        table.email.lower().like(pattern);
    return archivedClause & textClause;
  }
}
