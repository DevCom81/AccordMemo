import 'package:drift/drift.dart';

import '../../application/history/history_entry.dart';
import '../../application/history/history_kind.dart';
import '../../application/history/history_query.dart';
import '../../domain/activity/activity.dart';
import '../../domain/activity/activity_repository.dart';
import '../../domain/activity/activity_type.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/shared/calendar_date.dart';
import 'app_database.dart';

final class DriftHistoryQuery implements HistoryQuery {
  DriftHistoryQuery(this._database);

  final AppDatabase _database;

  @override
  Future<List<HistoryEntry>> findRecent({
    required int limit,
    required HistoryKindFilter filter,
  }) async {
    requirePositiveActivityLimit(limit);
    final query = _database.select(_database.activities).join([
      innerJoin(
        _database.pianos,
        _database.pianos.id.equalsExp(_database.activities.pianoId),
      ),
      innerJoin(
        _database.customers,
        _database.customers.id.equalsExp(_database.pianos.customerId),
      ),
      leftOuterJoin(
        _database.tunings,
        _database.tunings.id.equalsExp(_database.activities.tuningId),
      ),
      leftOuterJoin(
        _database.reminders,
        _database.reminders.id.equalsExp(_database.activities.reminderId),
      ),
    ]);
    switch (filter) {
      case HistoryKindFilter.all:
        break;
      case HistoryKindFilter.tunings:
        query.where(
          _database.activities.type.isIn([
            ActivityType.tuningCreated.name,
            ActivityType.tuningUpdated.name,
          ]),
        );
      case HistoryKindFilter.reminders:
        query.where(
          _database.activities.type.isIn([
            ActivityType.reminderRescheduled.name,
            ActivityType.reminderSent.name,
            ActivityType.reminderDisabled.name,
            ActivityType.reminderReenabled.name,
          ]),
        );
    }
    query.orderBy([
      OrderingTerm.desc(_database.activities.occurredAt),
      OrderingTerm.desc(_database.activities.id),
    ]);
    query.limit(limit);
    final rows = await query.get();
    return rows.map(_toEntry).toList();
  }

  HistoryEntry _toEntry(TypedResult row) {
    final activity = row.readTable(_database.activities);
    final piano = row.readTable(_database.pianos);
    final customer = row.readTable(_database.customers);
    final tuning = row.readTableOrNull(_database.tunings);
    final reminder = row.readTableOrNull(_database.reminders);
    return HistoryEntry(
      activityId: ActivityId(activity.id),
      occurredAt: activity.occurredAt.toUtc(),
      kind: HistoryKind.values.byName(activity.type),
      customerLastName: customer.lastName,
      customerFirstName: customer.firstName,
      customerArchived: customer.archivedAt != null,
      pianoBrand: piano.brand,
      pianoModel: piano.model,
      pianoType: piano.type == null ? null : PianoType.values.byName(piano.type!),
      pianoArchived: piano.archivedAt != null,
      previousDate: activity.previousDate == null
          ? null
          : CalendarDate.parseIso(activity.previousDate!),
      newDate: activity.newDate == null
          ? null
          : CalendarDate.parseIso(activity.newDate!),
      tuningDate: tuning == null
          ? null
          : CalendarDate.parseIso(tuning.tuningDate),
      reminderDueDate: reminder == null
          ? null
          : CalendarDate.parseIso(reminder.dueDate),
    );
  }
}
