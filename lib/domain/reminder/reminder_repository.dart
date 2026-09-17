import '../piano/piano.dart';
import '../tuning/tuning.dart';
import 'reminder.dart';

abstract interface class ReminderRepository {
  Future<Reminder?> findById(ReminderId id);

  Future<void> insert(Reminder reminder);

  Future<void> update(Reminder reminder);

  Future<Reminder?> findScheduledByPianoId(PianoId pianoId);

  Future<Reminder?> findByOriginTuningId(TuningId originTuningId);
}
