import 'dart:async';

import 'package:accord_memo/application/dashboard/dashboard_reminder.dart';
import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_page.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_reminder_card.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_strings.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
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
  String pianoId = 'piano-1',
  String lastName = 'Dupont',
  String? firstName = 'Jean',
  String? city = 'Toulouse',
  String? brand = 'Yamaha',
  String? model = 'U1',
  String? phone,
  String? email,
}) {
  return DashboardReminder(
    reminderId: ReminderId(id),
    pianoId: PianoId(pianoId),
    customerId: CustomerId('customer-1'),
    dueDate: dueDate,
    lastName: lastName,
    firstName: firstName,
    city: city,
    brand: brand,
    model: model,
    phone: phone,
    email: email,
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
  Future<List<HistoryEntry>> Function()? loadHistory,
  ReminderService? reminderService,
  VoidCallback? onSeeAllClients,
}) {
  return ProviderScope(
    overrides: [
      dashboardSnapshotProvider.overrideWith((ref) => loadSnapshot()),
      historySnapshotProvider.overrideWith((ref) {
        return loadHistory?.call() ?? Future.value(const <HistoryEntry>[]);
      }),
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

  testWidgets('affiche Relance prioritaire pour un rappel en retard', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            overdue: [_reminder(dueDate: today.addDays(-14))],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(dashboardHeroTitle.toUpperCase()), findsOneWidget);
    expect(find.text('14 jours de retard'), findsWidgets);
  });

  testWidgets('distingue deux pianos du même client', (tester) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            overdue: [
              _reminder(
                id: 'reminder-kawai',
                pianoId: 'piano-kawai',
                dueDate: today.addDays(-3),
                lastName: 'École Sainte-Cécile',
                firstName: null,
                city: 'Montpellier',
                brand: 'Kawai',
                model: 'K300',
              ),
              _reminder(
                id: 'reminder-yamaha',
                pianoId: 'piano-yamaha',
                dueDate: today.addDays(-1),
                lastName: 'École Sainte-Cécile',
                firstName: null,
                city: 'Montpellier',
                brand: 'Yamaha',
                model: 'C3',
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kawai K300'), findsWidgets);
    expect(find.text('Yamaha C3'), findsOneWidget);
    expect(find.text('École Sainte-Cécile'), findsWidgets);
  });

  testWidgets('ne répète pas le badge En retard dans les cartes', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            overdue: [
              _reminder(id: 'overdue-1', dueDate: today.addDays(-14)),
              _reminder(
                id: 'overdue-2',
                pianoId: 'piano-2',
                dueDate: today.addDays(-3),
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EN RETARD'), findsOneWidget);
    expect(find.text('En retard'), findsOneWidget);
  });

  testWidgets('n’overflow pas à 900×700', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            overdue: [_reminder(dueDate: today.addDays(-14))],
            dueSoon: [_reminder(id: 'soon', pianoId: 'piano-soon', dueDate: today)],
            upcoming: [
              _reminder(
                id: 'later',
                pianoId: 'piano-later',
                dueDate: today.addDays(12),
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('invalide l’historique après un report de rappel', (tester) async {
    await prepareDesktopSurface(tester);

    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final activities = InMemoryActivityRepository(pianos);
    final reminder = Reminder.schedule(
      id: ReminderId('reminder-1'),
      pianoId: PianoId('piano-1'),
      originTuningId: TuningId('tuning-1'),
      dueDate: today.addDays(-14),
      now: DateTime.utc(2026, 9, 17, 10),
    );
    await reminders.insert(reminder);
    var historyLoads = 0;
    var dashboardLoads = 0;

    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          dashboardLoads += 1;
          return _snapshot(
            overdue: [_reminder(dueDate: today.addDays(-14))],
          );
        },
        loadHistory: () async {
          historyLoads += 1;
          return const <HistoryEntry>[];
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    container.listen(
      historySnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pumpAndSettle();
    expect(historyLoads, 1);
    expect(dashboardLoads, 1);

    await tester.tap(find.text('Reporter'));
    await tester.pumpAndSettle();
    expect(find.text('Reporter le rappel'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(historyLoads, 2);
    expect(dashboardLoads, 2);
    expect((await reminders.findById(reminder.id))!.dueDate, today);
  });

  testWidgets('affiche le téléphone quand il est renseigné', (tester) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            dueSoon: [
              _reminder(dueDate: today.addDays(2), phone: '0612345678'),
            ],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('0612345678'), findsWidgets);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('affiche l’email quand il est renseigné', (tester) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            dueSoon: [
              _reminder(dueDate: today.addDays(2), email: 'jean@example.com'),
            ],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('jean@example.com'), findsWidgets);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('affiche téléphone et email quand ils sont renseignés', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            dueSoon: [
              _reminder(
                dueDate: today.addDays(2),
                phone: '0612345678',
                email: 'jean@example.com',
              ),
            ],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('0612345678'), findsWidgets);
    expect(find.text('jean@example.com'), findsWidgets);
  });

  testWidgets('n’affiche aucun placeholder sans coordonnées', (tester) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            dueSoon: [_reminder(dueDate: today.addDays(2))],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Non renseigné'), findsNothing);
    expect(find.text('Téléphone'), findsNothing);
    expect(find.text('Email'), findsNothing);
  });

  testWidgets('ignore téléphone et email vides ou seulement des espaces', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            dueSoon: [
              _reminder(
                dueDate: today.addDays(2),
                phone: '   ',
                email: ' ',
              ),
            ],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('   '), findsNothing);
    expect(find.text(' '), findsNothing);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('affiche les coordonnées dans la relance prioritaire', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            overdue: [
              _reminder(
                dueDate: today.addDays(-14),
                phone: '0612345678',
                email: 'jean@example.com',
              ),
            ],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(dashboardHeroTitle.toUpperCase()), findsOneWidget);
    expect(find.text('0612345678'), findsNWidgets(2));
    expect(find.text('jean@example.com'), findsNWidgets(2));
  });

  testWidgets('n’overflow pas en largeur étroite avec téléphone et email', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            child: DashboardReminderCard(
              reminder: _reminder(
                dueDate: today.addDays(-14),
                phone: '06 12 34 56 78',
                email: 'jean.dupont@exemple-long.fr',
              ),
              today: today,
              bucket: DashboardReminderBucket.overdue,
              onReschedule: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('06 12 34 56 78'), findsOneWidget);
    expect(find.text('jean.dupont@exemple-long.fr'), findsOneWidget);
  });

  testWidgets('conserve Envoyer le rappel disabled avec des coordonnées', (
    tester,
  ) async {
    await prepareDesktopSurface(tester);
    await tester.pumpWidget(
      _dashboardApp(
        loadSnapshot: () async {
          return _snapshot(
            dueSoon: [
              _reminder(
                dueDate: today.addDays(2),
                phone: '0612345678',
                email: 'jean@example.com',
              ),
            ],
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Envoyer le rappel'),
    );
    expect(send.onPressed, isNull);
  });
}
