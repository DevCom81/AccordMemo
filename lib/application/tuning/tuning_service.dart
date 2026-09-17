import '../../domain/clock.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/shared/calendar_date.dart';
import '../../domain/tuning/tuning.dart';
import '../../domain/tuning/tuning_repository.dart';
import '../ports/id_generator.dart';

final class TuningService {
  TuningService({
    required this._clock,
    required this._idGenerator,
    required this._tunings,
    required this._pianos,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final TuningRepository _tunings;
  final PianoRepository _pianos;

  Future<Tuning> create({
    required PianoId pianoId,
    required CalendarDate tuningDate,
    String? notes,
  }) async {
    await _requirePiano(pianoId);
    final now = _clock.now();
    final tuning = Tuning.create(
      id: TuningId(_idGenerator.next()),
      pianoId: pianoId,
      tuningDate: tuningDate,
      today: _todayFrom(now),
      notes: notes,
      now: now,
    );
    await _tunings.insert(tuning);
    return tuning;
  }

  Future<Tuning?> getById(TuningId id) {
    return _tunings.findById(id);
  }

  Future<Tuning> update({
    required TuningId id,
    required CalendarDate tuningDate,
    String? notes,
  }) async {
    final existing = await _requireTuning(id);
    final now = _clock.now();
    final updated = existing.changeDetails(
      tuningDate: tuningDate,
      today: _todayFrom(now),
      notes: notes,
      now: now,
    );
    await _tunings.update(updated);
    return updated;
  }

  Future<List<Tuning>> findByPiano(PianoId pianoId) {
    return _tunings.findByPianoId(pianoId);
  }

  CalendarDate _todayFrom(DateTime now) {
    final local = now.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  Future<Piano> _requirePiano(PianoId id) async {
    final piano = await _pianos.findById(id);
    if (piano == null) {
      throw PianoNotFound(id);
    }
    return piano;
  }

  Future<Tuning> _requireTuning(TuningId id) async {
    final tuning = await _tunings.findById(id);
    if (tuning == null) {
      throw TuningNotFound(id);
    }
    return tuning;
  }
}
