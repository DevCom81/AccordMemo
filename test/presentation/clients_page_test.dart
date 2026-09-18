import 'dart:async';

import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/application/piano/piano_service.dart';
import 'package:accord_memo/domain/customer/civility.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/domain/piano/piano_type.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/clients/clients_page.dart';
import 'package:accord_memo/presentation/clients/clients_providers.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/immediate_transaction_runner.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_customer_repository.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';

final _now = DateTime.utc(2026, 9, 17, 10);

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
  InMemoryCustomerRepository customers,
  PianoRepository pianos,
) {
  return CustomerService(
    clock: FixedClock(_now),
    idGenerator: FakeIdGenerator(spareIds()),
    transactions: const ImmediateTransactionRunner(),
    repository: customers,
    pianos: pianos,
    reminders: InMemoryReminderRepository(),
    activities: InMemoryActivityRepository(pianos),
  );
}

PianoService _pianoService(
  InMemoryCustomerRepository customers,
  PianoRepository pianos,
) {
  return PianoService(
    clock: FixedClock(_now),
    idGenerator: FakeIdGenerator(spareIds()),
    transactions: const ImmediateTransactionRunner(),
    pianos: pianos,
    customers: customers,
    reminders: InMemoryReminderRepository(),
    activities: InMemoryActivityRepository(pianos),
  );
}

Widget _clientsApp({
  required InMemoryCustomerRepository customers,
  PianoRepository? pianos,
}) {
  final pianoRepo = pianos ?? InMemoryPianoRepository();
  return ProviderScope(
    overrides: [
      customerServiceProvider.overrideWith(
        (ref) => _customerService(customers, pianoRepo),
      ),
      pianoServiceProvider.overrideWith(
        (ref) => _pianoService(customers, pianoRepo),
      ),
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

  testWidgets('permet de consulter un client archivé sans action Restaurer', (
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
    expect(find.text('Restaurer'), findsNothing);
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
    expect(find.text('Restaurer'), findsNothing);
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
