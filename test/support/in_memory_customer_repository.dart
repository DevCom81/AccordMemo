import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';

final class InMemoryCustomerRepository implements CustomerRepository {
  final Map<String, Customer> _customers = {};

  @override
  Future<Customer?> findById(CustomerId id) async {
    return _customers[id.value];
  }

  @override
  Future<void> insert(Customer customer) async {
    _customers[customer.id.value] = customer;
  }

  @override
  Future<void> update(Customer customer) async {
    if (!_customers.containsKey(customer.id.value)) {
      throw CustomerNotFound(customer.id);
    }
    _customers[customer.id.value] = customer;
  }

  @override
  Future<List<Customer>> search({
    required CustomerStatusFilter filter,
    String query = '',
  }) async {
    final trimmedQuery = query.trim().toLowerCase();
    final archived = filter == CustomerStatusFilter.archived;
    final matches = _customers.values.where((customer) {
      if (customer.isArchived != archived) {
        return false;
      }
      if (trimmedQuery.isEmpty) {
        return true;
      }
      return _matches(customer.lastName, trimmedQuery) ||
          _matches(customer.firstName, trimmedQuery) ||
          _matches(customer.city, trimmedQuery) ||
          _matches(customer.email, trimmedQuery);
    }).toList();
    matches.sort((a, b) {
      final lastName = a.lastName.compareTo(b.lastName);
      if (lastName != 0) {
        return lastName;
      }
      return (a.firstName ?? '').compareTo(b.firstName ?? '');
    });
    return matches;
  }

  bool _matches(String? value, String query) {
    return value != null && value.toLowerCase().contains(query);
  }
}
