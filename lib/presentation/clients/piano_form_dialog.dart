import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_type.dart';
import '../app_providers.dart';
import '../theme/app_colors.dart';
import 'clients_strings.dart';
import 'piano_confirm_dialog.dart';
import 'piano_error_messages.dart';

Future<Piano?> showPianoFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  required CustomerId customerId,
  Piano? existing,
}) {
  return showDialog<Piano>(
    context: context,
    builder: (dialogContext) {
      return PianoFormDialog(
        existing: existing,
        onSubmit: ({
          required String? brand,
          required String? model,
          required String? serialNumber,
          required PianoType? type,
          required String? location,
          required String? notes,
          required int reminderIntervalMonths,
          required bool remindersEnabled,
        }) {
          final service = ref.read(pianoServiceProvider);
          if (existing == null) {
            return service.create(
              customerId: customerId,
              brand: brand,
              model: model,
              serialNumber: serialNumber,
              type: type,
              location: location,
              notes: notes,
              reminderIntervalMonths: reminderIntervalMonths,
              remindersEnabled: remindersEnabled,
            );
          }
          return service.update(
            id: existing.id,
            brand: brand,
            model: model,
            serialNumber: serialNumber,
            type: type,
            location: location,
            notes: notes,
            reminderIntervalMonths: reminderIntervalMonths,
            remindersEnabled: remindersEnabled,
          );
        },
      );
    },
  );
}

class PianoFormDialog extends StatefulWidget {
  const PianoFormDialog({
    super.key,
    required this.onSubmit,
    this.existing,
  });

  final Piano? existing;
  final Future<Piano> Function({
    required String? brand,
    required String? model,
    required String? serialNumber,
    required PianoType? type,
    required String? location,
    required String? notes,
    required int reminderIntervalMonths,
    required bool remindersEnabled,
  })
  onSubmit;

  @override
  State<PianoFormDialog> createState() => _PianoFormDialogState();
}

class _PianoFormDialogState extends State<PianoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serialNumber;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late final TextEditingController _interval;
  PianoType? _type;
  late bool _remindersEnabled;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _brand = TextEditingController(text: existing?.brand ?? '');
    _model = TextEditingController(text: existing?.model ?? '');
    _serialNumber = TextEditingController(text: existing?.serialNumber ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _interval = TextEditingController(
      text:
          '${existing?.reminderIntervalMonths ?? Piano.defaultReminderIntervalMonths}',
    );
    _type = existing?.type;
    _remindersEnabled = existing?.remindersEnabled ?? true;
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _location.dispose();
    _notes.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _saving) {
      return;
    }
    final identified =
        _brand.text.trim().isNotEmpty ||
        _model.text.trim().isNotEmpty ||
        _type != null;
    if (!identified) {
      setState(() => _error = clientsPianoIdentificationRequired);
      return;
    }

    final months = int.tryParse(_interval.text.trim());
    if (months == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final disabling =
        widget.existing?.remindersEnabled == true && !_remindersEnabled;
    if (disabling) {
      final confirmed = await showDisablePianoRemindersDialog(context);
      if (confirmed != true) {
        if (mounted) {
          setState(() {
            _saving = false;
          });
        }
        return;
      }
    }

    try {
      final saved = await widget.onSubmit(
        brand: _brand.text,
        model: _model.text,
        serialNumber: _serialNumber.text,
        type: _type,
        location: _location.text,
        notes: _notes.text,
        reminderIntervalMonths: months,
        remindersEnabled: _remindersEnabled,
      );
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = pianoMutationMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null ? clientsCreatePianoTitle : clientsEditPianoTitle,
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _brand,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: clientsPianoBrandLabel,
                ),
              ),
              TextFormField(
                controller: _model,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: clientsPianoModelLabel,
                ),
              ),
              TextFormField(
                controller: _serialNumber,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: clientsPianoSerialLabel,
                ),
              ),
              DropdownButtonFormField<PianoType?>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: clientsPianoTypeLabel,
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text(clientsPianoTypeNone),
                  ),
                  DropdownMenuItem(
                    value: PianoType.droit,
                    child: Text(clientsPianoTypeDroit),
                  ),
                  DropdownMenuItem(
                    value: PianoType.queue,
                    child: Text(clientsPianoTypeQueue),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value),
              ),
              TextFormField(
                controller: _location,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: clientsPianoLocationLabel,
                ),
              ),
              TextFormField(
                controller: _notes,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: clientsPianoNotesLabel,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(clientsPianoRemindersEnabledLabel),
                value: _remindersEnabled,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _remindersEnabled = value),
              ),
              TextFormField(
                controller: _interval,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: clientsPianoIntervalLabel,
                ),
                validator: (value) {
                  final months = int.tryParse(value?.trim() ?? '');
                  if (months == null ||
                      months < Piano.minReminderIntervalMonths ||
                      months > Piano.maxReminderIntervalMonths) {
                    return clientsPianoIntervalInvalid;
                  }
                  return null;
                },
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
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(clientsCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: AppColors.onForest,
          ),
          child: const Text(clientsSaveCustomer),
        ),
      ],
    );
  }
}
