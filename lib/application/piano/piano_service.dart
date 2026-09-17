import '../../domain/clock.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/reminder/reminder_cancellation_reason.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../ports/id_generator.dart';
import '../ports/transaction_runner.dart';

final class PianoService {
  PianoService({
    required this._clock,
    required this._idGenerator,
    required this._transactions,
    required this._pianos,
    required this._customers,
    required this._reminders,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactions;
  final PianoRepository _pianos;
  final CustomerRepository _customers;
  final ReminderRepository _reminders;

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
    final now = _clock.now();
    final updated = existing.changeDetails(
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
    final disabling = existing.remindersEnabled && !remindersEnabled;
    if (!disabling) {
      await _pianos.update(updated);
      return updated;
    }

    return _transactions.run(() async {
      await _pianos.update(updated);
      await _cancelScheduled(
        pianoId: id,
        reason: ReminderCancellationReason.remindersDisabled,
        now: now,
      );
      return updated;
    });
  }

  Future<Piano> archive(PianoId id) async {
    final now = _clock.now();
    return _transactions.run(() async {
      final existing = await _requirePiano(id);
      final archived = existing.archive(now);
      await _pianos.update(archived);
      await _cancelScheduled(
        pianoId: id,
        reason: ReminderCancellationReason.pianoArchived,
        now: now,
      );
      return archived;
    });
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

  Future<void> _cancelScheduled({
    required PianoId pianoId,
    required ReminderCancellationReason reason,
    required DateTime now,
  }) async {
    final scheduled = await _reminders.findScheduledByPianoId(pianoId);
    if (scheduled == null) {
      return;
    }
    await _reminders.update(scheduled.cancel(reason: reason, now: now));
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
