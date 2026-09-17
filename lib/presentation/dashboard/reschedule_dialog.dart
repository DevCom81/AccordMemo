import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../application/dashboard/dashboard_reminder.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/shared/calendar_date.dart';
import '../app_providers.dart';
import '../theme/app_colors.dart';

Future<bool> showRescheduleDialog({
  required BuildContext context,
  required WidgetRef ref,
  required DashboardReminder reminder,
  required CalendarDate today,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return _RescheduleDialog(
        reminder: reminder,
        today: today,
        onSubmit: (newDueDate) {
          return ref.read(reminderServiceProvider).reschedule(
            id: reminder.reminderId,
            newDueDate: newDueDate,
          );
        },
      );
    },
  );
  return saved == true;
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({
    required this.reminder,
    required this.today,
    required this.onSubmit,
  });

  final DashboardReminder reminder;
  final CalendarDate today;
  final Future<void> Function(CalendarDate newDueDate) onSubmit;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late CalendarDate _selected;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.reminder.dueDate < widget.today
        ? widget.today
        : widget.reminder.dueDate;
  }

  CalendarDate get _base {
    return widget.reminder.dueDate >= widget.today
        ? widget.reminder.dueDate
        : widget.today;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selected.year, _selected.month, _selected.day),
      firstDate: DateTime(
        widget.today.year,
        widget.today.month,
        widget.today.day,
      ),
      lastDate: () {
        final limit = widget.today.addMonths(60);
        return DateTime(limit.year, limit.month, limit.day);
      }(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selected = CalendarDate.fromLocalInstant(picked);
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_selected);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = _messageFor(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = formatDashboardCustomerName(
      lastName: widget.reminder.lastName,
      firstName: widget.reminder.firstName,
    );
    return AlertDialog(
      title: const Text('Reporter le rappel'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
              'Échéance actuelle',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              widget.reminder.dueDate.toIso8601String(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Nouvelle date',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : _pickDate,
              child: Text(_selected.toIso8601String()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _selected = _base.addDays(7);
                          _error = null;
                        }),
                  child: const Text('+7 jours'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _selected = _base.addMonths(1);
                          _error = null;
                        }),
                  child: const Text('+1 mois'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: AppColors.onForest,
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

String _messageFor(Object error) {
  if (error is ReminderDueDateInPast) {
    return 'La date choisie ne peut pas être antérieure à aujourd’hui.';
  }
  if (error is ReminderNotFound ||
      error is ReminderAlreadySent ||
      error is ReminderAlreadyCancelled) {
    return 'Ce rappel n’est plus à traiter.';
  }
  return 'Impossible d’enregistrer le report.';
}
