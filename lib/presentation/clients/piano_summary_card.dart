import 'package:flutter/material.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/shared/calendar_date.dart';
import '../formatters/french_date_label.dart';
import '../theme/app_colors.dart';
import 'clients_strings.dart';

class PianoSummaryCard extends StatelessWidget {
  const PianoSummaryCard({
    super.key,
    required this.piano,
    this.muted = false,
    this.lastTuningDate,
    this.onRecordTuning,
    this.onCorrectTuning,
    this.onEdit,
    this.onArchive,
    this.onRestore,
  });

  final Piano piano;
  final bool muted;
  final CalendarDate? lastTuningDate;
  final VoidCallback? onRecordTuning;
  final VoidCallback? onCorrectTuning;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final name = formatDashboardPianoName(
      brand: piano.brand,
      model: piano.model,
      type: piano.type,
    );
    final typeLabel = switch (piano.type) {
      PianoType.droit => 'Piano droit',
      PianoType.queue => 'Piano à queue',
      null => null,
    };
    final reminder = piano.remindersEnabled
        ? clientsReminderEveryMonths(piano.reminderIntervalMonths)
        : clientsRemindersDisabled;
    final location = piano.location;
    final lastTuning = lastTuningDate == null
        ? null
        : '$clientsLastTuningPrefix${formatFrenchNumericDate(lastTuningDate!)}';
    final canAct =
        onRecordTuning != null ||
        onCorrectTuning != null ||
        onEdit != null ||
        onArchive != null ||
        onRestore != null;

    final content = Opacity(
      opacity: muted ? 0.72 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: muted ? AppColors.cream : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: muted ? AppColors.muted : AppColors.ink,
                ),
              ),
              if (typeLabel != null && typeLabel != name)
                Text(
                  typeLabel,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (location != null)
                Text(location, style: Theme.of(context).textTheme.bodyMedium),
              if (lastTuning != null)
                Text(lastTuning, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                reminder,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: piano.remindersEnabled
                      ? AppColors.muted
                      : AppColors.copperDark,
                ),
              ),
              if (canAct) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onRecordTuning != null)
                      FilledButton(
                        onPressed: onRecordTuning,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: AppColors.onForest,
                        ),
                        child: const Text(clientsRecordTuning),
                      ),
                    if (onCorrectTuning != null)
                      OutlinedButton(
                        onPressed: onCorrectTuning,
                        child: const Text(clientsCorrectTuning),
                      ),
                    if (onEdit != null)
                      OutlinedButton(
                        onPressed: onEdit,
                        child: const Text(clientsEditCustomer),
                      ),
                    if (onArchive != null)
                      OutlinedButton(
                        onPressed: onArchive,
                        child: const Text(clientsArchiveAction),
                      ),
                    if (onRestore != null)
                      FilledButton(
                        onPressed: onRestore,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: AppColors.onForest,
                        ),
                        child: const Text(clientsRestoreAction),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: [
        name,
        if (typeLabel != null && typeLabel != name) typeLabel,
        ?location,
        ?lastTuning,
        reminder,
        if (muted) clientsArchivedPianosSection,
      ].join('. '),
      child: content,
    );
  }
}
