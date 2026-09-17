import '../../domain/shared/calendar_date.dart';
import 'dashboard_reminder.dart';

final class DashboardSnapshot {
  const DashboardSnapshot({
    required this.today,
    required this.overdue,
    required this.dueSoon,
    required this.upcoming,
  });

  final CalendarDate today;
  final List<DashboardReminder> overdue;
  final List<DashboardReminder> dueSoon;
  final List<DashboardReminder> upcoming;

  bool get isEmpty =>
      overdue.isEmpty && dueSoon.isEmpty && upcoming.isEmpty;

  int get badgeCount => overdue.length + dueSoon.length;

  DashboardReminder? get nextDue {
    if (overdue.isNotEmpty) {
      return overdue.first;
    }
    if (dueSoon.isNotEmpty) {
      return dueSoon.first;
    }
    if (upcoming.isNotEmpty) {
      return upcoming.first;
    }
    return null;
  }
}
