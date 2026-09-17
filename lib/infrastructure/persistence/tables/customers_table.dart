import 'package:drift/drift.dart';

@DataClassName('CustomerRecord')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get civility => text().nullable()();
  TextColumn get lastName => text()();
  TextColumn get firstName => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
