import '../customer/customer.dart';
import 'piano_type.dart';

final class PianoId {
  const PianoId._(this.value);

  factory PianoId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const PianoIdInvalid();
    }
    return PianoId._(value);
  }

  final String value;

  @override
  bool operator ==(Object other) => other is PianoId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

sealed class PianoException implements Exception {
  const PianoException();
}

final class PianoIdInvalid extends PianoException {
  const PianoIdInvalid();

  @override
  String toString() => 'PianoIdInvalid';
}

final class PianoIdentificationRequired extends PianoException {
  const PianoIdentificationRequired();

  @override
  String toString() => 'PianoIdentificationRequired';
}

final class PianoReminderIntervalOutOfRange extends PianoException {
  const PianoReminderIntervalOutOfRange(this.months);

  final int months;

  @override
  String toString() => 'PianoReminderIntervalOutOfRange($months)';
}

final class PianoAlreadyArchived extends PianoException {
  const PianoAlreadyArchived();

  @override
  String toString() => 'PianoAlreadyArchived';
}

final class PianoNotArchived extends PianoException {
  const PianoNotArchived();

  @override
  String toString() => 'PianoNotArchived';
}

final class PianoArchivedNotModifiable extends PianoException {
  const PianoArchivedNotModifiable();

  @override
  String toString() => 'PianoArchivedNotModifiable';
}

final class PianoNotFound extends PianoException {
  const PianoNotFound(this.id);

  final PianoId id;

  @override
  String toString() => 'PianoNotFound($id)';
}

final class PianoCustomerArchived extends PianoException {
  const PianoCustomerArchived(this.customerId);

  final CustomerId customerId;

  @override
  String toString() => 'PianoCustomerArchived($customerId)';
}

final class Piano {
  static const defaultReminderIntervalMonths = 12;
  static const minReminderIntervalMonths = 1;
  static const maxReminderIntervalMonths = 60;

  const Piano._({
    required this.id,
    required this.customerId,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.type,
    required this.location,
    required this.notes,
    required this.reminderIntervalMonths,
    required this.remindersEnabled,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Piano.create({
    required PianoId id,
    required CustomerId customerId,
    String? brand,
    String? model,
    String? serialNumber,
    PianoType? type,
    String? location,
    String? notes,
    int reminderIntervalMonths = defaultReminderIntervalMonths,
    bool remindersEnabled = true,
    required DateTime now,
  }) {
    final normalizedBrand = _optionalText(brand);
    final normalizedModel = _optionalText(model);
    _assertIdentified(
      brand: normalizedBrand,
      model: normalizedModel,
      type: type,
    );

    return Piano._(
      id: id,
      customerId: customerId,
      brand: normalizedBrand,
      model: normalizedModel,
      serialNumber: _optionalText(serialNumber),
      type: type,
      location: _optionalText(location),
      notes: _optionalText(notes),
      reminderIntervalMonths: _requireInterval(reminderIntervalMonths),
      remindersEnabled: remindersEnabled,
      archivedAt: null,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  }

  /// Hydratation depuis la persistance. Ne pas utiliser pour modifier une fiche.
  factory Piano.reconstitute({
    required PianoId id,
    required CustomerId customerId,
    String? brand,
    String? model,
    String? serialNumber,
    PianoType? type,
    String? location,
    String? notes,
    required int reminderIntervalMonths,
    required bool remindersEnabled,
    DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final normalizedBrand = _optionalText(brand);
    final normalizedModel = _optionalText(model);
    _assertIdentified(
      brand: normalizedBrand,
      model: normalizedModel,
      type: type,
    );

    return Piano._(
      id: id,
      customerId: customerId,
      brand: normalizedBrand,
      model: normalizedModel,
      serialNumber: _optionalText(serialNumber),
      type: type,
      location: _optionalText(location),
      notes: _optionalText(notes),
      reminderIntervalMonths: _requireInterval(reminderIntervalMonths),
      remindersEnabled: remindersEnabled,
      archivedAt: archivedAt?.toUtc(),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  final PianoId id;
  final CustomerId customerId;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final PianoType? type;
  final String? location;
  final String? notes;
  final int reminderIntervalMonths;
  final bool remindersEnabled;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  Piano changeDetails({
    String? brand,
    String? model,
    String? serialNumber,
    PianoType? type,
    String? location,
    String? notes,
    required int reminderIntervalMonths,
    required bool remindersEnabled,
    required DateTime now,
  }) {
    if (isArchived) {
      throw const PianoArchivedNotModifiable();
    }

    final normalizedBrand = _optionalText(brand);
    final normalizedModel = _optionalText(model);
    _assertIdentified(
      brand: normalizedBrand,
      model: normalizedModel,
      type: type,
    );

    return Piano._(
      id: id,
      customerId: customerId,
      brand: normalizedBrand,
      model: normalizedModel,
      serialNumber: _optionalText(serialNumber),
      type: type,
      location: _optionalText(location),
      notes: _optionalText(notes),
      reminderIntervalMonths: _requireInterval(reminderIntervalMonths),
      remindersEnabled: remindersEnabled,
      archivedAt: null,
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  Piano archive(DateTime now) {
    if (isArchived) {
      throw const PianoAlreadyArchived();
    }

    return Piano._(
      id: id,
      customerId: customerId,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      type: type,
      location: location,
      notes: notes,
      reminderIntervalMonths: reminderIntervalMonths,
      remindersEnabled: remindersEnabled,
      archivedAt: now.toUtc(),
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  Piano restore(DateTime now) {
    if (!isArchived) {
      throw const PianoNotArchived();
    }

    return Piano._(
      id: id,
      customerId: customerId,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      type: type,
      location: location,
      notes: notes,
      reminderIntervalMonths: reminderIntervalMonths,
      remindersEnabled: remindersEnabled,
      archivedAt: null,
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) => other is Piano && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void _assertIdentified({
  required String? brand,
  required String? model,
  required PianoType? type,
}) {
  if (brand == null && model == null && type == null) {
    throw const PianoIdentificationRequired();
  }
}

int _requireInterval(int months) {
  if (months < Piano.minReminderIntervalMonths ||
      months > Piano.maxReminderIntervalMonths) {
    throw PianoReminderIntervalOutOfRange(months);
  }
  return months;
}

String? _optionalText(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
