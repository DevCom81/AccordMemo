import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../application/dashboard/dashboard_reminder.dart';
import '../../application/dashboard/dashboard_snapshot.dart';
import '../../domain/shared/calendar_date.dart';
import '../app_providers.dart';
import '../formatters/french_date_label.dart';
import '../theme/app_colors.dart';
import 'dashboard_reminder_card.dart';
import 'dashboard_strings.dart';
import 'reschedule_dialog.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.onSeeAllClients});

  final VoidCallback onSeeAllClients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardSnapshotProvider);
    return async.when(
      loading: () => const _DashboardStatus(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des rappels'),
          ],
        ),
      ),
      error: (_, _) => _DashboardStatus(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(dashboardLoadErrorMessage),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(dashboardSnapshotProvider),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (snapshot) => _DashboardBody(
        snapshot: snapshot,
        onSeeAllClients: onSeeAllClients,
        onReschedule: (reminder) async {
          final saved = await showRescheduleDialog(
            context: context,
            ref: ref,
            reminder: reminder,
            today: snapshot.today,
          );
          if (saved) {
            ref.invalidate(dashboardSnapshotProvider);
          }
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.snapshot,
    required this.onSeeAllClients,
    required this.onReschedule,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback onSeeAllClients;
  final Future<void> Function(DashboardReminder reminder) onReschedule;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 24),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tableau de bord',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatFrenchLongDate(snapshot.today),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onSeeAllClients,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: AppColors.onForest,
                  ),
                  child: const Text('Voir tous les clients'),
                ),
              ],
            ),
          ),
        ),
        if (snapshot.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  if (snapshot.nextDue != null)
                    _NextDueHero(
                      reminder: snapshot.nextDue!,
                      today: snapshot.today,
                    ),
                  if (snapshot.nextDue != null) const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          label: 'En retard',
                          value: '${snapshot.overdue.length}',
                          caption: 'échéance dépassée',
                          emphasized: snapshot.overdue.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _KpiCard(
                          label: 'À traiter',
                          value: '${snapshot.dueSoon.length}',
                          caption: 'dans les 7 jours',
                          emphasized: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _KpiCard(
                          label: 'À venir',
                          value: '${snapshot.upcoming.length}',
                          caption: 'dans les 30 jours',
                          emphasized: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ..._section(
            context: context,
            title: 'En retard',
            items: snapshot.overdue,
            today: snapshot.today,
            bucket: DashboardReminderBucket.overdue,
            onReschedule: onReschedule,
          ),
          ..._section(
            context: context,
            title: 'À traiter',
            items: snapshot.dueSoon,
            today: snapshot.today,
            bucket: DashboardReminderBucket.dueSoon,
            onReschedule: onReschedule,
          ),
          ..._section(
            context: context,
            title: 'À venir',
            items: snapshot.upcoming,
            today: snapshot.today,
            bucket: DashboardReminderBucket.upcoming,
            onReschedule: onReschedule,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ],
    );
  }

  List<Widget> _section({
    required BuildContext context,
    required String title,
    required List<DashboardReminder> items,
    required CalendarDate today,
    required DashboardReminderBucket bucket,
    required Future<void> Function(DashboardReminder reminder) onReschedule,
  }) {
    if (items.isEmpty) {
      return const [];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 12),
        sliver: SliverToBoxAdapter(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 8),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final reminder = items[index];
            return DashboardReminderCard(
              reminder: reminder,
              today: today,
              bucket: bucket,
              onReschedule: () => onReschedule(reminder),
            );
          },
        ),
      ),
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dashboardEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              dashboardEmptyBody,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatus extends StatelessWidget {
  const _DashboardStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}

class _NextDueHero extends StatelessWidget {
  const _NextDueHero({required this.reminder, required this.today});

  final DashboardReminder reminder;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    final name = formatDashboardCustomerName(
      lastName: reminder.lastName,
      firstName: reminder.firstName,
    );
    final piano = formatDashboardPianoName(
      brand: reminder.brand,
      model: reminder.model,
      type: reminder.type,
    );
    final subtitle = [
      if (piano.isNotEmpty) piano,
      if (reminder.city != null) reminder.city!,
    ].join(', ');
    final days = today.daysUntil(reminder.dueDate);
    final absDays = days < 0 ? -days : days;
    final caption = days < 0
        ? (absDays <= 1 ? 'jour de retard' : 'jours de retard')
        : (absDays <= 1 ? 'jour' : 'jours');

    return Semantics(
      label: 'Prochaine échéance : $name. $subtitle. $absDays $caption',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.dueSoonFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              const Icon(Icons.piano, color: AppColors.forest, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROCHAINE ÉCHÉANCE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.isEmpty ? name : '$name — $subtitle',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$absDays',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.copper,
                      fontSize: 36,
                    ),
                  ),
                  Text(caption, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.emphasized,
  });

  final String label;
  final String value;
  final String caption;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final background = emphasized ? AppColors.forest : AppColors.card;
    final titleColor = emphasized ? AppColors.onForest : AppColors.muted;
    final valueColor = emphasized ? AppColors.onForest : AppColors.ink;
    final captionColor = emphasized
        ? AppColors.onForest.withValues(alpha: 0.8)
        : AppColors.muted;

    return Semantics(
      label: '$label : $value. $caption',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: emphasized ? null : Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: titleColor,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: valueColor,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: captionColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
