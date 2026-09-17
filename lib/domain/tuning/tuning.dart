import '../piano/piano.dart';
import '../shared/calendar_date.dart';

final class TuningId {
  const TuningId._(this.value);

  factory TuningId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const TuningIdInvalid();
    }
    return TuningId._(value);
  }

  final String value;

  @override
  bool operator ==(Object other) => other is TuningId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

sealed class TuningException implements Exception {
  const TuningException();
}

final class TuningIdInvalid extends TuningException {
  const TuningIdInvalid();

  @override
  String toString() => 'TuningIdInvalid';
}

final class TuningDateInFuture extends TuningException {
  const TuningDateInFuture({required this.tuningDate, required this.today});

  final CalendarDate tuningDate;
  final CalendarDate today;

  @override
  String toString() => 'TuningDateInFuture($tuningDate, today: $today)';
}

final class TuningNotFound extends TuningException {
  const TuningNotFound(this.id);

  final TuningId id;

  @override
  String toString() => 'TuningNotFound($id)';
}

final class Tuning {
  const Tuning._({
    required this.id,
    required this.pianoId,
    required this.tuningDate,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tuning.create({
    required TuningId id,
    required PianoId pianoId,
    required CalendarDate tuningDate,
    required CalendarDate today,
    String? notes,
    required DateTime now,
  }) {
    _assertNotInFuture(tuningDate, today);

    return Tuning._(
      id: id,
      pianoId: pianoId,
      tuningDate: tuningDate,
      notes: _optionalText(notes),
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  }

  /// Hydratation depuis la persistance. Ne pas utiliser pour modifier un accord.
  factory Tuning.reconstitute({
    required TuningId id,
    required PianoId pianoId,
    required CalendarDate tuningDate,
    String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Tuning._(
      id: id,
      pianoId: pianoId,
      tuningDate: tuningDate,
      notes: _optionalText(notes),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  final TuningId id;
  final PianoId pianoId;
  final CalendarDate tuningDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tuning changeDetails({
    required CalendarDate tuningDate,
    required CalendarDate today,
    String? notes,
    required DateTime now,
  }) {
    _assertNotInFuture(tuningDate, today);

    return Tuning._(
      id: id,
      pianoId: pianoId,
      tuningDate: tuningDate,
      notes: _optionalText(notes),
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) => other is Tuning && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void _assertNotInFuture(CalendarDate tuningDate, CalendarDate today) {
  if (tuningDate > today) {
    throw TuningDateInFuture(tuningDate: tuningDate, today: today);
  }
}

String? _optionalText(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
