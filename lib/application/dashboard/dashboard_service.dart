import '../../domain/clock.dart';
import '../../domain/shared/calendar_date.dart';
import 'dashboard_classifier.dart';
import 'dashboard_reminder_query.dart';
import 'dashboard_snapshot.dart';

final class DashboardService {
  DashboardService({
    required this._clock,
    required this._query,
  });

  final Clock _clock;
  final DashboardReminderQuery _query;

  Future<DashboardSnapshot> load() async {
    final today = CalendarDate.fromLocalInstant(_clock.now());
    final until = today.addDays(dashboardUpcomingHorizonDays);
    final items = await _query.findScheduledDueOnOrBefore(until: until);
    return classifyDashboardReminders(today: today, items: items);
  }
}
