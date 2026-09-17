import '../piano/piano.dart';
import '../reminder/reminder.dart';
import '../shared/calendar_date.dart';
import '../tuning/tuning.dart';
import 'activity_type.dart';

final class ActivityId {
  const ActivityId._(this.value);

  factory ActivityId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const ActivityIdInvalid();
    }
    return ActivityId._(value);
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is ActivityId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

sealed class ActivityException implements Exception {
  const ActivityException();
}

final class ActivityIdInvalid extends ActivityException {
  const ActivityIdInvalid();

  @override
  String toString() => 'ActivityIdInvalid';
}

final class ActivityInvariantViolated extends ActivityException {
  const ActivityInvariantViolated();

  @override
  String toString() => 'ActivityInvariantViolated';
}

final class ActivityLimitInvalid extends ActivityException {
  const ActivityLimitInvalid(this.limit);

  final int limit;

  @override
  String toString() => 'ActivityLimitInvalid($limit)';
}

final class Activity {
  const Activity._({
    required this.id,
    required this.type,
    required this.pianoId,
    required this.tuningId,
    required this.reminderId,
    required this.previousDate,
    required this.newDate,
    required this.occurredAt,
  });

  factory Activity.tuningCreated({
    required ActivityId id,
    required PianoId pianoId,
    required TuningId tuningId,
    required DateTime now,
  }) {
    return Activity._validated(
      id: id,
      type: ActivityType.tuningCreated,
      pianoId: pianoId,
      tuningId: tuningId,
      reminderId: null,
      previousDate: null,
      newDate: null,
      now: now,
    );
  }

  factory Activity.tuningUpdated({
    required ActivityId id,
    required PianoId pianoId,
    required TuningId tuningId,
    CalendarDate? previousDate,
    CalendarDate? newDate,
    required DateTime now,
  }) {
    return Activity._validated(
      id: id,
      type: ActivityType.tuningUpdated,
      pianoId: pianoId,
      tuningId: tuningId,
      reminderId: null,
      previousDate: previousDate,
      newDate: newDate,
      now: now,
    );
  }

  factory Activity.reminderRescheduled({
    required ActivityId id,
    required PianoId pianoId,
    required ReminderId reminderId,
    required CalendarDate previousDate,
    required CalendarDate newDate,
    required DateTime now,
  }) {
    return Activity._validated(
      id: id,
      type: ActivityType.reminderRescheduled,
      pianoId: pianoId,
      tuningId: null,
      reminderId: reminderId,
      previousDate: previousDate,
      newDate: newDate,
      now: now,
    );
  }

  factory Activity.reminderSent({
    required ActivityId id,
    required PianoId pianoId,
    required ReminderId reminderId,
    required DateTime now,
  }) {
    return Activity._validated(
      id: id,
      type: ActivityType.reminderSent,
      pianoId: pianoId,
      tuningId: null,
      reminderId: reminderId,
      previousDate: null,
      newDate: null,
      now: now,
    );
  }

  factory Activity.reminderDisabled({
    required ActivityId id,
    required PianoId pianoId,
    required DateTime now,
  }) {
    return Activity._validated(
      id: id,
      type: ActivityType.reminderDisabled,
      pianoId: pianoId,
      tuningId: null,
      reminderId: null,
      previousDate: null,
      newDate: null,
      now: now,
    );
  }

  factory Activity.reminderReenabled({
    required ActivityId id,
    required PianoId pianoId,
    required DateTime now,
  }) {
    return Activity._validated(
      id: id,
      type: ActivityType.reminderReenabled,
      pianoId: pianoId,
      tuningId: null,
      reminderId: null,
      previousDate: null,
      newDate: null,
      now: now,
    );
  }

  /// Hydratation depuis la persistance. Ne pas utiliser pour modifier un journal.
  factory Activity.reconstitute({
    required ActivityId id,
    required ActivityType type,
    required PianoId pianoId,
    TuningId? tuningId,
    ReminderId? reminderId,
    CalendarDate? previousDate,
    CalendarDate? newDate,
    required DateTime occurredAt,
  }) {
    return Activity._validated(
      id: id,
      type: type,
      pianoId: pianoId,
      tuningId: tuningId,
      reminderId: reminderId,
      previousDate: previousDate,
      newDate: newDate,
      now: occurredAt,
    );
  }

  factory Activity._validated({
    required ActivityId id,
    required ActivityType type,
    required PianoId pianoId,
    required TuningId? tuningId,
    required ReminderId? reminderId,
    required CalendarDate? previousDate,
    required CalendarDate? newDate,
    required DateTime now,
  }) {
    _assertShape(
      type: type,
      tuningId: tuningId,
      reminderId: reminderId,
      previousDate: previousDate,
      newDate: newDate,
    );
    return Activity._(
      id: id,
      type: type,
      pianoId: pianoId,
      tuningId: tuningId,
      reminderId: reminderId,
      previousDate: previousDate,
      newDate: newDate,
      occurredAt: now.toUtc(),
    );
  }

  final ActivityId id;
  final ActivityType type;
  final PianoId pianoId;
  final TuningId? tuningId;
  final ReminderId? reminderId;
  final CalendarDate? previousDate;
  final CalendarDate? newDate;
  final DateTime occurredAt;

  @override
  bool operator ==(Object other) => other is Activity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void _assertShape({
  required ActivityType type,
  required TuningId? tuningId,
  required ReminderId? reminderId,
  required CalendarDate? previousDate,
  required CalendarDate? newDate,
}) {
  final datesEitherBothOrNeither =
      (previousDate == null) == (newDate == null);
  if (!datesEitherBothOrNeither) {
    throw const ActivityInvariantViolated();
  }

  switch (type) {
    case ActivityType.tuningCreated:
      if (tuningId == null ||
          reminderId != null ||
          previousDate != null ||
          newDate != null) {
        throw const ActivityInvariantViolated();
      }
    case ActivityType.tuningUpdated:
      if (tuningId == null || reminderId != null) {
        throw const ActivityInvariantViolated();
      }
    case ActivityType.reminderRescheduled:
      if (reminderId == null ||
          tuningId != null ||
          previousDate == null ||
          newDate == null) {
        throw const ActivityInvariantViolated();
      }
    case ActivityType.reminderSent:
      if (reminderId == null ||
          tuningId != null ||
          previousDate != null ||
          newDate != null) {
        throw const ActivityInvariantViolated();
      }
    case ActivityType.reminderDisabled:
    case ActivityType.reminderReenabled:
      if (tuningId != null ||
          reminderId != null ||
          previousDate != null ||
          newDate != null) {
        throw const ActivityInvariantViolated();
      }
  }
}
