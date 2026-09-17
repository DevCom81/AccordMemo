import 'package:accord_memo/application/dashboard/dashboard_reminder.dart';
import 'package:accord_memo/application/dashboard/dashboard_reminder_query.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';

final class InMemoryDashboardReminderQuery implements DashboardReminderQuery {
  InMemoryDashboardReminderQuery([List<DashboardReminder>? items])
    : items = items ?? [];

  List<DashboardReminder> items;

  @override
  Future<List<DashboardReminder>> findScheduledDueOnOrBefore({
    required CalendarDate until,
  }) async {
    final matches = items
        .where((item) => item.dueDate <= until)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return matches;
  }
}
