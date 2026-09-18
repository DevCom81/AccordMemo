import 'dart:async';
import 'dart:io';

import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/application/dashboard/dashboard_snapshot.dart';
import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/application/piano/piano_service.dart';
import 'package:accord_memo/application/tuning/record_tuning.dart';
import 'package:accord_memo/domain/customer/civility.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/domain/piano/piano_type.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_cancellation_reason.dart';
import 'package:accord_memo/domain/reminder/reminder_repository.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/domain/tuning/tuning_repository.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/clients/clients_page.dart';
import 'package:accord_memo/presentation/clients/clients_providers.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/piano_summary_card.dart';
import 'package:accord_memo/presentation/formatters/french_date_label.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/immediate_transaction_runner.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_customer_repository.dart';
import '../support/in_memory_latest_piano_tuning_query.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';
import '../support/in_memory_tuning_repository.dart';

final _now = DateTime.utc(2026, 9, 17, 10);

CalendarDate get _today => CalendarDate.fromLocalInstant(_now);

DashboardSnapshot get _emptyDashboard => DashboardSnapshot(
  today: _today,
  overdue: const [],
  dueSoon: const [],
  upcoming: const [],
);

Customer _customer({
  required String id,
  required String lastName,
  String? firstName,
  Civility? civility,
  String? address,
  String? postalCode,
  String? city,
  String? email,
  String? phone,
  bool archived = false,
}) {
  var customer = Customer.create(
    id: CustomerId(id),
    civility: civility,
    lastName: lastName,
    firstName: firstName,
    address: address,
    postalCode: postalCode,
    city: city,
    email: email,
    phone: phone,
    now: _now,
  );
  if (archived) {
    customer = customer.archive(_now);
  }
  return customer;
}

Piano _piano({
  required String id,
  required CustomerId customerId,
  String? brand,
  String? model,
  PianoType? type,
  String? location,
  int reminderIntervalMonths = 12,
  bool remindersEnabled = true,
  bool archived = false,
}) {
  var piano = Piano.create(
    id: PianoId(id),
    customerId: customerId,
    brand: brand,
    model: model,
    type: type,
    location: location,
    reminderIntervalMonths: reminderIntervalMonths,
    remindersEnabled: remindersEnabled,
    now: _now,
  );
  if (archived) {
    piano = piano.archive(_now);
  }
  return piano;
}

CustomerService _customerService(
  CustomerRepository customers,
  PianoRepository pianos, {
  ReminderRepository? reminders,
}) {
  return CustomerService(
    clock: FixedClock(_now),
    idGenerator: FakeIdGenerator(spareIds()),
    transactions: const ImmediateTransactionRunner(),
    repository: customers,
    pianos: pianos,
    reminders: reminders ?? InMemoryReminderRepository(),
    activities: InMemoryActivityRepository(pianos),
  );
}

PianoService _pianoService(
  CustomerRepository customers,
  PianoRepository pianos, {
  ReminderRepository? reminders,
}) {
  return PianoService(
    clock: FixedClock(_now),
    idGenerator: FakeIdGenerator(spareIds()),
    transactions: const ImmediateTransactionRunner(),
    pianos: pianos,
    customers: customers,
    reminders: reminders ?? InMemoryReminderRepository(),
    activities: InMemoryActivityRepository(pianos),
  );
}

Widget _clientsApp({
  required CustomerRepository customers,
  PianoRepository? pianos,
  ReminderRepository? reminders,
  InMemoryTuningRepository? tunings,
  RecordTuning? recordTuning,
  Future<DashboardSnapshot> Function()? loadDashboard,
  Future<List<HistoryEntry>> Function()? loadHistory,
}) {
  final pianoRepo = pianos ?? InMemoryPianoRepository();
  final reminderRepo = reminders ?? InMemoryReminderRepository();
  final tuningRepo = tunings ?? InMemoryTuningRepository();
  final clock = FixedClock(_now);
  return ProviderScope(
    overrides: [
      clockProvider.overrideWith((ref) => clock),
      customerServiceProvider.overrideWith(
        (ref) => _customerService(
          customers,
          pianoRepo,
          reminders: reminderRepo,
        ),
      ),
      pianoServiceProvider.overrideWith(
        (ref) => _pianoService(customers, pianoRepo, reminders: reminderRepo),
      ),
      latestPianoTuningQueryProvider.overrideWith(
        (ref) => InMemoryLatestPianoTuningQuery(
          pianos: pianoRepo,
          tunings: tuningRepo,
        ),
      ),
      recordTuningProvider.overrideWith(
        (ref) =>
            recordTuning ??
            RecordTuning(
              clock: clock,
              idGenerator: FakeIdGenerator(spareIds()),
              transactions: const ImmediateTransactionRunner(),
              tunings: tuningRepo,
              pianos: pianoRepo,
              reminders: reminderRepo,
              activities: InMemoryActivityRepository(pianoRepo),
            ),
      ),
      dashboardSnapshotProvider.overrideWith((ref) {
        return loadDashboard?.call() ?? Future.value(_emptyDashboard);
      }),
      historySnapshotProvider.overrideWith((ref) {
        return loadHistory?.call() ?? Future.value(const <HistoryEntry>[]);
      }),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: ClientsPage()),
    ),
  );
}

Future<void> _prepareDesktop(WidgetTester tester, {Size size = const Size(1400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _pianoCard(String name) {
  return find.ancestor(
    of: find.text(name),
    matching: find.byType(PianoSummaryCard),
  );
}

Finder _recordTuningOnCard(String pianoName) {
  return find.descendant(
    of: _pianoCard(pianoName),
    matching: find.widgetWithText(FilledButton, clientsRecordTuning),
  );
}

Finder _recordTuningDialogTitle() {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(clientsRecordTuningTitle),
  );
}

String _lastTuningLabel(CalendarDate date) {
  return '$clientsLastTuningPrefix${formatFrenchNumericDate(date)}';
}

void main() {
  testWidgets('affiche l’état vide des clients actifs', (tester) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(_clientsApp(customers: InMemoryCustomerRepository()));
    await tester.pumpAndSettle();

    expect(find.text(clientsPageTitle), findsOneWidget);
    expect(find.text(clientsEmptyActiveTitle), findsOneWidget);
    expect(find.text(clientsEmptyActiveBody), findsOneWidget);
  });

  testWidgets('liste les clients actifs et masque les archivés', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
        phone: '05 61 00 00 00',
      ),
    );
    await customers.insert(
      _customer(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        lastName: 'Martin',
        firstName: 'Marie',
        city: 'Albi',
        archived: true,
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();

    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('Toulouse · 05 61 00 00 00'), findsOneWidget);
    expect(find.text('Marie Martin'), findsNothing);

    await tester.tap(find.text(clientsFilterArchived));
    await tester.pumpAndSettle();

    expect(find.text('Marie Martin'), findsOneWidget);
    expect(find.text('Jean Dupont'), findsNothing);
  });

  testWidgets('debounce la recherche de 300 ms', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
      ),
    );
    await customers.insert(
      _customer(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        lastName: 'Fabre',
        firstName: 'Marguerite',
        city: 'Albi',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'toulouse');
    await tester.pump();
    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('Marguerite Fabre'), findsOneWidget);

    await tester.pump(clientsSearchDebounce);
    await tester.pumpAndSettle();

    expect(find.text('Jean Dupont'), findsOneWidget);
    expect(find.text('Marguerite Fabre'), findsNothing);
  });

  testWidgets('affiche aucun résultat si la recherche ne correspond pas', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(clientsSearchDebounce);
    await tester.pumpAndSettle();

    expect(find.text(clientsEmptySearchTitle), findsOneWidget);
    expect(find.text(clientsEmptySearchBody), findsOneWidget);
    expect(find.text('Jean Dupont'), findsNothing);
  });

  testWidgets('affiche le chargement puis l’erreur sans détail technique', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final completer = Completer<List<Customer>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientsSearchProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ClientsPage()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(clientsLoadingMessage), findsOneWidget);

    completer.completeError(Exception('SQLite constraint failed'));
    await tester.pumpAndSettle();
    expect(find.text(clientsLoadErrorMessage), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('SQLite'), findsNothing);
  });

  testWidgets('sélectionne un client dans la liste', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jean Dupont'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(
      container.read(selectedCustomerIdProvider),
      CustomerId('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
    );
  });

  testWidgets('n’overflow pas à 900×700', (tester) async {
    await _prepareDesktop(tester, size: const Size(900, 700));
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
        email: 'jean@example.com',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Jean Dupont'), findsOneWidget);
  });

  testWidgets('affiche la fiche du client sélectionné en master/detail', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      civility: Civility.monsieur,
      lastName: 'Dupont',
      firstName: 'Jean',
      address: '12 rue des Arts',
      postalCode: '31000',
      city: 'Toulouse',
      phone: '05 61 00 00 00',
      email: 'jean@example.com',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
        type: PianoType.droit,
        location: 'Salon',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    expect(find.text(clientsSelectPrompt), findsOneWidget);

    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(find.text(clientsSelectPrompt), findsNothing);
    expect(find.text('Monsieur'), findsOneWidget);
    expect(find.text('12 rue des Arts'), findsOneWidget);
    expect(find.text('31000 Toulouse'), findsOneWidget);
    expect(find.text(clientsPhoneLabel), findsOneWidget);
    expect(find.text('05 61 00 00 00'), findsWidgets);
    expect(find.text(clientsEmailLabel), findsOneWidget);
    expect(find.text('jean@example.com'), findsOneWidget);
    expect(find.text('Yamaha U1'), findsOneWidget);
    expect(find.text('Piano droit'), findsOneWidget);
    expect(find.text('Salon'), findsOneWidget);
    expect(find.text(clientsReminderEveryMonths(12)), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(clientsBackToList), findsNothing);
  });

  testWidgets('n’affiche que les pianos du client sélectionné', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final ecole = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'École Sainte-Cécile',
      city: 'Montpellier',
    );
    final fabre = _customer(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      lastName: 'Fabre',
      firstName: 'Marguerite',
      city: 'Toulouse',
    );
    await customers.insert(ecole);
    await customers.insert(fabre);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: ecole.id,
        brand: 'Kawai',
        model: 'K300',
        type: PianoType.droit,
      ),
    );
    await pianos.insert(
      _piano(
        id: '22222222-2222-4222-8222-222222222222',
        customerId: ecole.id,
        brand: 'Yamaha',
        model: 'C3',
        type: PianoType.queue,
      ),
    );
    await pianos.insert(
      _piano(
        id: '33333333-3333-4333-8333-333333333333',
        customerId: fabre.id,
        brand: 'Pleyel',
        model: '1920',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('École Sainte-Cécile'));
    await tester.pumpAndSettle();

    expect(find.text('Kawai K300'), findsOneWidget);
    expect(find.text('Yamaha C3'), findsOneWidget);
    expect(find.text('Pleyel 1920'), findsNothing);
  });

  testWidgets('affiche l’état sans piano', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(find.text(clientsNoPianoTitle), findsOneWidget);
    expect(find.text(clientsNoPianoBody), findsOneWidget);
  });

  testWidgets('permet de consulter un client archivé sans action Modifier', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Martin',
        firstName: 'Marie',
        city: 'Albi',
        archived: true,
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text(clientsFilterArchived));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Martin'));
    await tester.pumpAndSettle();

    expect(find.text(clientsArchivedBanner), findsOneWidget);
    expect(find.text('Albi'), findsWidgets);
    expect(find.text(clientsEditCustomer), findsNothing);
    expect(find.text(clientsArchiveAction), findsNothing);
    expect(find.text(clientsRestoreAction), findsOneWidget);
    expect(find.text(clientsAddPiano), findsNothing);
    expect(find.text(clientsRecordTuning), findsNothing);
  });

  testWidgets('distingue un piano archivé sans bouton mort', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );
    await pianos.insert(
      _piano(
        id: '22222222-2222-4222-8222-222222222222',
        customerId: dupont.id,
        brand: 'Schimmel',
        model: '120',
        archived: true,
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(find.text('Yamaha U1'), findsOneWidget);
    expect(find.text('Schimmel 120'), findsNothing);
    await tester.tap(find.text(clientsArchivedPianosSection));
    await tester.pumpAndSettle();
    expect(find.text('Schimmel 120'), findsOneWidget);
    expect(_recordTuningOnCard('Yamaha U1'), findsOneWidget);
    expect(_recordTuningOnCard('Schimmel 120'), findsNothing);
    expect(
      find.descendant(
        of: _pianoCard('Schimmel 120'),
        matching: find.text(clientsEditCustomer),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _pianoCard('Schimmel 120'),
        matching: find.text(clientsArchiveAction),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _pianoCard('Schimmel 120'),
        matching: find.text(clientsRestoreAction),
      ),
      findsOneWidget,
    );
  });

  testWidgets('en largeur réduite ouvre la fiche puis revient à la liste', (
    tester,
  ) async {
    await _prepareDesktop(tester, size: const Size(900, 700));
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(clientsSelectPrompt), findsNothing);

    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(find.text(clientsBackToList), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(clientsNoPianoTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(clientsBackToList));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(clientsNoPianoTitle), findsNothing);
  });

  testWidgets('efface la fiche si la recherche ne contient plus le client', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
        city: 'Toulouse',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    expect(find.text(clientsNoPianoTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(clientsSearchDebounce);
    await tester.pumpAndSettle();

    expect(find.text(clientsEmptySearchTitle), findsOneWidget);
    expect(find.text(clientsNoPianoTitle), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), isNull);
  });

  testWidgets('n’interroge les pianos qu’après sélection, sans N+1', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final inner = InMemoryPianoRepository();
    final counting = _CountingPianoRepository(inner);
    final first = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final second = _customer(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      lastName: 'Fabre',
      firstName: 'Marguerite',
    );
    await customers.insert(first);
    await customers.insert(second);
    await inner.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: first.id,
        brand: 'Yamaha',
      ),
    );
    await inner.insert(
      _piano(
        id: '22222222-2222-4222-8222-222222222222',
        customerId: second.id,
        brand: 'Kawai',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: counting));
    await tester.pumpAndSettle();
    expect(counting.findByCustomerCalls, 0);

    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    expect(counting.findByCustomerCalls, 2);
    expect(find.text('Yamaha'), findsOneWidget);
    expect(find.text('Kawai'), findsNothing);
  });

  testWidgets('affiche l’erreur de chargement des pianos sans détail technique', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerServiceProvider.overrideWith(
            (ref) => _customerService(customers, InMemoryPianoRepository()),
          ),
          pianoServiceProvider.overrideWith(
            (ref) => _pianoService(customers, InMemoryPianoRepository()),
          ),
          latestPianoTuningQueryProvider.overrideWith(
            (ref) => InMemoryLatestPianoTuningQuery(
              pianos: InMemoryPianoRepository(),
              tunings: InMemoryTuningRepository(),
            ),
          ),
          dashboardSnapshotProvider.overrideWith((ref) async => _emptyDashboard),
          selectedCustomerPianosProvider.overrideWith((ref) async {
            throw Exception('SQLite constraint failed');
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ClientsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(find.text(clientsPianosLoadError), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.text('Jean Dupont'), findsWidgets);
  });

  testWidgets('ouvre le formulaire de création', (tester) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(_clientsApp(customers: InMemoryCustomerRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, clientsNewCustomer));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(clientsCreateTitle),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, clientsLastNameLabel),
      findsOneWidget,
    );
  });

  testWidgets('refuse la création sans nom', (tester) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(_clientsApp(customers: InMemoryCustomerRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, clientsNewCustomer));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pump();

    expect(find.text(clientsLastNameRequired), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('crée un client via CustomerService puis affiche sa fiche', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, clientsNewCustomer));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsLastNameLabel),
      'Bernard',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsCityLabel),
      'Castres',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Bernard'), findsWidgets);
    expect(find.text('Castres'), findsWidgets);

    final created = await customers.findById(
      CustomerId('00000000-0000-4000-8000-000000000001'),
    );
    expect(created, isNotNull);
    expect(created!.lastName, 'Bernard');
    expect(created.city, 'Castres');
    expect(created.isArchived, isFalse);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), created.id);
    expect(container.read(clientsFilterProvider), CustomerStatusFilter.active);
    expect(find.text(clientsSelectPrompt), findsNothing);
    expect(find.text(clientsEditCustomer), findsOneWidget);
    expect(find.text(clientsNoPianoTitle), findsOneWidget);
  });

  testWidgets('préremplit la modification et affiche les nouvelles valeurs', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      civility: Civility.monsieur,
      lastName: 'Dupont',
      firstName: 'Jean',
      city: 'Toulouse',
      email: 'jean@example.com',
    );
    await customers.insert(dupont);

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(clientsEditCustomer));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(clientsEditTitle),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, clientsLastNameLabel),
          )
          .controller
          ?.text,
      'Dupont',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, clientsFirstNameLabel),
          )
          .controller
          ?.text,
      'Jean',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, clientsCityLabel),
          )
          .controller
          ?.text,
      'Toulouse',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, clientsCityLabel),
      'Albi',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Jean Dupont'), findsWidgets);
    expect(find.text('Albi'), findsWidgets);
    expect(find.text('Toulouse'), findsNothing);

    final updated = await customers.findById(dupont.id);
    expect(updated!.city, 'Albi');
    expect(updated.isArchived, isFalse);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), dupont.id);
  });

  testWidgets('demande confirmation puis archive via CustomerService', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    var historyLoads = 0;
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        loadHistory: () async {
          historyLoads += 1;
          return const <HistoryEntry>[];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    final archiveContainer = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    archiveContainer.listen(
      historySnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pumpAndSettle();
    expect(historyLoads, 1);
    await tester.tap(find.text(clientsArchiveAction));
    await tester.pumpAndSettle();

    expect(find.text(clientsArchiveTitle), findsOneWidget);
    expect(find.text(clientsArchiveBody), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, clientsCancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsWidgets);
    expect((await customers.findById(dupont.id))!.isArchived, isFalse);

    await tester.tap(find.text(clientsArchiveAction));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsArchiveConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Jean Dupont'), findsNothing);
    expect((await customers.findById(dupont.id))!.isArchived, isTrue);
    expect(historyLoads, 2);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), isNull);

    await tester.tap(find.text(clientsFilterArchived));
    await tester.pumpAndSettle();
    expect(find.text('Jean Dupont'), findsOneWidget);
  });

  testWidgets('restaure un client via CustomerService sans Modifier', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final martin = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Martin',
      firstName: 'Marie',
      archived: true,
    );
    await customers.insert(martin);

    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text(clientsFilterArchived));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Martin'));
    await tester.pumpAndSettle();
    expect(find.text(clientsEditCustomer), findsNothing);

    await tester.tap(find.text(clientsRestoreAction));
    await tester.pumpAndSettle();
    expect(find.text(clientsRestoreTitle), findsOneWidget);
    expect(find.text(clientsRestoreBody), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRestoreConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Marie Martin'), findsWidgets);
    expect(find.text(clientsEditCustomer), findsOneWidget);
    expect(find.text(clientsArchivedBanner), findsNothing);
    expect((await customers.findById(martin.id))!.isArchived, isFalse);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), martin.id);
    expect(container.read(clientsFilterProvider), CustomerStatusFilter.active);
  });

  testWidgets('désactive les actions pendant une mutation', (tester) async {
    await _prepareDesktop(tester);
    final inner = InMemoryCustomerRepository();
    final gate = Completer<void>();
    await tester.pumpWidget(
      _clientsApp(customers: _DelayedInsertCustomerRepository(inner, gate)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, clientsNewCustomer));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsLastNameLabel),
      'Bernard',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(TextButton, clientsCancel),
            ),
          )
          .onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Bernard'), findsWidgets);
  });

  testWidgets('présente une erreur de mutation sans détail technique', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(
      _clientsApp(customers: _FailingInsertCustomerRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, clientsNewCustomer));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsLastNameLabel),
      'Bernard',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsMutationGenericError), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('ouvre le formulaire de création de piano', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );
    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, clientsAddPiano));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(clientsCreatePianoTitle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('refuse un piano sans marque, modèle ni type', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );
    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, clientsAddPiano));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pump();

    expect(find.text(clientsPianoIdentificationRequired), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('refuse un intervalle hors 1..60', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );
    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, clientsAddPiano));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsPianoBrandLabel),
      'Yamaha',
    );
    final interval = find.widgetWithText(
      TextFormField,
      clientsPianoIntervalLabel,
    );
    await tester.ensureVisible(interval);
    await tester.enterText(interval, '61');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pump();

    expect(find.text(clientsPianoIntervalInvalid), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('crée un piano via PianoService et conserve le client', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);

    await tester.pumpWidget(
      _clientsApp(customers: customers, pianos: pianos, reminders: reminders),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, clientsAddPiano));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsPianoBrandLabel),
      'Yamaha',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsPianoModelLabel),
      'U1',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Yamaha U1'), findsOneWidget);
    expect(find.text(clientsNoPianoTitle), findsNothing);

    final created = await pianos.findById(
      PianoId('00000000-0000-4000-8000-000000000001'),
    );
    expect(created, isNotNull);
    expect(created!.customerId, dupont.id);
    expect(created.brand, 'Yamaha');
    expect(created.model, 'U1');
    expect(created.isArchived, isFalse);
    expect(await reminders.findScheduledByPianoId(created.id), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), dupont.id);
  });

  testWidgets('préremplit la modification piano et conserve customerId', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
      location: 'Salon',
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    var historyLoads = 0;
    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        loadHistory: () async {
          historyLoads += 1;
          return const <HistoryEntry>[];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    final locationContainer = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    locationContainer.listen(
      historySnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pumpAndSettle();
    expect(historyLoads, 1);
    await tester.tap(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsEditCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(clientsEditPianoTitle),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, clientsPianoBrandLabel),
          )
          .controller
          ?.text,
      'Yamaha',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, clientsPianoLocationLabel),
          )
          .controller
          ?.text,
      'Salon',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, clientsPianoLocationLabel),
      'Cuisine',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('Salon'), findsNothing);
    final updated = await pianos.findById(yamaha.id);
    expect(updated!.location, 'Cuisine');
    expect(updated.customerId, dupont.id);
    expect(historyLoads, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    expect(container.read(selectedCustomerIdProvider), dupont.id);
  });

  testWidgets('demande confirmation puis archive le piano via PianoService', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsArchiveAction),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsArchivePianoTitle), findsOneWidget);
    expect(find.text(clientsArchivePianoBody), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, clientsCancel),
      ),
    );
    await tester.pumpAndSettle();
    expect((await pianos.findById(yamaha.id))!.isArchived, isFalse);

    await tester.tap(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsArchiveAction),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsArchivePianoConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Yamaha U1'), findsNothing);
    expect((await pianos.findById(yamaha.id))!.isArchived, isTrue);

    await tester.tap(find.text(clientsArchivedPianosSection));
    await tester.pumpAndSettle();
    expect(find.text('Yamaha U1'), findsOneWidget);
    expect(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsEditCustomer),
      ),
      findsNothing,
    );
  });

  testWidgets('restaure un piano via PianoService sans recréer de rappel', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
      archived: true,
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    await tester.pumpWidget(
      _clientsApp(customers: customers, pianos: pianos, reminders: reminders),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(clientsArchivedPianosSection));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsRestoreAction),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(clientsRestorePianoTitle), findsOneWidget);
    expect(find.text(clientsRestorePianoBody), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRestorePianoConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Yamaha U1'), findsOneWidget);
    expect(find.text(clientsArchivedPianosSection), findsNothing);
    expect((await pianos.findById(yamaha.id))!.isArchived, isFalse);
    expect(await reminders.findScheduledByPianoId(yamaha.id), isNull);
    expect(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsEditCustomer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('aucune mutation piano depuis un client archivé', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final martin = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Martin',
      firstName: 'Marie',
      archived: true,
    );
    await customers.insert(martin);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: martin.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );
    await pianos.insert(
      _piano(
        id: '22222222-2222-4222-8222-222222222222',
        customerId: martin.id,
        brand: 'Schimmel',
        model: '120',
        archived: true,
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text(clientsFilterArchived));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Martin'));
    await tester.pumpAndSettle();

    expect(find.text(clientsAddPiano), findsNothing);
    expect(_recordTuningOnCard('Yamaha U1'), findsNothing);
    expect(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsEditCustomer),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsArchiveAction),
      ),
      findsNothing,
    );
    await tester.tap(find.text(clientsArchivedPianosSection));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _pianoCard('Schimmel 120'),
        matching: find.text(clientsRestoreAction),
      ),
      findsNothing,
    );
  });

  testWidgets('désactiver les rappels exige une confirmation avant update', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    var historyLoads = 0;
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        loadHistory: () async {
          historyLoads += 1;
          return const <HistoryEntry>[];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    final disableContainer = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    disableContainer.listen(
      historySnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pumpAndSettle();
    expect(historyLoads, 1);
    await tester.tap(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsEditCustomer),
      ),
    );
    await tester.pumpAndSettle();

    final remindersSwitch = find.byType(Switch);
    await tester.ensureVisible(remindersSwitch);
    await tester.tap(remindersSwitch);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog).first,
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsDisablePianoRemindersTitle), findsOneWidget);
    expect(find.text(clientsDisablePianoRemindersBody), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(AlertDialog, clientsDisablePianoRemindersTitle),
        matching: find.widgetWithText(TextButton, clientsCancel),
      ),
    );
    await tester.pumpAndSettle();
    expect((await pianos.findById(yamaha.id))!.remindersEnabled, isTrue);
    expect(find.text(clientsEditPianoTitle), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, clientsDisablePianoRemindersConfirm),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect((await pianos.findById(yamaha.id))!.remindersEnabled, isFalse);
    expect(find.text(clientsRemindersDisabled), findsOneWidget);
    expect(historyLoads, 2);
  });

  testWidgets('réactiver les rappels n’ouvre pas de confirmation ni de rappel', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
      remindersEnabled: false,
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    var historyLoads = 0;
    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        reminders: reminders,
        loadHistory: () async {
          historyLoads += 1;
          return const <HistoryEntry>[];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    final enableContainer = ProviderScope.containerOf(
      tester.element(find.byType(ClientsPage)),
    );
    enableContainer.listen(
      historySnapshotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await tester.pumpAndSettle();
    expect(historyLoads, 1);
    await tester.tap(
      find.descendant(
        of: _pianoCard('Yamaha U1'),
        matching: find.text(clientsEditCustomer),
      ),
    );
    await tester.pumpAndSettle();

    final remindersSwitch = find.byType(Switch);
    await tester.ensureVisible(remindersSwitch);
    await tester.tap(remindersSwitch);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsDisablePianoRemindersTitle), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect((await pianos.findById(yamaha.id))!.remindersEnabled, isTrue);
    expect(await reminders.findScheduledByPianoId(yamaha.id), isNull);
    expect(historyLoads, 2);
  });

  testWidgets('présente une erreur de mutation piano sans détail technique', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );
    await tester.pumpWidget(
      _clientsApp(customers: customers, pianos: _FailingInsertPianoRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, clientsAddPiano));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsPianoBrandLabel),
      'Yamaha',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsSaveCustomer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsPianoMutationGenericError), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('le dialog piano n’overflow pas à 900×700', (tester) async {
    await _prepareDesktop(tester, size: const Size(900, 700));
    final customers = InMemoryCustomerRepository();
    await customers.insert(
      _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      ),
    );
    await tester.pumpWidget(_clientsApp(customers: customers));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, clientsAddPiano));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(clientsCreatePianoTitle), findsOneWidget);
  });

  testWidgets('affiche Enregistrer un accord sur un piano actif', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(_recordTuningOnCard('Yamaha U1'), findsOneWidget);
    expect(find.textContaining('Dernier accord'), findsNothing);
  });

  testWidgets('affiche Dernier accord JJ/MM/AAAA lorsqu’une date existe', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final tunings = InMemoryTuningRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);
    await tunings.insert(
      Tuning.create(
        id: TuningId('cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
        pianoId: yamaha.id,
        tuningDate: CalendarDate(2026, 3, 1),
        today: _today,
        now: _now,
      ),
    );

    await tester.pumpWidget(
      _clientsApp(customers: customers, pianos: pianos, tunings: tunings),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();

    expect(find.text(_lastTuningLabel(CalendarDate(2026, 3, 1))), findsOneWidget);
  });

  testWidgets('ouvre le dialog d’accord à la date du Clock', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );

    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();

    expect(_recordTuningDialogTitle(), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(formatFrenchNumericDate(_today)),
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, clientsRecordTuningNotesLabel),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
          OutlinedButton,
          formatFrenchNumericDate(_today),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, DateTime(_today.year, _today.month, _today.day));
  });

  testWidgets(
    'enregistre un accord via RecordTuning et affiche le dernier accord',
    (tester) async {
      await _prepareDesktop(tester);
      final customers = InMemoryCustomerRepository();
      final pianos = InMemoryPianoRepository();
      final reminders = InMemoryReminderRepository();
      final tunings = InMemoryTuningRepository();
      var dashboardLoads = 0;
      var historyLoads = 0;
      final dupont = _customer(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        lastName: 'Dupont',
        firstName: 'Jean',
      );
      final yamaha = _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      );
      await customers.insert(dupont);
      await pianos.insert(yamaha);

      await tester.pumpWidget(
        _clientsApp(
          customers: customers,
          pianos: pianos,
          reminders: reminders,
          tunings: tunings,
          loadDashboard: () async {
            dashboardLoads += 1;
            return _emptyDashboard;
          },
          loadHistory: () async {
            historyLoads += 1;
            return const <HistoryEntry>[];
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jean Dupont'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ClientsPage)),
      );
      container.listen(
        dashboardSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      container.listen(
        historySnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await tester.pumpAndSettle();
      expect(dashboardLoads, 1);
      expect(historyLoads, 1);
      final pianoValue = container.read(selectedCustomerPianosProvider).value;
      final searchValue = container.read(clientsSearchProvider).value;

      await tester.tap(_recordTuningOnCard('Yamaha U1'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, clientsRecordTuningSave),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(_lastTuningLabel(_today)), findsOneWidget);
      expect(container.read(selectedCustomerIdProvider), dupont.id);
      expect(tunings.all, hasLength(1));
      expect(tunings.all.single.pianoId, yamaha.id);
      expect(tunings.all.single.tuningDate, _today);
      expect(tunings.all.single.notes, isNull);
      final reminder = await reminders.findScheduledByPianoId(yamaha.id);
      expect(reminder, isNotNull);
      expect(reminder!.dueDate, _today.addMonths(12));
      expect(reminder.status, ReminderStatus.scheduled);
      expect(dashboardLoads, 2);
      expect(historyLoads, 2);
      expect(
        identical(
          container.read(selectedCustomerPianosProvider).value,
          pianoValue,
        ),
        isTrue,
      );
      expect(
        identical(container.read(clientsSearchProvider).value, searchValue),
        isTrue,
      );
    },
  );

  testWidgets('n’affiche pas de Reminder si les rappels sont désactivés', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final tunings = InMemoryTuningRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
      remindersEnabled: false,
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        reminders: reminders,
        tunings: tunings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, clientsRecordTuningNotesLabel),
      '  passage rapide  ',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRecordTuningSave),
      ),
    );
    await tester.pumpAndSettle();

    expect(tunings.all.single.notes, 'passage rapide');
    expect(await reminders.findScheduledByPianoId(yamaha.id), isNull);
    expect(find.text(_lastTuningLabel(_today)), findsOneWidget);
  });

  testWidgets('remplace le rappel scheduled existant via RecordTuning', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final reminders = InMemoryReminderRepository();
    final tunings = InMemoryTuningRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);
    final previous = Reminder.schedule(
      id: ReminderId('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
      pianoId: yamaha.id,
      originTuningId: TuningId('cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
      dueDate: CalendarDate(2026, 1, 1),
      now: _now,
    );
    await reminders.insert(previous);

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        reminders: reminders,
        tunings: tunings,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRecordTuningSave),
      ),
    );
    await tester.pumpAndSettle();

    final cancelled = await reminders.findById(previous.id);
    expect(cancelled!.status, ReminderStatus.cancelled);
    expect(
      cancelled.cancellationReason,
      ReminderCancellationReason.supersededByTuning,
    );
    final current = await reminders.findScheduledByPianoId(yamaha.id);
    expect(current, isNotNull);
    expect(current!.id, isNot(previous.id));
    expect(current.originTuningId, tunings.all.single.id);
  });

  testWidgets('désactive les actions pendant l’enregistrement d’un accord', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final innerTunings = InMemoryTuningRepository();
    final gate = Completer<void>();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    final yamaha = _piano(
      id: '11111111-1111-4111-8111-111111111111',
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
    );
    await customers.insert(dupont);
    await pianos.insert(yamaha);

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        tunings: innerTunings,
        recordTuning: RecordTuning(
          clock: FixedClock(_now),
          idGenerator: FakeIdGenerator(spareIds()),
          transactions: const ImmediateTransactionRunner(),
          tunings: _DelayedInsertTuningRepository(innerTunings, gate),
          pianos: pianos,
          reminders: InMemoryReminderRepository(),
          activities: InMemoryActivityRepository(pianos),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRecordTuningSave),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(
                FilledButton,
                clientsRecordTuningSave,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(TextButton, clientsCancel),
            ),
          )
          .onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(_lastTuningLabel(_today)), findsOneWidget);
  });

  testWidgets('présente une erreur RecordTuning sans détail technique', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        recordTuning: RecordTuning(
          clock: FixedClock(_now),
          idGenerator: FakeIdGenerator(spareIds()),
          transactions: const ImmediateTransactionRunner(),
          tunings: _FailingInsertTuningRepository(),
          pianos: pianos,
          reminders: InMemoryReminderRepository(),
          activities: InMemoryActivityRepository(pianos),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRecordTuningSave),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsRecordTuningGenericError), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('présente PianoNotFound sans détail technique', (tester) async {
    await _prepareDesktop(tester);
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );

    await tester.pumpWidget(
      _clientsApp(
        customers: customers,
        pianos: pianos,
        recordTuning: RecordTuning(
          clock: FixedClock(_now),
          idGenerator: FakeIdGenerator(spareIds()),
          transactions: const ImmediateTransactionRunner(),
          tunings: InMemoryTuningRepository(),
          pianos: InMemoryPianoRepository(),
          reminders: InMemoryReminderRepository(),
          activities: InMemoryActivityRepository(InMemoryPianoRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, clientsRecordTuningSave),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsPianoNotFound), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('le dialog d’accord n’overflow pas à 900×700', (tester) async {
    await _prepareDesktop(tester, size: const Size(900, 700));
    final customers = InMemoryCustomerRepository();
    final pianos = InMemoryPianoRepository();
    final dupont = _customer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      lastName: 'Dupont',
      firstName: 'Jean',
    );
    await customers.insert(dupont);
    await pianos.insert(
      _piano(
        id: '11111111-1111-4111-8111-111111111111',
        customerId: dupont.id,
        brand: 'Yamaha',
        model: 'U1',
      ),
    );
    await tester.pumpWidget(_clientsApp(customers: customers, pianos: pianos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jean Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(_recordTuningOnCard('Yamaha U1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_recordTuningDialogTitle(), findsOneWidget);
  });

  test('les dialogs clients passent par CustomerService', () {
    const files = [
      'lib/presentation/clients/customer_form_dialog.dart',
      'lib/presentation/clients/customer_confirm_dialog.dart',
      'lib/presentation/clients/clients_page.dart',
      'lib/presentation/clients/client_detail_pane.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('customerRepositoryProvider'), isFalse, reason: path);
      expect(source.contains('app_database'), isFalse, reason: path);
      expect(source.contains('DriftCustomerRepository'), isFalse, reason: path);
    }
    final form = File(
      'lib/presentation/clients/customer_form_dialog.dart',
    ).readAsStringSync();
    final confirm = File(
      'lib/presentation/clients/customer_confirm_dialog.dart',
    ).readAsStringSync();
    expect(form.contains('customerServiceProvider'), isTrue);
    expect(confirm.contains('customerServiceProvider'), isTrue);

    const pianoFiles = [
      'lib/presentation/clients/piano_form_dialog.dart',
      'lib/presentation/clients/piano_confirm_dialog.dart',
      'lib/presentation/clients/client_detail_pane.dart',
      'lib/presentation/clients/piano_summary_card.dart',
    ];
    for (final path in pianoFiles) {
      final source = File(path).readAsStringSync();
      expect(source.contains('pianoRepositoryProvider'), isFalse, reason: path);
      expect(source.contains('recordTuningProvider'), isFalse, reason: path);
      expect(source.contains('app_database'), isFalse, reason: path);
    }
    final pianoForm = File(
      'lib/presentation/clients/piano_form_dialog.dart',
    ).readAsStringSync();
    final pianoConfirm = File(
      'lib/presentation/clients/piano_confirm_dialog.dart',
    ).readAsStringSync();
    expect(pianoForm.contains('pianoServiceProvider'), isTrue);
    expect(pianoConfirm.contains('pianoServiceProvider'), isTrue);

    final recordDialog = File(
      'lib/presentation/clients/record_tuning_dialog.dart',
    ).readAsStringSync();
    expect(recordDialog.contains('recordTuningProvider'), isTrue);
    expect(recordDialog.contains('tuningRepositoryProvider'), isFalse);
    expect(recordDialog.contains('reminderRepositoryProvider'), isFalse);
    expect(recordDialog.contains('activityRepositoryProvider'), isFalse);
    expect(recordDialog.contains('app_database'), isFalse);
    expect(recordDialog.contains('dueDate'), isFalse);
    expect(recordDialog.contains('DateTime.now()'), isFalse);

    final detail = File(
      'lib/presentation/clients/client_detail_pane.dart',
    ).readAsStringSync();
    expect(detail.contains('selectedCustomerLatestTuningDatesProvider'), isTrue);
    expect(detail.contains('dashboardSnapshotProvider'), isTrue);
    expect(detail.contains('historySnapshotProvider'), isTrue);
    expect(detail.contains('tuningRepositoryProvider'), isFalse);

    final clientsPage = File(
      'lib/presentation/clients/clients_page.dart',
    ).readAsStringSync();
    expect(clientsPage.contains('historySnapshotProvider'), isTrue);
  });
}

final class _CountingPianoRepository implements PianoRepository {
  _CountingPianoRepository(this._inner);

  final PianoRepository _inner;
  var findByCustomerCalls = 0;

  @override
  Future<Piano?> findById(PianoId id) => _inner.findById(id);

  @override
  Future<void> insert(Piano piano) => _inner.insert(piano);

  @override
  Future<void> update(Piano piano) => _inner.update(piano);

  @override
  Future<List<Piano>> findByCustomerId({
    required CustomerId customerId,
    required PianoStatusFilter filter,
  }) {
    findByCustomerCalls += 1;
    return _inner.findByCustomerId(customerId: customerId, filter: filter);
  }
}

final class _DelayedInsertCustomerRepository implements CustomerRepository {
  _DelayedInsertCustomerRepository(this._inner, this._insertGate);

  final InMemoryCustomerRepository _inner;
  final Completer<void> _insertGate;

  @override
  Future<Customer?> findById(CustomerId id) => _inner.findById(id);

  @override
  Future<void> insert(Customer customer) async {
    await _insertGate.future;
    await _inner.insert(customer);
  }

  @override
  Future<void> update(Customer customer) => _inner.update(customer);

  @override
  Future<List<Customer>> search({
    required CustomerStatusFilter filter,
    String query = '',
  }) {
    return _inner.search(filter: filter, query: query);
  }
}

final class _FailingInsertCustomerRepository implements CustomerRepository {
  @override
  Future<Customer?> findById(CustomerId id) async => null;

  @override
  Future<void> insert(Customer customer) async {
    throw Exception('SQLite constraint failed');
  }

  @override
  Future<void> update(Customer customer) async {}

  @override
  Future<List<Customer>> search({
    required CustomerStatusFilter filter,
    String query = '',
  }) async {
    return const [];
  }
}

final class _FailingInsertPianoRepository implements PianoRepository {
  @override
  Future<Piano?> findById(PianoId id) async => null;

  @override
  Future<void> insert(Piano piano) async {
    throw Exception('SQLite constraint failed');
  }

  @override
  Future<void> update(Piano piano) async {}

  @override
  Future<List<Piano>> findByCustomerId({
    required CustomerId customerId,
    required PianoStatusFilter filter,
  }) async {
    return const [];
  }
}

final class _DelayedInsertTuningRepository implements TuningRepository {
  _DelayedInsertTuningRepository(this._inner, this._insertGate);

  final InMemoryTuningRepository _inner;
  final Completer<void> _insertGate;

  @override
  Future<Tuning?> findById(TuningId id) => _inner.findById(id);

  @override
  Future<void> insert(Tuning tuning) async {
    await _insertGate.future;
    await _inner.insert(tuning);
  }

  @override
  Future<void> update(Tuning tuning) => _inner.update(tuning);

  @override
  Future<List<Tuning>> findByPianoId(PianoId pianoId) {
    return _inner.findByPianoId(pianoId);
  }
}

final class _FailingInsertTuningRepository implements TuningRepository {
  @override
  Future<Tuning?> findById(TuningId id) async => null;

  @override
  Future<void> insert(Tuning tuning) async {
    throw Exception('SQLite constraint failed');
  }

  @override
  Future<void> update(Tuning tuning) async {}

  @override
  Future<List<Tuning>> findByPianoId(PianoId pianoId) async => const [];
}
