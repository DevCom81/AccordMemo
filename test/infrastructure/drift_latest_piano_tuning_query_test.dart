import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_latest_piano_tuning_query.dart';
import 'package:accord_memo/infrastructure/persistence/drift_piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_tuning_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCustomerRepository customers;
  late DriftPianoRepository pianos;
  late DriftTuningRepository tunings;
  late DriftLatestPianoTuningQuery query;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
    query = DriftLatestPianoTuningQuery(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Customer> insertCustomer({
    required String id,
    String lastName = 'Dupont',
  }) async {
    final customer = Customer.create(
      id: CustomerId(id),
      lastName: lastName,
      now: now,
    );
    await customers.insert(customer);
    return customer;
  }

  Future<Piano> insertPiano({
    required CustomerId customerId,
    required String id,
  }) async {
    final piano = Piano.create(
      id: PianoId(id),
      customerId: customerId,
      brand: 'Yamaha',
      now: now,
    );
    await pianos.insert(piano);
    return piano;
  }

  Future<Tuning> insertTuning({
    required PianoId pianoId,
    required String id,
    required CalendarDate tuningDate,
    DateTime? createdAt,
  }) async {
    final instant = createdAt ?? now;
    final tuning = Tuning.reconstitute(
      id: TuningId(id),
      pianoId: pianoId,
      tuningDate: tuningDate,
      createdAt: instant,
      updatedAt: instant,
    );
    await tunings.insert(tuning);
    return tuning;
  }

  test('customer sans piano → map vide', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );

    expect(await query.findLatestDatesByCustomerId(customer.id), isEmpty);
  });

  test('piano sans accord absent de la map', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final piano = await insertPiano(
      customerId: customer.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );

    final latest = await query.findLatestDatesByCustomerId(customer.id);
    expect(latest.containsKey(piano.id), isFalse);
    expect(latest, isEmpty);
  });

  test('retourne le dernier accord du piano', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final piano = await insertPiano(
      customerId: customer.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    await insertTuning(
      pianoId: piano.id,
      id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      tuningDate: CalendarDate(2026, 3, 1),
    );

    expect(await query.findLatestDatesByCustomerId(customer.id), {
      piano.id: CalendarDate(2026, 3, 1),
    });
  });

  test('plusieurs accords → date civile la plus récente', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final piano = await insertPiano(
      customerId: customer.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    await insertTuning(
      pianoId: piano.id,
      id: '11111111-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      tuningDate: CalendarDate(2025, 1, 1),
      createdAt: DateTime.utc(2026, 9, 17, 12),
    );
    await insertTuning(
      pianoId: piano.id,
      id: '22222222-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      tuningDate: CalendarDate(2026, 8, 1),
      createdAt: DateTime.utc(2026, 1, 1),
    );

    expect(await query.findLatestDatesByCustomerId(customer.id), {
      piano.id: CalendarDate(2026, 8, 1),
    });
  });

  test('même tuningDate → created_at puis id DESC', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final piano = await insertPiano(
      customerId: customer.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    final sameDay = CalendarDate(2026, 3, 1);
    await insertTuning(
      pianoId: piano.id,
      id: 'zzzzzzzz-zzzz-4zzz-8zzz-zzzzzzzzzzzz',
      tuningDate: sameDay,
      createdAt: DateTime.utc(2026, 3, 1, 8),
    );
    await insertTuning(
      pianoId: piano.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
      tuningDate: sameDay,
      createdAt: DateTime.utc(2026, 3, 1, 10),
    );

    expect(await query.findLatestDatesByCustomerId(customer.id), {
      piano.id: sameDay,
    });

    final rows = await database
        .customSelect(
          '''
SELECT t.id
FROM tunings t
WHERE t.piano_id = ?
  AND t.id = (
    SELECT t2.id
    FROM tunings t2
    WHERE t2.piano_id = t.piano_id
    ORDER BY t2.tuning_date DESC, t2.created_at DESC, t2.id DESC
    LIMIT 1
  )
''',
          variables: [
            Variable<String>(piano.id.value),
          ],
        )
        .get();
    expect(rows.single.read<String>('id'), 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01');
  });

  test('même tuningDate et created_at → id DESC', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final piano = await insertPiano(
      customerId: customer.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    final sameDay = CalendarDate(2026, 3, 1);
    final createdAt = DateTime.utc(2026, 3, 1, 10);
    await insertTuning(
      pianoId: piano.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaa01',
      tuningDate: sameDay,
      createdAt: createdAt,
    );
    await insertTuning(
      pianoId: piano.id,
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01',
      tuningDate: sameDay,
      createdAt: createdAt,
    );

    final rows = await database
        .customSelect(
          '''
SELECT t.id
FROM tunings t
WHERE t.piano_id = ?
  AND t.id = (
    SELECT t2.id
    FROM tunings t2
    WHERE t2.piano_id = t.piano_id
    ORDER BY t2.tuning_date DESC, t2.created_at DESC, t2.id DESC
    LIMIT 1
  )
''',
          variables: [
            Variable<String>(piano.id.value),
          ],
        )
        .get();
    expect(rows.single.read<String>('id'), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbb01');
    expect(await query.findLatestDatesByCustomerId(customer.id), {
      piano.id: sameDay,
    });
  });

  test('aucun piano d’un autre Customer', () async {
    final dupont = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final martin = await insertCustomer(
      id: '22222222-2222-4222-8222-222222222222',
      lastName: 'Martin',
    );
    final yamaha = await insertPiano(
      customerId: dupont.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    final kawai = await insertPiano(
      customerId: martin.id,
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    await insertTuning(
      pianoId: yamaha.id,
      id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      tuningDate: CalendarDate(2026, 1, 1),
    );
    await insertTuning(
      pianoId: kawai.id,
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      tuningDate: CalendarDate(2026, 8, 1),
    );

    expect(await query.findLatestDatesByCustomerId(dupont.id), {
      yamaha.id: CalendarDate(2026, 1, 1),
    });
    expect(await query.findLatestDatesByCustomerId(martin.id), {
      kawai.id: CalendarDate(2026, 8, 1),
    });
  });

  test('aucune dérive timezone : ISO civil inchangé', () async {
    final customer = await insertCustomer(
      id: '11111111-1111-4111-8111-111111111111',
    );
    final piano = await insertPiano(
      customerId: customer.id,
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    await insertTuning(
      pianoId: piano.id,
      id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      tuningDate: CalendarDate(2026, 9, 17),
    );

    final stored = await database
        .customSelect('SELECT tuning_date FROM tunings')
        .getSingle();
    expect(stored.read<String>('tuning_date'), '2026-09-17');

    final latest = await query.findLatestDatesByCustomerId(customer.id);
    expect(latest[piano.id], CalendarDate(2026, 9, 17));
    expect(latest[piano.id]!.toIso8601String(), '2026-09-17');
  });
}
