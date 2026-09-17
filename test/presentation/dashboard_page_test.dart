import 'dart:async';

import 'package:accord_memo/application/dashboard/dashboard_reminder.dart';
import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_page.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_strings.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/immediate_transaction_runner.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';

DashboardReminder _reminder({
  required CalendarDate dueDate,
  String id = 'reminder-1',
}) {
  return DashboardReminder(
    reminderId: ReminderId(id),
    pianoId: PianoId('piano-1'),
    customerId: CustomerId('customer-1'),
    dueDate: dueDate,
    lastName: 'Dupont',
    firstName: 'Jean',
    city: 'Toulouse',
    brand: 'Yamaha',
    model: 'U1',
  );
}

DashboardSnapshot _snapshot({
  List<DashboardReminder> overdue = const [],
  List<DashboardReminder> dueSoon = const [],
  List<DashboardReminder> upcoming = const [],
}) {
  return DashboardSnapshot(
    today: CalendarDate(2026, 9, 17),
    overdue: overdue,
    dueSoon: dueSoon,
    upcoming: upcoming,
  );
}

Widget _dashboardApp({
  required Future<DashboardSnapshot> Function() loadSnapshot,
  ReminderService? reminderService,
  VoidCallback? onSeeAllClients,
}) {
  return ProviderScope(
    overrides: [
      dashboardSnapshotProvider.overrideWith((ref) => loadSnapshot()),
      if (reminderService != null)
        reminderServiceProvider.overrideWith((ref) => reminderService),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: DashboardPage(onSeeAllClients: onSeeAllClients ?? () {}),
    ),
  );
}

void main() {
  final today = CalendarDate(2026, 9, 17);

  Future<void> prepareDesktopSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('affiche l’empty state', (tester) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(loadSnapshot: () async => _snapshot()),
    );
    await tester.pumpAndSettle();

    expect(find.text(dashboardEmptyTitle), findsOneWidget);
    expect(find.text(dashboardEmptyBody), findsOneWidget);
  });

  testWidgets('affiche le chargement puis l’erreur sans détail technique', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    final completer = Completer<DashboardSnapshot>();
    await tester.pumpWidget(
      _dashboardApp(loadSnapshot: () => completer.future),
    );
    await tester.pump();
    expect(find.text('Chargement des rappels'), findsOneWidget);

    completer.completeError(Exception('SQLite constraint failed'));
    await tester.pumpAndSettle();
    expect(find.text(dashboardLoadErrorMessage), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('SQLite'), findsNothing);
  });

  testWidgets('le bouton Envoyer est disabled et ne mute pas le Reminder', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);

    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final activities = InMemoryActivityRepository(pianos);
    final reminder = Reminder.schedule(
      id: ReminderId('reminder-1'),
      pianoId: PianoId('piano-1'),
      originTuningId: TuningId('tuning-1'),
      dueDate: today.addDays(2),
      now: DateTime.utc(2026, 9, 17, 10),
    );
    await reminders.insert(reminder);

    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(dueSoon: [_reminder(dueDate: today.addDays(2))]);
        },
        reminderService: ReminderService(
          clock: FixedClock(DateTime.utc(2026, 9, 17, 10)),
          idGenerator: FakeIdGenerator(spareIds()),
          transactions: const ImmediateTransactionRunner(),
          reminders: reminders,
          activities: activities,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Envoyer le rappel'),
    );
    expect(send.onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Envoyer le rappel'));
    await tester.pump();

    expect((await reminders.findById(reminder.id))!.status, ReminderStatus.scheduled);
    expect(await activities.findRecent(limit: 10), isEmpty);
  });
}
