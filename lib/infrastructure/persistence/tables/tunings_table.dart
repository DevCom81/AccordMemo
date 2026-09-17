import 'package:drift/drift.dart';

import 'pianos_table.dart';

@DataClassName('TuningRecord')
class Tunings extends Table {
  TextColumn get id => text()();
  TextColumn get pianoId => text().references(
    Pianos,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get tuningDate => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
