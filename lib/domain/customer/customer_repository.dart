import 'customer.dart';

enum CustomerStatusFilter { active, archived }

abstract interface class CustomerRepository {
  Future<Customer?> findById(CustomerId id);

  Future<void> insert(Customer customer);

  Future<void> update(Customer customer);

  Future<List<Customer>> search({
    required CustomerStatusFilter filter,
    String query,
  });
}
