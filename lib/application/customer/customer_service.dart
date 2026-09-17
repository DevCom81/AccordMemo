import '../../domain/clock.dart';
import '../../domain/customer/civility.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../ports/id_generator.dart';

final class CustomerService {
  CustomerService({
    required this._clock,
    required this._idGenerator,
    required this._repository,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final CustomerRepository _repository;

  Future<Customer> create({
    Civility? civility,
    required String lastName,
    String? firstName,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
  }) async {
    final now = _clock.now();
    final customer = Customer.create(
      id: CustomerId(_idGenerator.next()),
      civility: civility,
      lastName: lastName,
      firstName: firstName,
      address: address,
      postalCode: postalCode,
      city: city,
      email: email,
      phone: phone,
      now: now,
    );
    await _repository.insert(customer);
    return customer;
  }

  Future<Customer?> getById(CustomerId id) {
    return _repository.findById(id);
  }

  Future<Customer> update({
    required CustomerId id,
    Civility? civility,
    required String lastName,
    String? firstName,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
  }) async {
    final existing = await _requireCustomer(id);
    final updated = existing.changeDetails(
      civility: civility,
      lastName: lastName,
      firstName: firstName,
      address: address,
      postalCode: postalCode,
      city: city,
      email: email,
      phone: phone,
      now: _clock.now(),
    );
    await _repository.update(updated);
    return updated;
  }

  Future<Customer> archive(CustomerId id) async {
    final existing = await _requireCustomer(id);
    final archived = existing.archive(_clock.now());
    await _repository.update(archived);
    return archived;
  }

  Future<Customer> restore(CustomerId id) async {
    final existing = await _requireCustomer(id);
    final restored = existing.restore(_clock.now());
    await _repository.update(restored);
    return restored;
  }

  Future<List<Customer>> search({
    required CustomerStatusFilter filter,
    String query = '',
  }) {
    return _repository.search(filter: filter, query: query);
  }

  Future<Customer> _requireCustomer(CustomerId id) async {
    final customer = await _repository.findById(id);
    if (customer == null) {
      throw CustomerNotFound(id);
    }
    return customer;
  }
}
