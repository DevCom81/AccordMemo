import 'package:drift/drift.dart';

import '../../../domain/activity/activity.dart';
import '../../../domain/activity/activity_type.dart';
import '../../../domain/piano/piano.dart';
import '../../../domain/reminder/reminder.dart';
import '../../../domain/shared/calendar_date.dart';
import '../../../domain/tuning/tuning.dart';
import '../app_database.dart';

final class ActivityMapper {
  const ActivityMapper();

  Activity toDomain(ActivityRecord row) {
    return Activity.reconstitute(
      id: ActivityId(row.id),
      type: ActivityType.values.byName(row.type),
      pianoId: PianoId(row.pianoId),
      tuningId: row.tuningId == null ? null : TuningId(row.tuningId!),
      reminderId: row.reminderId == null ? null : ReminderId(row.reminderId!),
      previousDate: row.previousDate == null
          ? null
          : CalendarDate.parseIso(row.previousDate!),
      newDate: row.newDate == null ? null : CalendarDate.parseIso(row.newDate!),
      occurredAt: row.occurredAt.toUtc(),
    );
  }

  ActivitiesCompanion toCompanion(Activity activity) {
    return ActivitiesCompanion(
      id: Value(activity.id.value),
      type: Value(activity.type.name),
      pianoId: Value(activity.pianoId.value),
      tuningId: Value(activity.tuningId?.value),
      reminderId: Value(activity.reminderId?.value),
      previousDate: Value(activity.previousDate?.toIso8601String()),
      newDate: Value(activity.newDate?.toIso8601String()),
      occurredAt: Value(activity.occurredAt.toUtc()),
    );
  }
}
