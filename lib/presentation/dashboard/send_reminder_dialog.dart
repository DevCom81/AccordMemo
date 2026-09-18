import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_reminder.dart';
import '../../application/reminder/send_reminder.dart';
import '../../application/reminder/send_reminder_exceptions.dart';
import '../../domain/reminder/reminder.dart';
import '../app_providers.dart';
import '../theme/app_colors.dart';
import 'dashboard_strings.dart';
import 'send_reminder_error_messages.dart';

Future<bool> showSendReminderDialog({
  required BuildContext context,
  required WidgetRef ref,
  required DashboardReminder reminder,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SendReminderDialog(
        onPreview: () {
          return ref.read(sendReminderProvider).preview(reminder.reminderId);
        },
        onSend: () {
          return ref.read(sendReminderProvider).execute(reminder.reminderId);
        },
        onRecordSent: () {
          return ref.read(reminderServiceProvider).markSent(reminder.reminderId);
        },
      );
    },
  );
  return sent == true;
}

class _SendReminderDialog extends StatefulWidget {
  const _SendReminderDialog({
    required this.onPreview,
    required this.onSend,
    required this.onRecordSent,
  });

  final Future<SendReminderPreview> Function() onPreview;
  final Future<void> Function() onSend;
  final Future<void> Function() onRecordSent;

  @override
  State<_SendReminderDialog> createState() => _SendReminderDialogState();
}

class _SendReminderDialogState extends State<_SendReminderDialog> {
  SendReminderPreview? _preview;
  String? _error;
  var _loadingPreview = true;
  var _sending = false;
  var _recordAfterSend = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final preview = await widget.onPreview();
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingPreview = false;
        _error = sendReminderMessage(error);
      });
    }
  }

  Future<void> _send() async {
    if (_sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _error = sendReminderMessage(error);
        _recordAfterSend = error is ReminderEmailSentButNotRecorded;
      });
    }
  }

  Future<void> _recordSent() async {
    if (_sending) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onRecordSent();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ReminderAlreadySent {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _error = sendReminderMessage(error);
        _recordAfterSend = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      title: const Text(dashboardSendReminderTitle),
      content: SizedBox(
        width: 480,
        child: _loadingPreview
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview != null) ...[
                    Text(
                      dashboardSendReminderRecipientLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SelectableText(
                      preview.recipient,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dashboardSendReminderSubjectLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SelectableText(
                      preview.subject,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dashboardSendReminderBodyLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: SelectableText(preview.body),
                      ),
                    ),
                  ],
                  if (_sending) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(dashboardSendReminderSending),
                      ],
                    ),
                  ],
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
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text(dashboardSendReminderCancel),
        ),
        if (_recordAfterSend)
          FilledButton(
            onPressed: _sending ? null : _recordSent,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.onForest,
            ),
            child: const Text(dashboardSendReminderRecordAsSent),
          )
        else
          FilledButton(
            onPressed: _sending || preview == null ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.onForest,
            ),
            child: const Text(dashboardSendReminderConfirm),
          ),
      ],
    );
  }
}
