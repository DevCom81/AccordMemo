import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../application/dashboard/dashboard_reminder.dart';
import '../../domain/shared/calendar_date.dart';
import '../formatters/french_date_label.dart';
import '../theme/app_colors.dart';
import 'dashboard_strings.dart';

enum DashboardReminderBucket { overdue, dueSoon, upcoming }

class DashboardReminderCard extends StatelessWidget {
  const DashboardReminderCard({
    super.key,
    required this.reminder,
    required this.today,
    required this.bucket,
    required this.onReschedule,
  });

  final DashboardReminder reminder;
  final CalendarDate today;
  final DashboardReminderBucket bucket;
  final VoidCallback onReschedule;

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
    final details = [
      if (piano.isNotEmpty) piano,
      if (reminder.city != null) reminder.city!,
    ].join(' — ');
    final badge = switch (bucket) {
      DashboardReminderBucket.overdue => 'En retard',
      DashboardReminderBucket.dueSoon => 'À traiter',
      DashboardReminderBucket.upcoming => 'À venir',
    };
    final fill = switch (bucket) {
      DashboardReminderBucket.overdue => AppColors.overdueFill,
      DashboardReminderBucket.dueSoon => AppColors.dueSoonFill,
      DashboardReminderBucket.upcoming => AppColors.card,
    };
    final badgeColor = switch (bucket) {
      DashboardReminderBucket.overdue => AppColors.copperDark,
      DashboardReminderBucket.dueSoon => AppColors.copper,
      DashboardReminderBucket.upcoming => AppColors.forestMid,
    };

    return Semantics(
      container: true,
      label: '$name. $details. ${formatFrenchShortDate(reminder.dueDate)}. $badge. ${formatDueRelative(today: today, dueDate: reminder.dueDate)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _InitialsAvatar(
                initials: dashboardCustomerInitials(
                  lastName: reminder.lastName,
                  firstName: reminder.firstName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (details.isNotEmpty)
                      Text(details, style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      formatDueRelative(today: today, dueDate: reminder.dueDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Échéance',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          formatFrenchShortDate(reminder.dueDate),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                    _StatusBadge(label: badge, color: badgeColor),
                    Tooltip(
                      message: sendReminderComingSoonMessage,
                      child: Semantics(
                        button: true,
                        enabled: false,
                        label: 'Envoyer le rappel',
                        hint: sendReminderComingSoonMessage,
                        child: const FilledButton(
                          onPressed: null,
                          child: Text('Envoyer le rappel'),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onReschedule,
                      child: const Text('Reporter'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.overdueFill,
        foregroundColor: AppColors.copperDark,
        child: Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
