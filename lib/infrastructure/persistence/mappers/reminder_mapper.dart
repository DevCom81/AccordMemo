import 'package:drift/drift.dart';

import '../../../domain/piano/piano.dart';
import '../../../domain/reminder/reminder.dart';
import '../../../domain/reminder/reminder_cancellation_reason.dart';
import '../../../domain/reminder/reminder_status.dart';
import '../../../domain/shared/calendar_date.dart';
import '../../../domain/tuning/tuning.dart';
import '../app_database.dart';

final class ReminderMapper {
  const ReminderMapper();

  Reminder toDomain(ReminderRecord row) {
    return Reminder.reconstitute(
      id: ReminderId(row.id),
      pianoId: PianoId(row.pianoId),
      originTuningId: TuningId(row.originTuningId),
      dueDate: CalendarDate.parseIso(row.dueDate),
      status: ReminderStatus.values.byName(row.status),
      manuallyRescheduled: row.manuallyRescheduled,
      cancellationReason: row.cancellationReason == null
          ? null
          : ReminderCancellationReason.values.byName(row.cancellationReason!),
      sentAt: row.sentAt?.toUtc(),
      cancelledAt: row.cancelledAt?.toUtc(),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  RemindersCompanion toCompanion(Reminder reminder) {
    return RemindersCompanion(
      id: Value(reminder.id.value),
      pianoId: Value(reminder.pianoId.value),
      originTuningId: Value(reminder.originTuningId.value),
      dueDate: Value(reminder.dueDate.toIso8601String()),
      status: Value(reminder.status.name),
      manuallyRescheduled: Value(reminder.manuallyRescheduled),
      cancellationReason: Value(reminder.cancellationReason?.name),
      sentAt: Value(reminder.sentAt?.toUtc()),
      cancelledAt: Value(reminder.cancelledAt?.toUtc()),
      createdAt: Value(reminder.createdAt.toUtc()),
      updatedAt: Value(reminder.updatedAt.toUtc()),
    );
  }
}
