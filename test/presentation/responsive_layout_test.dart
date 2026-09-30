import 'dart:async';

import 'package:accord_memo/application/dashboard/dashboard_reminder.dart';
import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/application/history/history_kind.dart';
import 'package:accord_memo/application/reminder/send_reminder.dart';
import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/infrastructure/google/fake_google_auth_session.dart';
import 'package:accord_memo/infrastructure/email/fake_email_sender.dart';
import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/clients/clients_page.dart';
import 'package:accord_memo/presentation/clients/clients_providers.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/correct_tuning_dialog.dart';
import 'package:accord_memo/presentation/clients/customer_form_dialog.dart';
import 'package:accord_memo/presentation/clients/piano_form_dialog.dart';
import 'package:accord_memo/presentation/clients/piano_summary_card.dart';
import 'package:accord_memo/presentation/clients/piano_tunings_dialog.dart';
import 'package:accord_memo/presentation/clients/record_tuning_dialog.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_page.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_reminder_card.dart';
import 'package:accord_memo/presentation/dashboard/reschedule_dialog.dart';
import 'package:accord_memo/presentation/dashboard/send_reminder_dialog.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_strings.dart';
import 'package:accord_memo/presentation/history/history_page.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/settings/settings_page.dart';
import 'package:accord_memo/presentation/settings/settings_providers.dart';
import 'package:accord_memo/presentation/settings/settings_strings.dart';
import 'package:accord_memo/presentation/shell/app_shell.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_data_locator.dart';
import '../support/fake_mail_overrides.dart';
import '../support/fake_file_location_picker.dart';
import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/immediate_transaction_runner.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_customer_repository.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';

const _longName = 'Saint-Martin de la Vallée et du Lauragais';
const _longEmail = 'contact.pianos.et.concerts.du.lauragais@example.com';
final _today = CalendarDate(2026, 9, 30);
final _now = DateTime.utc(2026, 9, 30);
final _customer = Customer.create(
  id: CustomerId('responsive-customer'),
  lastName: _longName,
  firstName: 'Marie-Claire',
  email: _longEmail,
  address: 'Résidence des Musiciens, bâtiment des concerts, 123 avenue des Arts',
  city: 'Saint-Orens-de-Gameville',
  now: _now,
);
final _piano = Piano.create(
  id: PianoId('responsive-piano'),
  customerId: _customer.id,
  brand: 'Manufacture de pianos de concert',
  model: 'Grand modèle de salon édition spéciale du conservatoire',
  location: 'Salle de concert principale, deuxième étage, bâtiment des Arts',
  now: _now,
);
final _reminder = DashboardReminder(
  reminderId: ReminderId('responsive-reminder'),
  customerId: _customer.id,
  pianoId: _piano.id,
  dueDate: _today,
  lastName: _longName,
  firstName: _customer.firstName,
  email: _longEmail,
  city: _customer.city,
  brand: _piano.brand,
  model: _piano.model,
);
final _tuning = Tuning.create(
  id: TuningId('responsive-tuning'),
  pianoId: _piano.id,
  tuningDate: _today,
  today: _today,
  notes: List.filled(12, 'Notes détaillées sur cet accord.').join(' '),
  now: _now,
);

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Widget _app({Widget home = const AppShell(), bool empty = false,
  SendReminder? sendReminder, double textScale = 1}) {
  return ProviderScope(
    overrides: [
      dashboardSnapshotProvider.overrideWith((ref) async => DashboardSnapshot(
        today: _today,
        overdue: const [],
        dueSoon: empty ? [] : [_reminder],
        upcoming: const [],
      )),
      clientsSearchProvider.overrideWith((ref) async => empty ? [] : [_customer]),
      selectedCustomerPianosProvider.overrideWith((ref) async =>
          SelectedCustomerPianos(active: [_piano], archived: const [])),
      selectedCustomerLatestTuningDatesProvider.overrideWith(
        (ref) async => {_piano.id: _today},
      ),
      historySnapshotProvider.overrideWith((ref) async => empty ? [] : [
        HistoryEntry(
          activityId: ActivityId('responsive-activity'),
          occurredAt: _now,
          kind: HistoryKind.tuningCreated,
          customerLastName: _longName,
          customerArchived: false,
          pianoBrand: _piano.brand,
          pianoModel: _piano.model,
          pianoArchived: false,
          tuningDate: _today,
        ),
      ]),
      appDataLocatorProvider.overrideWith((ref) =>
          FakeAppDataLocator.displayOnly()),
      fileLocationPickerProvider.overrideWith((ref) =>
          FakeFileLocationPicker(openPath: '/fake/backup.db')),
      if (sendReminder != null)
        sendReminderProvider.overrideWith((ref) => sendReminder),
      ...fakeMailOverrides(),
    ],
    child: MaterialApp(
      theme: buildAppTheme(), home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

Future<void> _navigate(WidgetTester tester, String label) async {
  if (find.byType(AppBar).evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    final item = find.descendant(
      of: find.byType(Drawer), matching: find.text(label),
    );
    await tester.ensureVisible(item);
    await tester.tap(item);
  } else {
    await tester.tap(find.text(label).first);
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [
    const Size(600, 960),
    const Size(1024, 768),
    const Size(1400, 900),
  ]) {
    testWidgets('écrans, navigation et textes longs : $size', (tester) async {
      _size(tester, size);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AppBar), size.width < 1192
          ? findsOneWidget : findsNothing);

      await tester.scrollUntilVisible(
        find.byType(DashboardReminderCard), 300,
        scrollable: find.descendant(
          of: find.byType(DashboardPage), matching: find.byType(Scrollable),
        ).first,
      );
      expect(tester.takeException(), isNull);

      await _navigate(tester, 'Clients & Pianos');
      await tester.tap(find.textContaining(_longName).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(PianoSummaryCard), 250,
        scrollable: find.descendant(
          of: find.byType(ClientsPage), matching: find.byType(Scrollable),
        ).last,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(clientsRecordTuning), findsOneWidget);

      await _navigate(tester, 'Historique');
      expect(find.byType(HistoryPage), findsOneWidget);
      await _navigate(tester, 'Paramètres');
      await tester.scrollUntilVisible(
        find.text(settingsMailConnect), 250,
        scrollable: find.descendant(
          of: find.byType(SettingsPage), matching: find.byType(Scrollable),
        ).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('états vides : $size', (tester) async {
      _size(tester, size);
      await tester.pumpWidget(_app(empty: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _navigate(tester, 'Clients & Pianos');
      await _navigate(tester, 'Historique');
    });
  }

  for (final width in [800.0, 1024.0, 1400.0]) {
  testWidgets('recherche clients et clavier en paysage : $width', (tester) async {
    _size(tester, Size(width, 600));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _navigate(tester, 'Clients & Pianos');
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  }

  testWidgets('rotation conserve la fiche client sélectionnée', (tester) async {
    _size(tester, const Size(600, 960));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _navigate(tester, 'Clients & Pianos');
    await tester.tap(find.textContaining(_longName).first);
    await tester.pumpAndSettle();
    expect(find.text(clientsBackToList), findsOneWidget);
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(clientsBackToList), findsNothing);
    expect(find.text(_longEmail), findsOneWidget);
    tester.view.physicalSize = const Size(600, 960);
    await tester.pumpAndSettle();
    expect(find.text(clientsBackToList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texte agrandi en portrait', (tester) async {
    _size(tester, const Size(600, 960));
    await tester.pumpWidget(_app(textScale: 1.5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _navigate(tester, 'Clients & Pianos');
    await _navigate(tester, 'Historique');
    await _navigate(tester, 'Paramètres');
  });

  final forms = <String, Widget Function()>{
    'client': () => CustomerFormDialog(
      existing: _customer,
      onSubmit: ({required civility, required lastName, firstName, address,
        postalCode, city, email, phone}) async => _customer,
    ),
    'piano': () => PianoFormDialog(
      existing: _piano,
      onSubmit: ({required brand, required model, required serialNumber,
        required type, required location, required notes,
        required reminderIntervalMonths, required remindersEnabled}) async => _piano,
    ),
    'accord': () => RecordTuningDialog(
      today: _today,
      onSubmit: ({required tuningDate, notes}) async => _tuning,
    ),
    'correction': () => CorrectTuningDialog(
      today: _today, initialDate: _today, initialNotes: _tuning.notes,
      onSubmit: ({required tuningDate, notes}) async => _tuning,
    ),
  };
  for (final form in forms.entries) {
    testWidgets('formulaire ${form.key} : clavier, scroll et validation', (tester) async {
      _size(tester, const Size(800, 600));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () => showDialog<Object>(
            context: context, builder: (_) => form.value(),
          ),
          child: const Text('Ouvrir'),
        ))),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final lastField = find.byType(TextFormField).last;
      await tester.ensureVisible(lastField);
      await tester.enterText(lastField, '12');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton),
      );
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('liste des accords et notes longues en hauteur réduite', (tester) async {
    _size(tester, const Size(600, 320));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: PianoTuningsDialog(
        initialTunings: [_tuning, _tuning],
        loadTunings: () async => [_tuning],
        onSelect: (_) async => false,
        onCorrected: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('report avec nom long en hauteur réduite', (tester) async {
    _size(tester, const Size(600, 320));
    await tester.pumpWidget(_app(home: Scaffold(
      body: Consumer(builder: (context, ref, _) => TextButton(
        onPressed: () => showRescheduleDialog(
          context: context, ref: ref, reminder: _reminder, today: _today,
        ),
        child: const Text('Ouvrir'),
      )),
    )));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Enregistrer').hitTestable(), findsOneWidget);
  });

  testWidgets('preview longue : contenu scrollable et envoi accessible', (tester) async {
    _size(tester, const Size(600, 320));
    final sendReminder = await _previewService();
    await tester.pumpWidget(_app(sendReminder: sendReminder, home: Scaffold(
      body: Consumer(builder: (context, ref, _) => TextButton(
        onPressed: () => showSendReminderDialog(
          context: context, ref: ref, reminder: _reminder,
        ),
        child: const Text('Ouvrir'),
      )),
    )));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.tap(find.text(dashboardSendReminderCancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirmation restauration : scroll et annulation', (tester) async {
    _size(tester, const Size(600, 320));
    await tester.pumpWidget(_app(home: const Scaffold(body: SettingsPage())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(settingsRestoreButton), 200,
      scrollable: find.descendant(
        of: find.descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(CustomScrollView),
        ),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pumpAndSettle();
    final restoreButton = find.text(settingsRestoreButton);
    await tester.ensureVisible(restoreButton);
    await tester.pumpAndSettle();
    expect(restoreButton.hitTestable(), findsOneWidget);
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(settingsRestoreConfirm).hitTestable(), findsOneWidget);
    await tester.tap(find.text(settingsCancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final loading in [true, false]) {
    testWidgets('états ${loading ? 'chargement' : 'erreur'} en petite hauteur', (tester) async {
      _size(tester, const Size(600, 240));
      final pending = Completer<DashboardSnapshot>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dashboardSnapshotProvider.overrideWith((ref) {
            if (loading) {
              return pending.future;
            }
            throw StateError('indisponible');
          }),
          ...fakeMailOverrides(),
        ],
        child: MaterialApp(theme: buildAppTheme(),
          home: Scaffold(body: DashboardPage(onSeeAllClients: () {}))),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<SendReminder> _previewService() async {
  final customers = InMemoryCustomerRepository();
  final pianos = InMemoryPianoRepository();
  final reminders = InMemoryReminderRepository();
  await customers.insert(_customer);
  await pianos.insert(_piano);
  await reminders.insert(Reminder.schedule(
    id: _reminder.reminderId, pianoId: _piano.id,
    originTuningId: _tuning.id, dueDate: _today, now: _now,
  ));
  return SendReminder(
    reminders: ReminderService(
      clock: FixedClock(_now),
      idGenerator: FakeIdGenerator([]),
      transactions: const ImmediateTransactionRunner(),
      reminders: reminders,
      activities: InMemoryActivityRepository(pianos),
    ),
    pianos: pianos, customers: customers,
    googleAuth: FakeGoogleAuthSession.connected(accountEmail: _longEmail),
    emailSender: FakeEmailSender(),
  );
}
