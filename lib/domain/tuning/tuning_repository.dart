import '../piano/piano.dart';
import 'tuning.dart';

abstract interface class TuningRepository {
  Future<Tuning?> findById(TuningId id);

  Future<void> insert(Tuning tuning);

  Future<void> update(Tuning tuning);

  Future<List<Tuning>> findByPianoId(PianoId pianoId);
}
