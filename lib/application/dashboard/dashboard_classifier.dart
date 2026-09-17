import '../../domain/shared/calendar_date.dart';
import 'dashboard_reminder.dart';
import 'dashboard_snapshot.dart';

const dashboardDueSoonHorizonDays = 7;
const dashboardUpcomingHorizonDays = 30;

DashboardSnapshot classifyDashboardReminders({
  required CalendarDate today,
  required List<DashboardReminder> items,
}) {
  final dueSoonEnd = today.addDays(dashboardDueSoonHorizonDays);
  final upcomingStart = today.addDays(dashboardDueSoonHorizonDays + 1);
  final upcomingEnd = today.addDays(dashboardUpcomingHorizonDays);

  final overdue = <DashboardReminder>[];
  final dueSoon = <DashboardReminder>[];
  final upcoming = <DashboardReminder>[];

  for (final item in items) {
    if (item.dueDate < today) {
      overdue.add(item);
    } else if (item.dueDate <= dueSoonEnd) {
      dueSoon.add(item);
    } else if (item.dueDate >= upcomingStart && item.dueDate <= upcomingEnd) {
      upcoming.add(item);
    }
  }

  return DashboardSnapshot(
    today: today,
    overdue: overdue,
    dueSoon: dueSoon,
    upcoming: upcoming,
  );
}
