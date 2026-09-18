import 'package:accord_memo/application/tuning/latest_piano_tuning_query.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';

import 'in_memory_tuning_repository.dart';

final class InMemoryLatestPianoTuningQuery implements LatestPianoTuningQuery {
  InMemoryLatestPianoTuningQuery({
    required this._pianos,
    required this._tunings,
  });

  final PianoRepository _pianos;
  final InMemoryTuningRepository _tunings;

  @override
  Future<Map<PianoId, CalendarDate>> findLatestDatesByCustomerId(
    CustomerId customerId,
  ) async {
    final bestByPiano = <PianoId, Tuning>{};
    for (final tuning in _tunings.all) {
      final current = bestByPiano[tuning.pianoId];
      if (current == null || _isNewer(tuning, current)) {
        bestByPiano[tuning.pianoId] = tuning;
      }
    }

    final latest = <PianoId, CalendarDate>{};
    for (final entry in bestByPiano.entries) {
      final piano = await _pianos.findById(entry.key);
      if (piano == null || piano.customerId != customerId) {
        continue;
      }
      latest[entry.key] = entry.value.tuningDate;
    }
    return latest;
  }

  bool _isNewer(Tuning candidate, Tuning current) {
    final byDate = candidate.tuningDate.compareTo(current.tuningDate);
    if (byDate != 0) {
      return byDate > 0;
    }
    final byCreated = candidate.createdAt.compareTo(current.createdAt);
    if (byCreated != 0) {
      return byCreated > 0;
    }
    return candidate.id.value.compareTo(current.id.value) > 0;
  }
}
