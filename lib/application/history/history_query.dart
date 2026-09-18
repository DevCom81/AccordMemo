import 'history_entry.dart';
import 'history_kind.dart';

const historyDefaultLimit = 100;

abstract interface class HistoryQuery {
  Future<List<HistoryEntry>> findRecent({
    required int limit,
    required HistoryKindFilter filter,
  });
}
