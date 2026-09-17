import 'package:drift/drift.dart';

import 'pianos_table.dart';
import 'reminders_table.dart';
import 'tunings_table.dart';

@DataClassName('ActivityRecord')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get pianoId => text().references(
    Pianos,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get tuningId => text().nullable().references(
    Tunings,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get reminderId => text().nullable().references(
    Reminders,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get previousDate => text().nullable()();
  TextColumn get newDate => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('tuningCreated', 'tuningUpdated', 'reminderRescheduled', "
        "'reminderSent', 'reminderDisabled', 'reminderReenabled'))",
  ];
}
