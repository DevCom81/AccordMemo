import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/piano/piano.dart';
import '../app_providers.dart';
import '../theme/app_colors.dart';
import 'clients_strings.dart';
import 'piano_error_messages.dart';

Future<bool> showDisablePianoRemindersDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        title: const Text(clientsDisablePianoRemindersTitle),
        content: const SizedBox(
          width: 420,
          child: Text(clientsDisablePianoRemindersBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(clientsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.copperDark,
              foregroundColor: Colors.white,
            ),
            child: const Text(clientsDisablePianoRemindersConfirm),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

Future<bool> showArchivePianoDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PianoId pianoId,
}) async {
  final archived = await showDialog<Piano>(
    context: context,
    builder: (dialogContext) {
      return _PianoMutationConfirmDialog(
        title: clientsArchivePianoTitle,
        body: clientsArchivePianoBody,
        confirmLabel: clientsArchivePianoConfirm,
        destructive: true,
        onConfirm: () => ref.read(pianoServiceProvider).archive(pianoId),
      );
    },
  );
  return archived != null;
}

Future<Piano?> showRestorePianoDialog({
  required BuildContext context,
  required WidgetRef ref,
  required PianoId pianoId,
}) {
  return showDialog<Piano>(
    context: context,
    builder: (dialogContext) {
      return _PianoMutationConfirmDialog(
        title: clientsRestorePianoTitle,
        body: clientsRestorePianoBody,
        confirmLabel: clientsRestorePianoConfirm,
        destructive: false,
        onConfirm: () => ref.read(pianoServiceProvider).restore(pianoId),
      );
    },
  );
}

class _PianoMutationConfirmDialog<T> extends StatefulWidget {
  const _PianoMutationConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.destructive,
    required this.onConfirm,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final bool destructive;
  final Future<T> Function() onConfirm;

  @override
  State<_PianoMutationConfirmDialog<T>> createState() =>
      _PianoMutationConfirmDialogState<T>();
}

class _PianoMutationConfirmDialogState<T>
    extends State<_PianoMutationConfirmDialog<T>> {
  var _saving = false;
  String? _error;

  Future<void> _confirm() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (mounted) {
        Navigator.of(context).pop(result);
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
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(clientsCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _confirm,
          style: FilledButton.styleFrom(
            backgroundColor: widget.destructive
                ? AppColors.copperDark
                : AppColors.forest,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
