import 'package:accord_memo/application/tuning/tuning_service.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_tuning_repository.dart';

void main() {
  late InMemoryTuningRepository tunings;
  late TuningService tuningService;
  final now = DateTime.utc(2026, 9, 17, 10);
  final pianoId = PianoId('piano-1');
  final today = CalendarDate(2026, 9, 17);

  setUp(() {
    tunings = InMemoryTuningRepository();
    tuningService = TuningService(tunings: tunings);
  });

  test('lit un accord par id et par piano', () async {
    final older = Tuning.create(
      id: TuningId('tuning-1'),
      pianoId: pianoId,
      tuningDate: CalendarDate(2025, 1, 1),
      today: today,
      now: now,
    );
    final newer = Tuning.create(
      id: TuningId('tuning-2'),
      pianoId: pianoId,
      tuningDate: CalendarDate(2026, 3, 1),
      today: today,
      now: now,
    );
    await tunings.insert(older);
    await tunings.insert(newer);

    expect(await tuningService.getById(older.id), older);
    final listed = await tuningService.findByPiano(pianoId);
    expect(listed.map((item) => item.id), [newer.id, older.id]);
  });
}
