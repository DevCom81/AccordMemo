import '../../domain/activity/activity.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/shared/calendar_date.dart';
import 'history_kind.dart';

/// Projection historique. Ce n'est pas une entité du domaine.
final class HistoryEntry {
  const HistoryEntry({
    required this.activityId,
    required this.occurredAt,
    required this.kind,
    required this.customerLastName,
    this.customerFirstName,
    required this.customerArchived,
    this.pianoBrand,
    this.pianoModel,
    this.pianoType,
    required this.pianoArchived,
    this.previousDate,
    this.newDate,
    this.tuningDate,
    this.reminderDueDate,
  });

  final ActivityId activityId;
  final DateTime occurredAt;
  final HistoryKind kind;
  final String customerLastName;
  final String? customerFirstName;
  final bool customerArchived;
  final String? pianoBrand;
  final String? pianoModel;
  final PianoType? pianoType;
  final bool pianoArchived;
  final CalendarDate? previousDate;
  final CalendarDate? newDate;
  final CalendarDate? tuningDate;
  final CalendarDate? reminderDueDate;
}
