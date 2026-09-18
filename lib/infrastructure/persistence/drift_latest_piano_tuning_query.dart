import 'package:drift/drift.dart';

import '../../application/tuning/latest_piano_tuning_query.dart';
import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/shared/calendar_date.dart';
import 'app_database.dart';

final class DriftLatestPianoTuningQuery implements LatestPianoTuningQuery {
  DriftLatestPianoTuningQuery(this._database);

  final AppDatabase _database;

  @override
  Future<Map<PianoId, CalendarDate>> findLatestDatesByCustomerId(
    CustomerId customerId,
  ) async {
    final rows = await _database
        .customSelect(
          '''
SELECT t.piano_id, t.tuning_date
FROM tunings t
INNER JOIN pianos p ON p.id = t.piano_id
WHERE p.customer_id = ?
  AND t.id = (
    SELECT t2.id
    FROM tunings t2
    WHERE t2.piano_id = t.piano_id
    ORDER BY t2.tuning_date DESC, t2.created_at DESC, t2.id DESC
    LIMIT 1
  )
''',
          variables: [Variable<String>(customerId.value)],
          readsFrom: {_database.tunings, _database.pianos},
        )
        .get();

    final latest = <PianoId, CalendarDate>{};
    for (final row in rows) {
      latest[PianoId(row.read<String>('piano_id'))] = CalendarDate.parseIso(
        row.read<String>('tuning_date'),
      );
    }
    return latest;
  }
}
