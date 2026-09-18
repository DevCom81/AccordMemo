import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/record_tuning_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mappe les erreurs RecordTuning sans détail technique', () {
    expect(
      recordTuningMessage(
        TuningDateInFuture(
          tuningDate: CalendarDate(2099, 1, 1),
          today: CalendarDate(2026, 9, 17),
        ),
      ),
      clientsTuningDateInFuture,
    );
    expect(
      recordTuningMessage(PianoNotFound(PianoId('p1'))),
      clientsPianoNotFound,
    );
    expect(
      recordTuningMessage(Exception('SQLite constraint failed')),
      clientsRecordTuningGenericError,
    );
  });
}
