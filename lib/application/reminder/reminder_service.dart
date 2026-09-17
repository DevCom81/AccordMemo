import '../../domain/activity/activity.dart';
import '../../domain/activity/activity_repository.dart';
import '../../domain/clock.dart';
import '../../domain/piano/piano.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_cancellation_reason.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../../domain/shared/calendar_date.dart';
import '../ports/id_generator.dart';
import '../ports/transaction_runner.dart';

final class ReminderService {
  ReminderService({
    required this._clock,
    required this._idGenerator,
    required this._transactions,
    required this._reminders,
    required this._activities,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactions;
  final ReminderRepository _reminders;
  final ActivityRepository _activities;

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
      today: CalendarDate.fromLocalInstant(now),
      now: now,
    );
    return _transactions.run(() async {
      await _reminders.update(updated);
      await _activities.insert(
        Activity.reminderRescheduled(
          id: ActivityId(_idGenerator.next()),
          pianoId: existing.pianoId,
          reminderId: existing.id,
          previousDate: existing.dueDate,
          newDate: updated.dueDate,
          now: now,
        ),
      );
      return updated;
    });
  }

  Future<Reminder> markSent(ReminderId id) async {
    final existing = await _requireReminder(id);
    final now = _clock.now();
    final updated = existing.markSent(now);
    return _transactions.run(() async {
      await _reminders.update(updated);
      await _activities.insert(
        Activity.reminderSent(
          id: ActivityId(_idGenerator.next()),
          pianoId: existing.pianoId,
          reminderId: existing.id,
          now: now,
        ),
      );
      return updated;
    });
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
