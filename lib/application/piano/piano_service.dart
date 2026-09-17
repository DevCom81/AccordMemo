import '../../domain/clock.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/piano/piano_type.dart';
import '../ports/id_generator.dart';

final class PianoService {
  PianoService({
    required this._clock,
    required this._idGenerator,
    required this._pianos,
    required this._customers,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final PianoRepository _pianos;
  final CustomerRepository _customers;

  Future<Piano> create({
    required CustomerId customerId,
    String? brand,
    String? model,
    String? serialNumber,
    PianoType? type,
    String? location,
    String? notes,
    int reminderIntervalMonths = Piano.defaultReminderIntervalMonths,
    bool remindersEnabled = true,
  }) async {
    await _requireActiveCustomer(customerId);
    final now = _clock.now();
    final piano = Piano.create(
      id: PianoId(_idGenerator.next()),
      customerId: customerId,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      type: type,
      location: location,
      notes: notes,
      reminderIntervalMonths: reminderIntervalMonths,
      remindersEnabled: remindersEnabled,
      now: now,
    );
    await _pianos.insert(piano);
    return piano;
  }

  Future<Piano?> getById(PianoId id) {
    return _pianos.findById(id);
  }

  Future<Piano> update({
    required PianoId id,
    String? brand,
    String? model,
    String? serialNumber,
    PianoType? type,
    String? location,
    String? notes,
    required int reminderIntervalMonths,
    required bool remindersEnabled,
  }) async {
    final existing = await _requirePiano(id);
    final updated = existing.changeDetails(
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      type: type,
      location: location,
      notes: notes,
      reminderIntervalMonths: reminderIntervalMonths,
      remindersEnabled: remindersEnabled,
      now: _clock.now(),
    );
    await _pianos.update(updated);
    return updated;
  }

  Future<Piano> archive(PianoId id) async {
    final existing = await _requirePiano(id);
    final archived = existing.archive(_clock.now());
    await _pianos.update(archived);
    return archived;
  }

  Future<Piano> restore(PianoId id) async {
    final existing = await _requirePiano(id);
    final restored = existing.restore(_clock.now());
    await _pianos.update(restored);
    return restored;
  }

  Future<List<Piano>> findByCustomer({
    required CustomerId customerId,
    required PianoStatusFilter filter,
  }) {
    return _pianos.findByCustomerId(customerId: customerId, filter: filter);
  }

  Future<Customer> _requireActiveCustomer(CustomerId customerId) async {
    final customer = await _customers.findById(customerId);
    if (customer == null) {
      throw CustomerNotFound(customerId);
    }
    if (customer.isArchived) {
      throw PianoCustomerArchived(customerId);
    }
    return customer;
  }

  Future<Piano> _requirePiano(PianoId id) async {
    final piano = await _pianos.findById(id);
    if (piano == null) {
      throw PianoNotFound(id);
    }
    return piano;
  }
}
