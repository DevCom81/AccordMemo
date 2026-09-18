import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/customer/customer.dart';
import '../app_providers.dart';
import '../theme/app_colors.dart';
import 'clients_error_messages.dart';
import 'clients_strings.dart';

Future<bool> showArchiveCustomerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required CustomerId customerId,
}) async {
  final archived = await showDialog<Customer>(
    context: context,
    builder: (dialogContext) {
      return _CustomerMutationConfirmDialog(
        title: clientsArchiveTitle,
        body: clientsArchiveBody,
        confirmLabel: clientsArchiveConfirm,
        destructive: true,
        onConfirm: () => ref.read(customerServiceProvider).archive(customerId),
      );
    },
  );
  return archived != null;
}

Future<Customer?> showRestoreCustomerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required CustomerId customerId,
}) {
  return showDialog<Customer>(
    context: context,
    builder: (dialogContext) {
      return _CustomerMutationConfirmDialog(
        title: clientsRestoreTitle,
        body: clientsRestoreBody,
        confirmLabel: clientsRestoreConfirm,
        destructive: false,
        onConfirm: () => ref.read(customerServiceProvider).restore(customerId),
      );
    },
  );
}

class _CustomerMutationConfirmDialog<T> extends StatefulWidget {
  const _CustomerMutationConfirmDialog({
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
  State<_CustomerMutationConfirmDialog<T>> createState() =>
      _CustomerMutationConfirmDialogState<T>();
}

class _CustomerMutationConfirmDialogState<T>
    extends State<_CustomerMutationConfirmDialog<T>> {
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
        _error = customerMutationMessage(error);
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
