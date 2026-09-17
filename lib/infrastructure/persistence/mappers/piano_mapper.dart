import 'package:drift/drift.dart';

import '../../../domain/customer/customer.dart';
import '../../../domain/piano/piano.dart';
import '../../../domain/piano/piano_type.dart';
import '../app_database.dart';

final class PianoMapper {
  const PianoMapper();

  Piano toDomain(PianoRecord row) {
    return Piano.reconstitute(
      id: PianoId(row.id),
      customerId: CustomerId(row.customerId),
      brand: row.brand,
      model: row.model,
      serialNumber: row.serialNumber,
      type: row.type == null ? null : PianoType.values.byName(row.type!),
      location: row.location,
      notes: row.notes,
      reminderIntervalMonths: row.reminderIntervalMonths,
      remindersEnabled: row.remindersEnabled,
      archivedAt: row.archivedAt?.toUtc(),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  PianosCompanion toCompanion(Piano piano) {
    return PianosCompanion(
      id: Value(piano.id.value),
      customerId: Value(piano.customerId.value),
      brand: Value(piano.brand),
      model: Value(piano.model),
      serialNumber: Value(piano.serialNumber),
      type: Value(piano.type?.name),
      location: Value(piano.location),
      notes: Value(piano.notes),
      reminderIntervalMonths: Value(piano.reminderIntervalMonths),
      remindersEnabled: Value(piano.remindersEnabled),
      archivedAt: Value(piano.archivedAt?.toUtc()),
      createdAt: Value(piano.createdAt.toUtc()),
      updatedAt: Value(piano.updatedAt.toUtc()),
    );
  }
}
