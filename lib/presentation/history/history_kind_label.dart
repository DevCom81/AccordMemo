import '../../application/history/history_kind.dart';
import 'history_strings.dart';

String historyKindLabel(HistoryKind kind) {
  return switch (kind) {
    HistoryKind.tuningCreated => historyKindTuningCreated,
    HistoryKind.tuningUpdated => historyKindTuningUpdated,
    HistoryKind.reminderRescheduled => historyKindReminderRescheduled,
    HistoryKind.reminderSent => historyKindReminderSent,
    HistoryKind.reminderDisabled => historyKindReminderDisabled,
    HistoryKind.reminderReenabled => historyKindReminderReenabled,
  };
}
