import '../../domain/shared/calendar_date.dart';
import 'dashboard_reminder.dart';

abstract interface class DashboardReminderQuery {
  Future<List<DashboardReminder>> findScheduledDueOnOrBefore({
    required CalendarDate until,
  });
}
