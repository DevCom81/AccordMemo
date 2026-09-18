import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/history/history_entry.dart';
import '../../application/history/history_kind.dart';
import '../theme/app_colors.dart';
import 'history_event_card.dart';
import 'history_providers.dart';
import 'history_strings.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final async = ref.watch(historySnapshotProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const _HistoryStatus(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(historyLoadingMessage),
          ],
        ),
      ),
      error: (_, _) => _HistoryStatus(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(historyLoadErrorMessage),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(historySnapshotProvider),
              child: const Text(historyRetry),
            ),
          ],
        ),
      ),
      data: (entries) => _HistoryBody(
        filter: filter,
        entries: entries,
        onFilter: (next) => ref.read(historyFilterProvider.notifier).setFilter(next),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.filter,
    required this.entries,
    required this.onFilter,
  });

  final HistoryKindFilter filter;
  final List<HistoryEntry> entries;
  final ValueChanged<HistoryKindFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historyPageTitle,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                _HistoryFilters(filter: filter, onFilter: onFilter),
              ],
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(filter: filter),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 40),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return HistoryEventCard(entry: entries[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.filter,
    required this.onFilter,
  });

  final HistoryKindFilter filter;
  final ValueChanged<HistoryKindFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<HistoryKindFilter>(
      segments: const [
        ButtonSegment(
          value: HistoryKindFilter.all,
          label: Text(historyFilterAll),
        ),
        ButtonSegment(
          value: HistoryKindFilter.tunings,
          label: Text(historyFilterTunings),
        ),
        ButtonSegment(
          value: HistoryKindFilter.reminders,
          label: Text(historyFilterReminders),
        ),
      ],
      selected: {filter},
      onSelectionChanged: (next) {
        if (next.isNotEmpty) {
          onFilter(next.single);
        }
      },
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onForest;
          }
          return AppColors.forest;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.forest;
          }
          return AppColors.card;
        }),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final HistoryKindFilter filter;

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      HistoryKindFilter.all => historyEmptyAllTitle,
      HistoryKindFilter.tunings => historyEmptyTuningsTitle,
      HistoryKindFilter.reminders => historyEmptyRemindersTitle,
    };
    final body = switch (filter) {
      HistoryKindFilter.all => historyEmptyAllBody,
      HistoryKindFilter.tunings => historyEmptyTuningsBody,
      HistoryKindFilter.reminders => historyEmptyRemindersBody,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatus extends StatelessWidget {
  const _HistoryStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            historyPageTitle,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}
