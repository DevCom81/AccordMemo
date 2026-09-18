import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../application/history/history_entry.dart';
import '../../application/history/history_kind.dart';
import '../formatters/french_date_label.dart';
import '../theme/app_colors.dart';
import 'history_kind_label.dart';
import 'history_strings.dart';

class HistoryEventCard extends StatelessWidget {
  const HistoryEventCard({super.key, required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final customer = formatDashboardCustomerName(
      lastName: entry.customerLastName,
      firstName: entry.customerFirstName,
    );
    final piano = formatDashboardPianoName(
      brand: entry.pianoBrand,
      model: entry.pianoModel,
      type: entry.pianoType,
    );
    final kind = historyKindLabel(entry.kind);
    final occurred = formatFrenchDateTime(entry.occurredAt);
    final detail = _detail(entry);
    final badges = [
      if (entry.customerArchived) historyCustomerArchivedBadge,
      if (entry.pianoArchived) historyPianoArchivedBadge,
    ];

    return Semantics(
      container: true,
      label: [
        occurred,
        kind,
        customer,
        if (piano.isNotEmpty) piano,
        ?detail,
        ...badges,
      ].join('. '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    occurred,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  for (final badge in badges) _ArchivedBadge(label: badge),
                ],
              ),
              const SizedBox(height: 4),
              Text(kind, style: Theme.of(context).textTheme.titleMedium),
              Text(
                piano.isEmpty ? customer : '$customer · $piano',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (detail != null)
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

String? _detail(HistoryEntry entry) {
  return switch (entry.kind) {
    HistoryKind.tuningCreated => entry.tuningDate == null
        ? null
        : formatFrenchNumericDate(entry.tuningDate!),
    HistoryKind.tuningUpdated =>
      entry.previousDate == null || entry.newDate == null
          ? null
          : formatFrenchDateRange(
              from: entry.previousDate!,
              to: entry.newDate!,
            ),
    HistoryKind.reminderRescheduled =>
      entry.previousDate == null || entry.newDate == null
          ? null
          : formatFrenchDateRange(
              from: entry.previousDate!,
              to: entry.newDate!,
            ),
    HistoryKind.reminderSent => entry.reminderDueDate == null
        ? null
        : formatFrenchNumericDate(entry.reminderDueDate!),
    HistoryKind.reminderDisabled || HistoryKind.reminderReenabled => null,
  };
}

class _ArchivedBadge extends StatelessWidget {
  const _ArchivedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.muted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
