import 'civility.dart';

final class CustomerId {
  const CustomerId._(this.value);

  factory CustomerId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const CustomerIdInvalid();
    }
    return CustomerId._(value);
  }

  final String value;

  @override
  bool operator ==(Object other) => other is CustomerId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

sealed class CustomerException implements Exception {
  const CustomerException();
}

final class CustomerIdInvalid extends CustomerException {
  const CustomerIdInvalid();

  @override
  String toString() => 'CustomerIdInvalid';
}

final class CustomerLastNameRequired extends CustomerException {
  const CustomerLastNameRequired();

  @override
  String toString() => 'CustomerLastNameRequired';
}

final class CustomerAlreadyArchived extends CustomerException {
  const CustomerAlreadyArchived();

  @override
  String toString() => 'CustomerAlreadyArchived';
}

final class CustomerNotArchived extends CustomerException {
  const CustomerNotArchived();

  @override
  String toString() => 'CustomerNotArchived';
}

final class CustomerArchivedNotModifiable extends CustomerException {
  const CustomerArchivedNotModifiable();

  @override
  String toString() => 'CustomerArchivedNotModifiable';
}

final class CustomerNotFound extends CustomerException {
  const CustomerNotFound(this.id);

  final CustomerId id;

  @override
  String toString() => 'CustomerNotFound($id)';
}

final class Customer {
  const Customer._({
    required this.id,
    required this.civility,
    required this.lastName,
    required this.firstName,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.email,
    required this.phone,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.create({
    required CustomerId id,
    Civility? civility,
    required String lastName,
    String? firstName,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
    required DateTime now,
  }) {
    return Customer._(
      id: id,
      civility: civility,
      lastName: _requireLastName(lastName),
      firstName: _optionalText(firstName),
      address: _optionalText(address),
      postalCode: _optionalText(postalCode),
      city: _optionalText(city),
      email: _optionalText(email),
      phone: _optionalText(phone),
      archivedAt: null,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  }

  /// Hydratation depuis la persistance. Ne pas utiliser pour modifier une fiche.
  factory Customer.reconstitute({
    required CustomerId id,
    Civility? civility,
    required String lastName,
    String? firstName,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
    DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Customer._(
      id: id,
      civility: civility,
      lastName: _requireLastName(lastName),
      firstName: _optionalText(firstName),
      address: _optionalText(address),
      postalCode: _optionalText(postalCode),
      city: _optionalText(city),
      email: _optionalText(email),
      phone: _optionalText(phone),
      archivedAt: archivedAt?.toUtc(),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  final CustomerId id;
  final Civility? civility;
  final String lastName;
  final String? firstName;
  final String? address;
  final String? postalCode;
  final String? city;
  final String? email;
  final String? phone;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  Customer changeDetails({
    Civility? civility,
    required String lastName,
    String? firstName,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
    required DateTime now,
  }) {
    if (isArchived) {
      throw const CustomerArchivedNotModifiable();
    }

    return Customer._(
      id: id,
      civility: civility,
      lastName: _requireLastName(lastName),
      firstName: _optionalText(firstName),
      address: _optionalText(address),
      postalCode: _optionalText(postalCode),
      city: _optionalText(city),
      email: _optionalText(email),
      phone: _optionalText(phone),
      archivedAt: null,
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  Customer archive(DateTime now) {
    if (isArchived) {
      throw const CustomerAlreadyArchived();
    }

    return Customer._(
      id: id,
      civility: civility,
      lastName: lastName,
      firstName: firstName,
      address: address,
      postalCode: postalCode,
      city: city,
      email: email,
      phone: phone,
      archivedAt: now.toUtc(),
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  Customer restore(DateTime now) {
    if (!isArchived) {
      throw const CustomerNotArchived();
    }

    return Customer._(
      id: id,
      civility: civility,
      lastName: lastName,
      firstName: firstName,
      address: address,
      postalCode: postalCode,
      city: city,
      email: email,
      phone: phone,
      archivedAt: null,
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) => other is Customer && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

String _requireLastName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw const CustomerLastNameRequired();
  }
  return trimmed;
}

String? _optionalText(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
