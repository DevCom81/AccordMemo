import 'package:accord_memo/application/dashboard/dashboard_classifier.dart';
import 'package:accord_memo/application/dashboard/dashboard_reminder.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final today = CalendarDate(2026, 9, 17);

  test('classifie les frontières overdue / à traiter / à venir', () {
    final overdue = _item(today.addDays(-1), 'overdue');
    final todayItem = _item(today, 'today');
    final day7 = _item(today.addDays(7), 'day7');
    final day8 = _item(today.addDays(8), 'day8');
    final day30 = _item(today.addDays(30), 'day30');
    final day31 = _item(today.addDays(31), 'day31');

    final snapshot = classifyDashboardReminders(
      today: today,
      items: [day31, day30, day8, day7, todayItem, overdue],
    );

    expect(snapshot.overdue.map((item) => item.reminderId.value), ['overdue']);
    expect(snapshot.dueSoon.map((item) => item.reminderId.value), [
      'day7',
      'today',
    ]);
    expect(snapshot.upcoming.map((item) => item.reminderId.value), [
      'day30',
      'day8',
    ]);
    expect(snapshot.isEmpty, isFalse);
    expect(snapshot.badgeCount, 3);
    expect(snapshot.nextDue?.reminderId.value, 'overdue');
  });

  test('liste vide produit Tout est à jour', () {
    final snapshot = classifyDashboardReminders(today: today, items: const []);
    expect(snapshot.isEmpty, isTrue);
    expect(snapshot.badgeCount, 0);
    expect(snapshot.nextDue, isNull);
  });
}
