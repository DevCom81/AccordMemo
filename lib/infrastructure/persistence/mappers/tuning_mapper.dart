import 'package:drift/drift.dart';

import '../../../domain/piano/piano.dart';
import '../../../domain/shared/calendar_date.dart';
import '../../../domain/tuning/tuning.dart';
import '../app_database.dart';

final class TuningMapper {
  const TuningMapper();

  Tuning toDomain(TuningRecord row) {
    return Tuning.reconstitute(
      id: TuningId(row.id),
      pianoId: PianoId(row.pianoId),
      tuningDate: CalendarDate.parseIso(row.tuningDate),
      notes: row.notes,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  TuningsCompanion toCompanion(Tuning tuning) {
    return TuningsCompanion(
      id: Value(tuning.id.value),
      pianoId: Value(tuning.pianoId.value),
      tuningDate: Value(tuning.tuningDate.toIso8601String()),
      notes: Value(tuning.notes),
      createdAt: Value(tuning.createdAt.toUtc()),
      updatedAt: Value(tuning.updatedAt.toUtc()),
    );
  }
}
