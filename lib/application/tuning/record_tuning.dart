import '../../domain/activity/activity.dart';
import '../../domain/activity/activity_repository.dart';
import '../../domain/clock.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_cancellation_reason.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../../domain/shared/calendar_date.dart';
import '../../domain/tuning/tuning.dart';
import '../../domain/tuning/tuning_repository.dart';
import '../ports/id_generator.dart';
import '../ports/transaction_runner.dart';

final class RecordTuning {
  RecordTuning({
    required this._clock,
    required this._idGenerator,
    required this._transactions,
    required this._tunings,
    required this._pianos,
    required this._reminders,
    required this._activities,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactions;
  final TuningRepository _tunings;
  final PianoRepository _pianos;
  final ReminderRepository _reminders;
  final ActivityRepository _activities;

  Future<Tuning> execute({
    required PianoId pianoId,
    required CalendarDate tuningDate,
    String? notes,
  }) async {
    final now = _clock.now();
    final today = CalendarDate.fromLocalInstant(now);
    return _transactions.run(() async {
      final piano = await _requirePiano(pianoId);
      final tuning = Tuning.create(
        id: TuningId(_idGenerator.next()),
        pianoId: piano.id,
        tuningDate: tuningDate,
        today: today,
        notes: notes,
        now: now,
      );
      await _tunings.insert(tuning);

      final scheduled = await _reminders.findScheduledByPianoId(piano.id);
      if (scheduled != null) {
        await _reminders.update(
          scheduled.cancel(
            reason: ReminderCancellationReason.supersededByTuning,
            now: now,
          ),
        );
      }

      if (piano.remindersEnabled) {
        final reminder = Reminder.schedule(
          id: ReminderId(_idGenerator.next()),
          pianoId: piano.id,
          originTuningId: tuning.id,
          dueDate: tuning.tuningDate.addMonths(piano.reminderIntervalMonths),
          now: now,
        );
        await _reminders.insert(reminder);
      }

      await _activities.insert(
        Activity.tuningCreated(
          id: ActivityId(_idGenerator.next()),
          pianoId: piano.id,
          tuningId: tuning.id,
          now: now,
        ),
      );

      return tuning;
    });
  }

  Future<Piano> _requirePiano(PianoId id) async {
    final piano = await _pianos.findById(id);
    if (piano == null) {
      throw PianoNotFound(id);
    }
    return piano;
  }
}
