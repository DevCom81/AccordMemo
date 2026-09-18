import 'dart:async';

import 'package:accord_memo/application/customer/customer_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
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
  String? city,
  String? email,
  String? phone,
  bool archived = false,
}) {
  var customer = Customer.create(
    id: CustomerId(id),
    lastName: lastName,
    firstName: firstName,
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

CustomerService _service(InMemoryCustomerRepository customers) {
  final pianos = InMemoryPianoRepository();
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

Widget _clientsApp({
  required InMemoryCustomerRepository customers,
}) {
  return ProviderScope(
    overrides: [
      customerServiceProvider.overrideWith((ref) => _service(customers)),
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
}
