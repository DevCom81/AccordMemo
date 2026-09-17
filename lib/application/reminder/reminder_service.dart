import '../../domain/clock.dart';
import '../../domain/piano/piano.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_cancellation_reason.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../../domain/shared/calendar_date.dart';

final class ReminderService {
  ReminderService({
    required this._clock,
    required this._reminders,
  });

  final Clock _clock;
  final ReminderRepository _reminders;

  Future<Reminder?> getById(ReminderId id) {
    return _reminders.findById(id);
  }

  Future<Reminder?> findScheduledByPiano(PianoId pianoId) {
    return _reminders.findScheduledByPianoId(pianoId);
  }

  Future<Reminder> reschedule({
    required ReminderId id,
    required CalendarDate newDueDate,
  }) async {
    final existing = await _requireReminder(id);
    final now = _clock.now();
    final updated = existing.reschedule(
      newDueDate: newDueDate,
      today: _todayFrom(now),
      now: now,
    );
    await _reminders.update(updated);
    return updated;
  }

  Future<Reminder> markSent(ReminderId id) async {
    final existing = await _requireReminder(id);
    final updated = existing.markSent(_clock.now());
    await _reminders.update(updated);
    return updated;
  }

  Future<Reminder> cancel({
    required ReminderId id,
    required ReminderCancellationReason reason,
  }) async {
    final existing = await _requireReminder(id);
    final updated = existing.cancel(reason: reason, now: _clock.now());
    await _reminders.update(updated);
    return updated;
  }

  Future<Reminder> _requireReminder(ReminderId id) async {
    final reminder = await _reminders.findById(id);
    if (reminder == null) {
      throw ReminderNotFound(id);
    }
    return reminder;
  }
}

CalendarDate _todayFrom(DateTime now) {
  final local = now.toLocal();
  return CalendarDate(local.year, local.month, local.day);
}
