import 'package:drift/drift.dart';

import '../../domain/piano/piano.dart';
import '../../domain/tuning/tuning.dart';
import '../../domain/tuning/tuning_repository.dart';
import 'app_database.dart';
import 'mappers/tuning_mapper.dart';

final class DriftTuningRepository implements TuningRepository {
  DriftTuningRepository(this._database, {this._mapper = const TuningMapper()});

  final AppDatabase _database;
  final TuningMapper _mapper;

  @override
  Future<Tuning?> findById(TuningId id) async {
    final row = await (_database.select(
      _database.tunings,
    )..where((t) => t.id.equals(id.value))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.toDomain(row);
  }

  @override
  Future<void> insert(Tuning tuning) {
    return _database.into(_database.tunings).insert(_mapper.toCompanion(tuning));
  }

  @override
  Future<void> update(Tuning tuning) async {
    final written = await (_database.update(_database.tunings)
          ..where((t) => t.id.equals(tuning.id.value)))
        .write(_mapper.toCompanion(tuning));
    if (written == 0) {
      throw TuningNotFound(tuning.id);
    }
  }

  @override
  Future<List<Tuning>> findByPianoId(PianoId pianoId) async {
    final rows =
        await (_database.select(_database.tunings)
              ..where((t) => t.pianoId.equals(pianoId.value))
              ..orderBy([(t) => OrderingTerm.desc(t.tuningDate)]))
            .get();
    return rows.map(_mapper.toDomain).toList();
  }
}
