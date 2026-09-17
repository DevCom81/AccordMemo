import 'package:drift/drift.dart';

import '../../domain/piano/piano.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../../domain/reminder/reminder_status.dart';
import '../../domain/tuning/tuning.dart';
import 'app_database.dart';
import 'mappers/reminder_mapper.dart';

final class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(
    this._database, {
    this._mapper = const ReminderMapper(),
  });

  final AppDatabase _database;
  final ReminderMapper _mapper;

  @override
  Future<Reminder?> findById(ReminderId id) async {
    final row = await (_database.select(
      _database.reminders,
    )..where((t) => t.id.equals(id.value))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.toDomain(row);
  }

  @override
  Future<void> insert(Reminder reminder) {
    return _database
        .into(_database.reminders)
        .insert(_mapper.toCompanion(reminder));
  }

  @override
  Future<void> update(Reminder reminder) async {
    final written = await (_database.update(_database.reminders)
          ..where((t) => t.id.equals(reminder.id.value)))
        .write(_mapper.toCompanion(reminder));
    if (written == 0) {
      throw ReminderNotFound(reminder.id);
    }
  }

  @override
  Future<Reminder?> findScheduledByPianoId(PianoId pianoId) async {
    final row = await (_database.select(_database.reminders)
          ..where(
            (t) =>
                t.pianoId.equals(pianoId.value) &
                t.status.equals(ReminderStatus.scheduled.name),
          ))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.toDomain(row);
  }

  @override
  Future<Reminder?> findByOriginTuningId(TuningId originTuningId) async {
    final row = await (_database.select(_database.reminders)
          ..where((t) => t.originTuningId.equals(originTuningId.value)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapper.toDomain(row);
  }
}
