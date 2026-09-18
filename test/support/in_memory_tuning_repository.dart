import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/domain/tuning/tuning_repository.dart';

final class InMemoryTuningRepository implements TuningRepository {
  final Map<String, Tuning> _tunings = {};

  Iterable<Tuning> get all => _tunings.values;

  @override
  Future<Tuning?> findById(TuningId id) async {
    return _tunings[id.value];
  }

  @override
  Future<void> insert(Tuning tuning) async {
    _tunings[tuning.id.value] = tuning;
  }

  @override
  Future<void> update(Tuning tuning) async {
    if (!_tunings.containsKey(tuning.id.value)) {
      throw TuningNotFound(tuning.id);
    }
    _tunings[tuning.id.value] = tuning;
  }

  @override
  Future<List<Tuning>> findByPianoId(PianoId pianoId) async {
    final matches = _tunings.values
        .where((tuning) => tuning.pianoId == pianoId)
        .toList();
    matches.sort((a, b) => b.tuningDate.compareTo(a.tuningDate));
    return matches;
  }
}
