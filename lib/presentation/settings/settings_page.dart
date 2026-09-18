import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/backup/backup_exceptions.dart';
import '../../application/backup/backup_outcome.dart';
import '../app_providers.dart';
import '../clients/clients_providers.dart';
import '../history/history_providers.dart';
import '../theme/app_colors.dart';
import 'settings_error_messages.dart';
import 'settings_providers.dart';
import 'settings_strings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _busy = false;
  String? _message;
  var _isError = false;

  Future<void> _backup() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });
    try {
      final outcome = await ref.read(dataBackupServiceProvider).backup();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (outcome == BackupOutcome.completed) {
          _message = settingsBackupSuccess;
          _isError = false;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _message = settingsBackupMessage(error);
        _isError = true;
      });
    }
  }

  Future<void> _restore() async {
    if (_busy) {
      return;
    }
    final picker = ref.read(fileLocationPickerProvider);
    final source = await picker.pickOpenLocation();
    if (!mounted || source == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(settingsRestoreTitle),
          content: const SizedBox(
            width: 420,
            child: Text(settingsRestoreBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(settingsCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.copperDark,
                foregroundColor: Colors.white,
              ),
              child: const Text(settingsRestoreConfirm),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });
    try {
      final outcome = await ref.read(dataBackupServiceProvider).restore(
        sourcePath: source,
      );
      if (!mounted) {
        return;
      }
      if (outcome == RestoreOutcome.completed) {
        _reloadAfterRestore();
      }
      setState(() {
        _busy = false;
        if (outcome == RestoreOutcome.completed) {
          _message = settingsRestoreSuccess;
          _isError = false;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is RestoreRolledBack || error is RestoreFailed) {
        _reloadAfterRestore();
      }
      setState(() {
        _busy = false;
        _message = settingsRestoreMessage(error);
        _isError = true;
      });
    }
  }

  void _reloadAfterRestore() {
    ref.read(selectedCustomerIdProvider.notifier).clear();
    ref.invalidate(dashboardSnapshotProvider);
    ref.invalidate(clientsSearchProvider);
    ref.invalidate(selectedCustomerPianosProvider);
    ref.invalidate(selectedCustomerLatestTuningDatesProvider);
    ref.invalidate(historySnapshotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(appDataLocatorProvider).displayLocation;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
          sliver: SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settingsPageTitle,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    settingsDataSectionTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settingsLocalOnlyMessage,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    settingsLocationLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SelectableText(
                    location,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    settingsBackupHelp,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _backup,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: AppColors.onForest,
                    ),
                    child: const Text(settingsBackupButton),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    settingsRestoreHelp,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _restore,
                    child: const Text(settingsRestoreButton),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(settingsWorking),
                      ],
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _isError
                            ? Theme.of(context).colorScheme.error
                            : AppColors.forest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
