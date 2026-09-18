import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/application/history/history_kind.dart';
import 'package:accord_memo/application/history/history_query.dart';
import 'package:accord_memo/domain/activity/activity_repository.dart';

final class InMemoryHistoryQuery implements HistoryQuery {
  InMemoryHistoryQuery([List<HistoryEntry>? items]) : items = items ?? [];

  final List<HistoryEntry> items;

  @override
  Future<List<HistoryEntry>> findRecent({
    required int limit,
    required HistoryKindFilter filter,
  }) async {
    requirePositiveActivityLimit(limit);
    final matches = items.where((item) {
      return switch (filter) {
        HistoryKindFilter.all => true,
        HistoryKindFilter.tunings =>
          item.kind == HistoryKind.tuningCreated ||
          item.kind == HistoryKind.tuningUpdated,
        HistoryKindFilter.reminders =>
          item.kind == HistoryKind.reminderRescheduled ||
          item.kind == HistoryKind.reminderSent ||
          item.kind == HistoryKind.reminderDisabled ||
          item.kind == HistoryKind.reminderReenabled,
      };
    }).toList();
    matches.sort((a, b) {
      final byTime = b.occurredAt.compareTo(a.occurredAt);
      if (byTime != 0) {
        return byTime;
      }
      return b.activityId.value.compareTo(a.activityId.value);
    });
    return matches.take(limit).toList();
  }
}
