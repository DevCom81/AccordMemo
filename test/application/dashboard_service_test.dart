import 'package:accord_memo/application/dashboard/dashboard_reminder.dart';
import 'package:accord_memo/application/dashboard/dashboard_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixed_clock.dart';
import '../support/in_memory_dashboard_reminder_query.dart';

DashboardReminder _item(CalendarDate dueDate, String id) {
  return DashboardReminder(
    reminderId: ReminderId(id),
    pianoId: PianoId('piano-1'),
    customerId: CustomerId('customer-1'),
    dueDate: dueDate,
    lastName: 'Dupont',
    firstName: 'Jean',
  );
}

void main() {
  test('load classifie à partir du Clock injecté puis rafraîchit', () async {
    final now = DateTime.utc(2026, 9, 17, 10);
    final today = CalendarDate.fromLocalInstant(now);
    final query = InMemoryDashboardReminderQuery([
      _item(today, 'soon'),
    ]);
    final service = DashboardService(
      clock: FixedClock(now),
      query: query,
    );

    final first = await service.load();
    expect(first.today, today);
    expect(first.dueSoon, hasLength(1));
    expect(first.upcoming, isEmpty);

    query.items = [_item(today.addDays(20), 'later')];
    final second = await service.load();
    expect(second.dueSoon, isEmpty);
    expect(second.upcoming.single.reminderId.value, 'later');
  });
}
