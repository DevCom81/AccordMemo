import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/backup/backup_exceptions.dart';
import '../../application/backup/backup_outcome.dart';
import '../../application/ports/google_auth_session.dart';
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
  var _confirmingRestore = false;
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
        _message = outcome == BackupOutcome.completed
            ? settingsBackupSuccess
            : settingsBackupCancelled;
        _isError = false;
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

  Future<bool> _confirmRestore() async {
    if (!mounted) {
      return false;
    }
    setState(() => _confirmingRestore = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
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
    if (!mounted) {
      return false;
    }
    setState(() => _confirmingRestore = false);
    return confirmed == true;
  }

  Future<void> _restore() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });
    try {
      final outcome = await ref.read(dataBackupServiceProvider).restore(
        confirm: _confirmRestore,
      );
      if (!mounted) {
        return;
      }
      if (outcome == RestoreOutcome.completed) {
        _reloadAfterRestore();
      }
      setState(() {
        _busy = false;
        _message = outcome == RestoreOutcome.completed
            ? settingsRestoreSuccess
            : settingsRestoreCancelled;
        _isError = false;
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
        _confirmingRestore = false;
        _message = settingsRestoreMessage(error);
        _isError = true;
      });
    }
  }

  Future<void> _connectGoogle({required bool reconnect}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });
    try {
      final session = ref.read(googleAuthSessionProvider);
      if (reconnect) {
        await session.reconnect();
      } else {
        await session.connect();
      }
      ref.invalidate(googleAuthStateProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ref.invalidate(googleAuthStateProvider);
      setState(() {
        _busy = false;
        _message = settingsMailMessage(error);
        _isError = true;
      });
    }
  }

  Future<void> _disconnectGoogle() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _isError = false;
    });
    try {
      await ref.read(googleAuthSessionProvider).disconnect();
      ref.invalidate(googleAuthStateProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ref.invalidate(googleAuthStateProvider);
      setState(() {
        _busy = false;
        _message = settingsMailMessage(error);
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
    final android = ref.watch(backupOnAndroidProvider);
    final location = android
        ? settingsAndroidLocation
        : ref.watch(appDataLocatorProvider).displayLocation;
    final google = ref.watch(googleAuthStateProvider);
    final restoringGoogle = ref.watch(googleAuthOnAndroidProvider) &&
        google.isLoading;
    final googleState =
        google.asData?.value ?? const GoogleAuthState.disconnected();
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
                    android
                        ? settingsLocalOnlyAndroidMessage
                        : settingsLocalOnlyMessage,
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
                    android ? settingsAndroidBackupHelp : settingsBackupHelp,
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
                  const SizedBox(height: 36),
                  Text(
                    settingsMailSectionTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settingsMailAccountLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (restoringGoogle)
                    const Text(settingsMailRestoring)
                  else if (googleState.isConnected) ...[
                    Text(
                      '$settingsMailConnectedPrefix${googleState.accountEmail}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _connectGoogle(reconnect: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: AppColors.onForest,
                          ),
                          child: const Text(settingsMailReconnect),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : _disconnectGoogle,
                          child: const Text(settingsMailDisconnect),
                        ),
                      ],
                    ),
                  ] else
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _connectGoogle(reconnect: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: AppColors.onForest,
                      ),
                      child: const Text(settingsMailConnect),
                    ),
                  if (_busy && !_confirmingRestore) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text(settingsWorking)),
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
