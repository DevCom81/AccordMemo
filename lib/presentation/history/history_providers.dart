import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/history/history_entry.dart';
import '../../application/history/history_kind.dart';
import '../../application/history/history_query.dart';
import '../app_providers.dart';

final historyFilterProvider =
    NotifierProvider<HistoryFilter, HistoryKindFilter>(HistoryFilter.new);

final historySnapshotProvider = FutureProvider<List<HistoryEntry>>((ref) {
  final filter = ref.watch(historyFilterProvider);
  return ref.watch(historyQueryProvider).findRecent(
    limit: historyDefaultLimit,
    filter: filter,
  );
});

final class HistoryFilter extends Notifier<HistoryKindFilter> {
  @override
  HistoryKindFilter build() => HistoryKindFilter.all;

  void setFilter(HistoryKindFilter filter) {
    if (state == filter) {
      return;
    }
    state = filter;
  }
}
