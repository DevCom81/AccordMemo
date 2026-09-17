import '../../domain/clock.dart';
import '../../domain/customer/civility.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/reminder/reminder_cancellation_reason.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../ports/id_generator.dart';
import '../ports/transaction_runner.dart';

final class CustomerService {
  CustomerService({
    required this._clock,
    required this._idGenerator,
    required this._transactions,
    required this._repository,
    required this._pianos,
    required this._reminders,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactions;
  final CustomerRepository _repository;
  final PianoRepository _pianos;
  final ReminderRepository _reminders;

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
    final now = _clock.now();
    return _transactions.run(() async {
      final existing = await _requireCustomer(id);
      final archived = existing.archive(now);
      await _repository.update(archived);

      final pianos = [
        ...await _pianos.findByCustomerId(
          customerId: id,
          filter: PianoStatusFilter.active,
        ),
        ...await _pianos.findByCustomerId(
          customerId: id,
          filter: PianoStatusFilter.archived,
        ),
      ];
      for (final piano in pianos) {
        if (piano.remindersEnabled) {
          await _pianos.update(piano.disableReminders(now));
        }
        final scheduled = await _reminders.findScheduledByPianoId(piano.id);
        if (scheduled != null) {
          await _reminders.update(
            scheduled.cancel(
              reason: ReminderCancellationReason.customerArchived,
              now: now,
            ),
          );
        }
      }
      return archived;
    });
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
