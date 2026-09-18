import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../application/dashboard/dashboard_reminder.dart';
import '../../domain/shared/calendar_date.dart';
import '../formatters/french_date_label.dart';
import '../theme/app_colors.dart';
import 'dashboard_strings.dart';

enum DashboardReminderBucket { overdue, dueSoon, upcoming }

const _cardCompactBreakpoint = 680.0;

class DashboardReminderCard extends StatelessWidget {
  const DashboardReminderCard({
    super.key,
    required this.reminder,
    required this.today,
    required this.bucket,
    required this.onReschedule,
    this.onSendReminder,
    this.sendDisabledReason = dashboardSendReminderGoogleDisconnected,
  });

  final DashboardReminder reminder;
  final CalendarDate today;
  final DashboardReminderBucket bucket;
  final VoidCallback onReschedule;
  final VoidCallback? onSendReminder;
  final String sendDisabledReason;

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
    final city = reminder.city;
    final statusLabel = switch (bucket) {
      DashboardReminderBucket.overdue => 'En retard',
      DashboardReminderBucket.dueSoon => 'À traiter',
      DashboardReminderBucket.upcoming => 'À venir',
    };
    final fill = switch (bucket) {
      DashboardReminderBucket.overdue => AppColors.overdueFill,
      DashboardReminderBucket.dueSoon => AppColors.dueSoonFill,
      DashboardReminderBucket.upcoming => AppColors.card,
    };
    final dueColor = switch (bucket) {
      DashboardReminderBucket.overdue => AppColors.copperDark,
      DashboardReminderBucket.dueSoon => AppColors.copper,
      DashboardReminderBucket.upcoming => AppColors.forestMid,
    };
    final dueRelative = formatDueRelative(today: today, dueDate: reminder.dueDate);
    final dueDateLabel = formatFrenchShortDate(reminder.dueDate);
    final semanticsDetails = [
      piano,
      ?city,
      if (DashboardReminderContacts.isPresent(reminder.phone)) reminder.phone!,
      if (DashboardReminderContacts.isPresent(reminder.email)) reminder.email!,
    ].where((part) => part.isNotEmpty).join('. ');

    final avatar = _InitialsAvatar(
      initials: dashboardCustomerInitials(
        lastName: reminder.lastName,
        firstName: reminder.firstName,
      ),
    );
    final identity = _IdentityColumn(
      name: name,
      piano: piano,
      city: city,
      phone: reminder.phone,
      email: reminder.email,
    );
    final due = _DueColumn(
      dateLabel: dueDateLabel,
      relativeLabel: dueRelative,
      dueColor: dueColor,
    );
    final actions = _ActionColumn(
      onReschedule: onReschedule,
      onSendReminder: onSendReminder,
      sendDisabledReason: sendDisabledReason,
    );

    return Semantics(
      container: true,
      label: '$name. $semanticsDetails. $dueDateLabel. $statusLabel. $dueRelative',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _cardCompactBreakpoint;
            if (compact) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        avatar,
                        const SizedBox(width: 16),
                        Expanded(child: identity),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: due),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  due,
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IdentityColumn extends StatelessWidget {
  const _IdentityColumn({
    required this.name,
    required this.piano,
    required this.city,
    required this.phone,
    required this.email,
  });

  final String name;
  final String piano;
  final String? city;
  final String? phone;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final cityLabel = city;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium),
        if (piano.isNotEmpty)
          Text(piano, style: Theme.of(context).textTheme.bodyLarge),
        if (cityLabel != null)
          Text(cityLabel, style: Theme.of(context).textTheme.bodyMedium),
        if (DashboardReminderContacts.isPresent(phone) ||
            DashboardReminderContacts.isPresent(email))
          DashboardReminderContacts(phone: phone, email: email),
      ],
    );
  }
}

class DashboardReminderContacts extends StatelessWidget {
  const DashboardReminderContacts({
    super.key,
    this.phone,
    this.email,
  });

  final String? phone;
  final String? email;

  static bool isPresent(String? value) =>
      value != null && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (isPresent(phone))
        Text(phone!, style: Theme.of(context).textTheme.bodyMedium),
      if (isPresent(email))
        Text(email!, style: Theme.of(context).textTheme.bodyMedium),
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: items,
    );
  }
}

class _DueColumn extends StatelessWidget {
  const _DueColumn({
    required this.dateLabel,
    required this.relativeLabel,
    required this.dueColor,
  });

  final String dateLabel;
  final String relativeLabel;
  final Color dueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Échéance', style: Theme.of(context).textTheme.bodyMedium),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: dueColor,
          ),
        ),
        Text(relativeLabel, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({
    required this.onReschedule,
    required this.onSendReminder,
    required this.sendDisabledReason,
  });

  final VoidCallback onReschedule;
  final VoidCallback? onSendReminder;
  final String sendDisabledReason;

  @override
  Widget build(BuildContext context) {
    final canSend = onSendReminder != null;
    final tooltip = canSend ? dashboardSendReminderTitle : sendDisabledReason;
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: tooltip,
            child: Semantics(
              button: true,
              enabled: canSend,
              label: 'Envoyer le rappel',
              hint: tooltip,
              child: FilledButton(
                onPressed: onSendReminder,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: AppColors.copper.withValues(
                    alpha: 0.58,
                  ),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.88),
                  minimumSize: const Size(0, 40),
                  disabledMouseCursor: SystemMouseCursors.forbidden,
                ),
                child: const Text('Envoyer le rappel'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onReschedule,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Reporter'),
          ),
        ],
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
        radius: 24,
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
