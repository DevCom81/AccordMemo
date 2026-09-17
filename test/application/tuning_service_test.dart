import 'package:accord_memo/application/tuning/tuning_service.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_tuning_repository.dart';

void main() {
  late InMemoryPianoRepository pianos;
  late InMemoryTuningRepository tunings;
  late TuningService tuningService;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    pianos = InMemoryPianoRepository();
    tunings = InMemoryTuningRepository();
    tuningService = TuningService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator([
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      ]),
      tunings: tunings,
      pianos: pianos,
    );
  });

  Future<Piano> insertPiano({bool archived = false}) async {
    var piano = Piano.create(
      id: PianoId('piano-1'),
      customerId: CustomerId('customer-1'),
      brand: 'Yamaha',
      now: now,
    );
    if (archived) {
      piano = piano.archive(now);
    }
    await pianos.insert(piano);
    return piano;
  }

  CalendarDate todayFromClock() {
    final local = now.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  test('génère un id et utilise FixedClock', () async {
    final piano = await insertPiano();
    final today = todayFromClock();

    final tuning = await tuningService.create(
      pianoId: piano.id,
      tuningDate: today,
    );

    expect(tuning.id.value, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
    expect(tuning.createdAt, now);
    expect(tuning.updatedAt, now);
    expect(tuning.tuningDate, today);
  });

  test('refuse un piano inexistant', () async {
    await expectLater(
      tuningService.create(
        pianoId: PianoId('missing'),
        tuningDate: todayFromClock(),
      ),
      throwsA(isA<PianoNotFound>()),
    );
  });

  test('accepte un piano actif', () async {
    final piano = await insertPiano();

    final tuning = await tuningService.create(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 1, 5),
    );

    expect(tuning.pianoId, piano.id);
    final loaded = await tuningService.getById(tuning.id);
    expect(loaded, isNotNull);
    expect(loaded!.tuningDate, CalendarDate(2026, 1, 5));
  });

  test('accepte un piano archivé', () async {
    final piano = await insertPiano(archived: true);
    expect(piano.isArchived, isTrue);

    final tuning = await tuningService.create(
      pianoId: piano.id,
      tuningDate: CalendarDate(2025, 6, 1),
      notes: 'saisie rétroactive',
    );

    expect(tuning.pianoId, piano.id);
    expect(tuning.notes, 'saisie rétroactive');
  });

  test('create, update et findByPiano', () async {
    final piano = await insertPiano();
    final older = await tuningService.create(
      pianoId: piano.id,
      tuningDate: CalendarDate(2025, 1, 1),
    );
    final newer = await tuningService.create(
      pianoId: piano.id,
      tuningDate: CalendarDate(2026, 3, 1),
    );

    final corrected = await tuningService.update(
      id: older.id,
      tuningDate: CalendarDate(2024, 12, 15),
      notes: 'date corrigée',
    );
    expect(corrected.pianoId, piano.id);
    expect(corrected.tuningDate, CalendarDate(2024, 12, 15));
    expect(corrected.notes, 'date corrigée');

    final listed = await tuningService.findByPiano(piano.id);
    expect(listed.map((item) => item.id), [newer.id, older.id]);
  });

  test('refuse la correction d’un accord inexistant', () async {
    await expectLater(
      tuningService.update(
        id: TuningId('missing'),
        tuningDate: CalendarDate(2026, 1, 1),
      ),
      throwsA(isA<TuningNotFound>()),
    );
  });

  test('refuse une date future dérivée du Clock applicatif', () async {
    final piano = await insertPiano();

    await expectLater(
      tuningService.create(
        pianoId: piano.id,
        tuningDate: CalendarDate(2099, 1, 1),
      ),
      throwsA(isA<TuningDateInFuture>()),
    );
  });
}
