import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../domain/customer/civility.dart';
import '../../domain/customer/customer.dart';
import '../theme/app_colors.dart';
import 'clients_providers.dart';
import 'clients_strings.dart';
import 'piano_summary_card.dart';

class ClientDetailPane extends ConsumerWidget {
  const ClientDetailPane({super.key, required this.customer});

  final Customer customer;

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
          data: (pianos) => _pianoSlivers(context, pianos),
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

  List<Widget> _pianoSlivers(BuildContext context, SelectedCustomerPianos pianos) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            clientsPianosSection,
            style: Theme.of(context).textTheme.titleLarge,
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
              return PianoSummaryCard(piano: pianos.active[index]);
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
                  PianoSummaryCard(piano: pianos.archived[i], muted: true),
                ],
              ],
            ),
          ),
        ),
    ];
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
