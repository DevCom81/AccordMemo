import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/correct_tuning_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mappe les erreurs CorrectTuning sans détail technique', () {
    expect(
      correctTuningMessage(
        TuningDateInFuture(
          tuningDate: CalendarDate(2099, 1, 1),
          today: CalendarDate(2026, 9, 17),
        ),
      ),
      clientsTuningDateInFuture,
    );
    expect(
      correctTuningMessage(TuningNotFound(TuningId('t1'))),
      clientsTuningNotFound,
    );
    expect(
      correctTuningMessage(PianoNotFound(PianoId('p1'))),
      clientsPianoNotFound,
    );
    expect(
      correctTuningMessage(Exception('SQLite constraint failed')),
      clientsCorrectTuningGenericError,
    );
  });
}
