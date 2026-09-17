import 'package:drift/drift.dart';

import '../../../domain/customer/customer.dart';
import '../../../domain/piano/piano.dart';
import '../../../domain/piano/piano_repository.dart';
import 'app_database.dart';
import 'mappers/piano_mapper.dart';

final class DriftPianoRepository implements PianoRepository {
  DriftPianoRepository(this._database, {this._mapper = const PianoMapper()});

  final AppDatabase _database;
  final PianoMapper _mapper;

  @override
  Future<Piano?> findById(PianoId id) async {
    final row = await (_database.select(
      _database.pianos,
    )..where((t) => t.id.equals(id.value))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.toDomain(row);
  }

  @override
  Future<void> insert(Piano piano) {
    return _database.into(_database.pianos).insert(_mapper.toCompanion(piano));
  }

  @override
  Future<void> update(Piano piano) async {
    final written = await (_database.update(_database.pianos)
          ..where((t) => t.id.equals(piano.id.value)))
        .write(_mapper.toCompanion(piano));
    if (written == 0) {
      throw PianoNotFound(piano.id);
    }
  }

  @override
  Future<List<Piano>> findByCustomerId({
    required CustomerId customerId,
    required PianoStatusFilter filter,
  }) async {
    final rows =
        await (_database.select(_database.pianos)
              ..where((t) => _customerFilter(t, customerId, filter))
              ..orderBy([
                (t) => OrderingTerm.asc(t.brand),
                (t) => OrderingTerm.asc(t.model),
              ]))
            .get();
    return rows.map(_mapper.toDomain).toList();
  }

  Expression<bool> _customerFilter(
    $PianosTable table,
    CustomerId customerId,
    PianoStatusFilter filter,
  ) {
    final customerClause = table.customerId.equals(customerId.value);
    final archivedClause = filter == PianoStatusFilter.archived
        ? table.archivedAt.isNotNull()
        : table.archivedAt.isNull();
    return customerClause & archivedClause;
  }
}
