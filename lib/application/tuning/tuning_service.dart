import '../../domain/piano/piano.dart';
import '../../domain/tuning/tuning.dart';
import '../../domain/tuning/tuning_repository.dart';

final class TuningService {
  TuningService({required this._tunings});

  final TuningRepository _tunings;

  Future<Tuning?> getById(TuningId id) {
    return _tunings.findById(id);
  }

  Future<List<Tuning>> findByPiano(PianoId pianoId) {
    return _tunings.findByPianoId(pianoId);
  }
}
