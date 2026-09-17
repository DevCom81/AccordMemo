import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_repository.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';

final class InMemoryReminderRepository implements ReminderRepository {
  final Map<String, Reminder> _reminders = {};

  @override
  Future<Reminder?> findById(ReminderId id) async {
    return _reminders[id.value];
  }

  @override
  Future<void> insert(Reminder reminder) async {
    _reminders[reminder.id.value] = reminder;
  }

  @override
  Future<void> update(Reminder reminder) async {
    if (!_reminders.containsKey(reminder.id.value)) {
      throw ReminderNotFound(reminder.id);
    }
    _reminders[reminder.id.value] = reminder;
  }

  @override
  Future<Reminder?> findScheduledByPianoId(PianoId pianoId) async {
    for (final reminder in _reminders.values) {
      if (reminder.pianoId == pianoId &&
          reminder.status == ReminderStatus.scheduled) {
        return reminder;
      }
    }
    return null;
  }

  @override
  Future<Reminder?> findByOriginTuningId(TuningId originTuningId) async {
    for (final reminder in _reminders.values) {
      if (reminder.originTuningId == originTuningId) {
        return reminder;
      }
    }
    return null;
  }
}
