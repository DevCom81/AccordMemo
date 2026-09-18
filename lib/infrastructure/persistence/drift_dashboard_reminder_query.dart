import 'package:drift/drift.dart';

import '../../application/dashboard/dashboard_reminder.dart';
import '../../application/dashboard/dashboard_reminder_query.dart';
import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_status.dart';
import '../../domain/shared/calendar_date.dart';
import 'app_database.dart';

final class DriftDashboardReminderQuery implements DashboardReminderQuery {
  DriftDashboardReminderQuery(this._database);

  final AppDatabase _database;

  @override
  Future<List<DashboardReminder>> findScheduledDueOnOrBefore({
    required CalendarDate until,
  }) async {
    final query = _database.select(_database.reminders).join([
      innerJoin(
        _database.pianos,
        _database.pianos.id.equalsExp(_database.reminders.pianoId),
      ),
      innerJoin(
        _database.customers,
        _database.customers.id.equalsExp(_database.pianos.customerId),
      ),
    ]);
    query.where(
      _database.reminders.status.equals(ReminderStatus.scheduled.name) &
          _database.reminders.dueDate.isSmallerOrEqualValue(
            until.toIso8601String(),
          ) &
          _database.pianos.archivedAt.isNull() &
          _database.customers.archivedAt.isNull() &
          _database.pianos.remindersEnabled.equals(true),
    );
    query.orderBy([OrderingTerm.asc(_database.reminders.dueDate)]);
    final rows = await query.get();
    return rows.map(_toDashboardReminder).toList();
  }

  DashboardReminder _toDashboardReminder(TypedResult row) {
    final reminder = row.readTable(_database.reminders);
    final piano = row.readTable(_database.pianos);
    final customer = row.readTable(_database.customers);
    return DashboardReminder(
      reminderId: ReminderId(reminder.id),
      pianoId: PianoId(piano.id),
      customerId: CustomerId(customer.id),
      dueDate: CalendarDate.parseIso(reminder.dueDate),
      lastName: customer.lastName,
      firstName: customer.firstName,
      city: customer.city,
      brand: piano.brand,
      model: piano.model,
      type: piano.type == null ? null : PianoType.values.byName(piano.type!),
      phone: customer.phone,
      email: customer.email,
    );
  }
}
