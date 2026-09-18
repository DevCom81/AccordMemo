import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/shared/calendar_date.dart';
import '../../domain/tuning/tuning.dart';
import '../app_providers.dart';
import '../formatters/french_date_label.dart';
import '../theme/app_colors.dart';
import 'clients_strings.dart';
import 'correct_tuning_error_messages.dart';

Future<bool> showCorrectTuningDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Tuning tuning,
}) async {
  final today = CalendarDate.fromLocalInstant(ref.read(clockProvider).now());
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return CorrectTuningDialog(
        today: today,
        initialDate: tuning.tuningDate,
        initialNotes: tuning.notes,
        onSubmit: ({required CalendarDate tuningDate, String? notes}) {
          return ref.read(correctTuningProvider).execute(
            id: tuning.id,
            tuningDate: tuningDate,
            notes: notes,
          );
        },
      );
    },
  );
  return saved == true;
}

class CorrectTuningDialog extends StatefulWidget {
  const CorrectTuningDialog({
    super.key,
    required this.today,
    required this.initialDate,
    required this.onSubmit,
    this.initialNotes,
  });

  final CalendarDate today;
  final CalendarDate initialDate;
  final String? initialNotes;
  final Future<Tuning> Function({
    required CalendarDate tuningDate,
    String? notes,
  })
  onSubmit;

  @override
  State<CorrectTuningDialog> createState() => _CorrectTuningDialogState();
}

class _CorrectTuningDialogState extends State<CorrectTuningDialog> {
  late CalendarDate _selected;
  late final TextEditingController _notes;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _notes = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime get _todayDateTime {
    return DateTime(widget.today.year, widget.today.month, widget.today.day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selected.year, _selected.month, _selected.day),
      firstDate: DateTime(widget.today.year - 40, 1, 1),
      lastDate: _todayDateTime,
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
    if (_saving) {
      return;
    }
    if (_selected > widget.today) {
      setState(() => _error = clientsTuningDateInFuture);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(tuningDate: _selected, notes: _notes.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = correctTuningMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text(clientsCorrectTuningTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clientsRecordTuningDateLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : _pickDate,
              child: Text(formatFrenchNumericDate(_selected)),
            ),
            TextFormField(
              controller: _notes,
              enabled: !_saving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: clientsRecordTuningNotesLabel,
              ),
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
          child: const Text(clientsCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: AppColors.onForest,
          ),
          child: const Text(clientsCorrectTuningSave),
        ),
      ],
    );
  }
}
