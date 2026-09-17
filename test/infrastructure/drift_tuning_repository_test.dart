import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_tuning_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftCustomerRepository customers;
  late DriftPianoRepository pianos;
  late DriftTuningRepository tunings;
  final now = DateTime.utc(2026, 9, 17, 10);
  final today = CalendarDate(2026, 9, 17);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Piano> insertPiano() async {
    final customer = Customer.create(
      id: CustomerId('11111111-1111-4111-8111-111111111111'),
      lastName: 'Dupont',
      now: now,
    );
    await customers.insert(customer);
    final piano = Piano.create(
      id: PianoId('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
      customerId: customer.id,
      brand: 'Yamaha',
      now: now,
    );
    await pianos.insert(piano);
    return piano;
  }

  Tuning newTuning({
    required PianoId pianoId,
    String id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    CalendarDate? tuningDate,
    String? notes,
  }) {
    return Tuning.create(
      id: TuningId(id),
      pianoId: pianoId,
      tuningDate: tuningDate ?? today,
      today: today,
      notes: notes,
      now: now,
    );
  }

  test('insert, findById et update', () async {
    final piano = await insertPiano();
    final created = newTuning(pianoId: piano.id);
    await tunings.insert(created);

    final loaded = await tunings.findById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.tuningDate, today);
    expect(loaded.pianoId, piano.id);
    expect(loaded.createdAt, now);

    final corrected = created.changeDetails(
      tuningDate: CalendarDate(2026, 9, 16),
      today: today,
      notes: 'très désaccordé',
      now: now.add(const Duration(days: 1)),
    );
    await tunings.update(corrected);

    final updated = await tunings.findById(created.id);
    expect(updated!.tuningDate, CalendarDate(2026, 9, 16));
    expect(updated.notes, 'très désaccordé');
    expect(updated.pianoId, piano.id);
  });

  test('FK empêche un accord orphelin', () async {
    final orphan = newTuning(
      pianoId: PianoId('99999999-9999-4999-8999-999999999999'),
    );

    await expectLater(tunings.insert(orphan), throwsA(isA<SqliteException>()));
  });

  test('FK RESTRICT empêche de supprimer un piano qui a un accord', () async {
    final piano = await insertPiano();
    await tunings.insert(newTuning(pianoId: piano.id));

    await expectLater(
      database.customStatement(
        "DELETE FROM pianos WHERE id = '${piano.id.value}'",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('accepte deux accords le même jour', () async {
    final piano = await insertPiano();
    await tunings.insert(newTuning(pianoId: piano.id));
    await tunings.insert(
      newTuning(
        pianoId: piano.id,
        id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        notes: 'second passage',
      ),
    );

    final listed = await tunings.findByPianoId(piano.id);
    expect(listed, hasLength(2));
  });

  test('findByPianoId trie tuningDate DESC', () async {
    final piano = await insertPiano();
    final oldest = newTuning(
      pianoId: piano.id,
      id: '11111111-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      tuningDate: CalendarDate(2025, 1, 1),
    );
    final middle = newTuning(
      pianoId: piano.id,
      id: '22222222-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      tuningDate: CalendarDate(2026, 3, 1),
    );
    final newest = newTuning(
      pianoId: piano.id,
      id: '33333333-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      tuningDate: CalendarDate(2026, 9, 17),
    );
    await tunings.insert(oldest);
    await tunings.insert(newest);
    await tunings.insert(middle);

    final listed = await tunings.findByPianoId(piano.id);
    expect(listed.map((item) => item.id), [newest.id, middle.id, oldest.id]);
  });

  test('round-trip 2026-09-17 sans dérive timezone', () async {
    final piano = await insertPiano();
    await tunings.insert(
      newTuning(pianoId: piano.id, tuningDate: CalendarDate(2026, 9, 17)),
    );

    final stored = await database
        .customSelect('SELECT tuning_date FROM tunings')
        .getSingle();
    expect(stored.read<String>('tuning_date'), '2026-09-17');

    final loaded = await tunings.findByPianoId(piano.id);
    expect(loaded.single.tuningDate, CalendarDate(2026, 9, 17));
    expect(loaded.single.tuningDate.toIso8601String(), '2026-09-17');
  });
}
