import 'package:drift/drift.dart';

import 'pianos_table.dart';
import 'tunings_table.dart';

@DataClassName('ReminderRecord')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get pianoId => text().references(
    Pianos,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get originTuningId => text().references(
    Tunings,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get dueDate => text()();
  TextColumn get status => text()();
  BoolColumn get manuallyRescheduled => boolean()();
  TextColumn get cancellationReason => text().nullable()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('scheduled', 'sent', 'cancelled'))",
  ];
}
