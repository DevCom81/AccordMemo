import 'package:drift/drift.dart';

import '../../domain/activity/activity.dart';
import '../../domain/activity/activity_repository.dart';
import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import 'app_database.dart';
import 'mappers/activity_mapper.dart';

final class DriftActivityRepository implements ActivityRepository {
  DriftActivityRepository(
    this._database, {
    this._mapper = const ActivityMapper(),
  });

  final AppDatabase _database;
  final ActivityMapper _mapper;

  @override
  Future<void> insert(Activity activity) {
    return _database
        .into(_database.activities)
        .insert(_mapper.toCompanion(activity));
  }

  @override
  Future<List<Activity>> findRecent({required int limit}) async {
    requirePositiveActivityLimit(limit);
    final rows = await (_database.select(_database.activities)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapper.toDomain).toList();
  }

  @override
  Future<List<Activity>> findByPianoId({
    required PianoId pianoId,
    required int limit,
  }) async {
    requirePositiveActivityLimit(limit);
    final rows = await (_database.select(_database.activities)
          ..where((t) => t.pianoId.equals(pianoId.value))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
    return rows.map(_mapper.toDomain).toList();
  }

  @override
  Future<List<Activity>> findByCustomerId({
    required CustomerId customerId,
    required int limit,
  }) async {
    requirePositiveActivityLimit(limit);
    final query = _database.select(_database.activities).join([
      innerJoin(
        _database.pianos,
        _database.pianos.id.equalsExp(_database.activities.pianoId),
      ),
    ]);
    query.where(_database.pianos.customerId.equals(customerId.value));
    query.orderBy([OrderingTerm.desc(_database.activities.occurredAt)]);
    query.limit(limit);
    final rows = await query.get();
    return rows
        .map((row) => _mapper.toDomain(row.readTable(_database.activities)))
        .toList();
  }
}
