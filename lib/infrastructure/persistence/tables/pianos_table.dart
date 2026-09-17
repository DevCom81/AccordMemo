import 'package:drift/drift.dart';

import 'customers_table.dart';

@DataClassName('PianoRecord')
class Pianos extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(
    Customers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get reminderIntervalMonths => integer()();
  BoolColumn get remindersEnabled => boolean()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
