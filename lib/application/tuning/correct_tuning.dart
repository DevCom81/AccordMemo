import '../../domain/activity/activity.dart';
import '../../domain/activity/activity_repository.dart';
import '../../domain/clock.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../../domain/reminder/reminder_status.dart';
import '../../domain/shared/calendar_date.dart';
import '../../domain/tuning/tuning.dart';
import '../../domain/tuning/tuning_repository.dart';
import '../ports/id_generator.dart';
import '../ports/transaction_runner.dart';

final class CorrectTuning {
  CorrectTuning({
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
    required TuningId id,
    required CalendarDate tuningDate,
    String? notes,
  }) async {
    final now = _clock.now();
    final today = _todayFrom(now);
    final existing = await _requireTuning(id);
    final updated = existing.changeDetails(
      tuningDate: tuningDate,
      today: today,
      notes: notes,
      now: now,
    );
    final dateChanged = existing.tuningDate != tuningDate;

    return _transactions.run(() async {
      await _tunings.update(updated);
      if (dateChanged) {
        final reminder = await _reminders.findByOriginTuningId(existing.id);
        if (reminder != null &&
            reminder.status == ReminderStatus.scheduled &&
            !reminder.manuallyRescheduled) {
          final piano = await _requirePiano(existing.pianoId);
          await _reminders.update(
            reminder.recalculateAutomaticDueDate(
              dueDate: updated.tuningDate.addMonths(piano.reminderIntervalMonths),
              now: now,
            ),
          );
        }
      }

      await _activities.insert(
        Activity.tuningUpdated(
          id: ActivityId(_idGenerator.next()),
          pianoId: existing.pianoId,
          tuningId: existing.id,
          previousDate: dateChanged ? existing.tuningDate : null,
          newDate: dateChanged ? updated.tuningDate : null,
          now: now,
        ),
      );
      return updated;
    });
  }

  Future<Tuning> _requireTuning(TuningId id) async {
    final tuning = await _tunings.findById(id);
    if (tuning == null) {
      throw TuningNotFound(id);
    }
    return tuning;
  }

  Future<Piano> _requirePiano(PianoId id) async {
    final piano = await _pianos.findById(id);
    if (piano == null) {
      throw PianoNotFound(id);
    }
    return piano;
  }
}

CalendarDate _todayFrom(DateTime now) {
  final local = now.toLocal();
  return CalendarDate(local.year, local.month, local.day);
}
