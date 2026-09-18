import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../domain/customer/civility.dart';
import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/shared/calendar_date.dart';
import '../app_providers.dart';
import '../history/history_providers.dart';
import '../theme/app_colors.dart';
import 'clients_providers.dart';
import 'clients_strings.dart';
import 'piano_confirm_dialog.dart';
import 'piano_form_dialog.dart';
import 'piano_summary_card.dart';
import 'record_tuning_dialog.dart';

class ClientDetailPane extends ConsumerWidget {
  const ClientDetailPane({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = formatDashboardCustomerName(
      lastName: customer.lastName,
      firstName: customer.firstName,
    );
    final civility = switch (customer.civility) {
      Civility.monsieur => 'Monsieur',
      Civility.madame => 'Madame',
      null => null,
    };
    final pianosAsync = ref.watch(selectedCustomerPianosProvider);
    final latestDates =
        ref.watch(selectedCustomerLatestTuningDatesProvider).value ??
        const <PianoId, CalendarDate>{};

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.isArchived) ...[
                  const _ArchivedBanner(),
                  const SizedBox(height: 16),
                ],
                if (civility != null)
                  Text(civility, style: Theme.of(context).textTheme.bodyMedium),
                Text(name, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 16),
                _CustomerActions(
                  archived: customer.isArchived,
                  onEdit: onEdit,
                  onArchive: onArchive,
                  onRestore: onRestore,
                ),
                const SizedBox(height: 16),
                ..._coordinateLines(context),
              ],
            ),
          ),
        ),
        ...pianosAsync.when(
          skipLoadingOnReload: true,
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(clientsPianosLoading),
                  ],
                ),
              ),
            ),
          ],
          error: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Text(clientsPianosLoadError),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(selectedCustomerPianosProvider);
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          data: (pianos) => _pianoSlivers(context, ref, pianos, latestDates),
        ),
      ],
    );
  }

  List<Widget> _coordinateLines(BuildContext context) {
    final lines = <Widget>[];
    final address = customer.address;
    final postalCity = [
      ?customer.postalCode,
      ?customer.city,
    ].join(' ');

    if (address != null) {
      lines.add(Text(address, style: Theme.of(context).textTheme.bodyLarge));
    }
    if (postalCity.isNotEmpty) {
      lines.add(Text(postalCity, style: Theme.of(context).textTheme.bodyLarge));
    }
    final phone = customer.phone;
    final email = customer.email;
    if (phone != null) {
      lines.add(const SizedBox(height: 12));
      lines.add(
        Text(clientsPhoneLabel, style: Theme.of(context).textTheme.bodyMedium),
      );
      lines.add(Text(phone, style: Theme.of(context).textTheme.bodyLarge));
    }
    if (email != null) {
      lines.add(const SizedBox(height: 12));
      lines.add(
        Text(clientsEmailLabel, style: Theme.of(context).textTheme.bodyMedium),
      );
      lines.add(Text(email, style: Theme.of(context).textTheme.bodyLarge));
    }
    return lines;
  }

  Future<void> _addPiano(BuildContext context, WidgetRef ref) async {
    if (customer.isArchived) {
      return;
    }
    final created = await showPianoFormDialog(
      context: context,
      ref: ref,
      customerId: customer.id,
    );
    if (!context.mounted || created == null) {
      return;
    }
    ref.invalidate(selectedCustomerPianosProvider);
  }

  Future<void> _editPiano(
    BuildContext context,
    WidgetRef ref,
    Piano piano,
  ) async {
    if (customer.isArchived || piano.isArchived) {
      return;
    }
    final updated = await showPianoFormDialog(
      context: context,
      ref: ref,
      customerId: customer.id,
      existing: piano,
    );
    if (!context.mounted || updated == null) {
      return;
    }
    ref.invalidate(selectedCustomerPianosProvider);
    if (piano.remindersEnabled != updated.remindersEnabled) {
      ref.invalidate(historySnapshotProvider);
    }
  }

  Future<void> _archivePiano(
    BuildContext context,
    WidgetRef ref,
    Piano piano,
  ) async {
    if (customer.isArchived || piano.isArchived) {
      return;
    }
    final archived = await showArchivePianoDialog(
      context: context,
      ref: ref,
      pianoId: piano.id,
    );
    if (!context.mounted || !archived) {
      return;
    }
    ref.invalidate(selectedCustomerPianosProvider);
  }

  Future<void> _restorePiano(
    BuildContext context,
    WidgetRef ref,
    Piano piano,
  ) async {
    if (customer.isArchived || !piano.isArchived) {
      return;
    }
    final restored = await showRestorePianoDialog(
      context: context,
      ref: ref,
      pianoId: piano.id,
    );
    if (!context.mounted || restored == null) {
      return;
    }
    ref.invalidate(selectedCustomerPianosProvider);
  }

  Future<void> _recordTuning(
    BuildContext context,
    WidgetRef ref,
    Piano piano,
  ) async {
    if (customer.isArchived || piano.isArchived) {
      return;
    }
    final recorded = await showRecordTuningDialog(
      context: context,
      ref: ref,
      pianoId: piano.id,
    );
    if (!context.mounted || !recorded) {
      return;
    }
    ref.invalidate(selectedCustomerLatestTuningDatesProvider);
    ref.invalidate(dashboardSnapshotProvider);
    ref.invalidate(historySnapshotProvider);
  }

  List<Widget> _pianoSlivers(
    BuildContext context,
    WidgetRef ref,
    SelectedCustomerPianos pianos,
    Map<PianoId, CalendarDate> latestDates,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        sliver: SliverToBoxAdapter(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                clientsPianosSection,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!customer.isArchived)
                FilledButton.icon(
                  onPressed: () => _addPiano(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: AppColors.onForest,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(clientsAddPiano),
                ),
            ],
          ),
        ),
      ),
      if (pianos.active.isEmpty)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clientsNoPianoTitle),
                SizedBox(height: 4),
                Text(clientsNoPianoBody),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          sliver: SliverList.separated(
            itemCount: pianos.active.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final piano = pianos.active[index];
              return PianoSummaryCard(
                piano: piano,
                lastTuningDate: latestDates[piano.id],
                onRecordTuning: customer.isArchived
                    ? null
                    : () => _recordTuning(context, ref, piano),
                onEdit: customer.isArchived
                    ? null
                    : () => _editPiano(context, ref, piano),
                onArchive: customer.isArchived
                    ? null
                    : () => _archivePiano(context, ref, piano),
              );
            },
          ),
        ),
      if (pianos.archived.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 40),
          sliver: SliverToBoxAdapter(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              title: Text(
                clientsArchivedPianosSection,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              children: [
                for (var i = 0; i < pianos.archived.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  PianoSummaryCard(
                    piano: pianos.archived[i],
                    muted: true,
                    lastTuningDate: latestDates[pianos.archived[i].id],
                    onRestore: customer.isArchived
                        ? null
                        : () => _restorePiano(context, ref, pianos.archived[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
  }
}

class _CustomerActions extends StatelessWidget {
  const _CustomerActions({
    required this.archived,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!archived) ...[
          OutlinedButton(
            onPressed: onEdit,
            child: const Text(clientsEditCustomer),
          ),
          OutlinedButton(
            onPressed: onArchive,
            child: const Text(clientsArchiveAction),
          ),
        ] else
          FilledButton(
            onPressed: onRestore,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.onForest,
            ),
            child: const Text(clientsRestoreAction),
          ),
      ],
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          clientsArchivedBanner,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }
}
