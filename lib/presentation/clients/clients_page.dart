import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../theme/app_colors.dart';
import 'clients_providers.dart';
import 'clients_strings.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(clientsFilterProvider);
    final selectedId = ref.watch(selectedCustomerIdProvider);
    final async = ref.watch(clientsSearchProvider);

    ref.listen(clientsSearchProvider, (previous, next) {
      next.whenData((customers) {
        final selected = ref.read(selectedCustomerIdProvider);
        if (selected == null) {
          return;
        }
        final stillThere = customers.any((customer) => customer.id == selected);
        if (!stillThere) {
          ref.read(selectedCustomerIdProvider.notifier).clear();
        }
      });
    });

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientsPageTitle,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 24),
                Semantics(
                  textField: true,
                  label: clientsSearchSemanticsLabel,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      ref.read(clientsQueryProvider.notifier).schedule(value);
                    },
                    decoration: InputDecoration(
                      hintText: clientsSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.forest),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FilterToggle(
                  filter: filter,
                  onChanged: (value) {
                    ref.read(clientsFilterProvider.notifier).setFilter(value);
                  },
                ),
              ],
            ),
          ),
        ),
        ...async.when(
          skipLoadingOnReload: true,
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _ClientsStatus(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(clientsLoadingMessage),
                  ],
                ),
              ),
            ),
          ],
          error: (_, _) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ClientsStatus(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(clientsLoadErrorMessage),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(clientsSearchProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          data: (customers) => _resultsSlivers(
            context: context,
            customers: customers,
            filter: filter,
            query: ref.read(clientsQueryProvider),
            selectedId: selectedId,
          ),
        ),
      ],
    );
  }

  List<Widget> _resultsSlivers({
    required BuildContext context,
    required List<Customer> customers,
    required CustomerStatusFilter filter,
    required String query,
    required CustomerId? selectedId,
  }) {
    if (customers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(filter: filter, hasQuery: query.isNotEmpty),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 40),
        sliver: SliverList.separated(
          itemCount: customers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final customer = customers[index];
            return _ClientRow(
              customer: customer,
              selected: customer.id == selectedId,
              onSelect: () {
                ref.read(selectedCustomerIdProvider.notifier).select(customer.id);
              },
            );
          },
        ),
      ),
    ];
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({required this.filter, required this.onChanged});

  final CustomerStatusFilter filter;
  final ValueChanged<CustomerStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: clientsFilterActive,
          selected: filter == CustomerStatusFilter.active,
          onPressed: () => onChanged(CustomerStatusFilter.active),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: clientsFilterArchived,
          selected: filter == CustomerStatusFilter.archived,
          onPressed: () => onChanged(CustomerStatusFilter.archived),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forest : AppColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        focusColor: AppColors.focus.withValues(alpha: 0.35),
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.forest : AppColors.line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.onForest : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.customer,
    required this.selected,
    required this.onSelect,
  });

  final Customer customer;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final name = formatDashboardCustomerName(
      lastName: customer.lastName,
      firstName: customer.firstName,
    );
    final city = customer.city;
    final contact = customer.phone ?? customer.email;
    final details = [
      ?city,
      ?contact,
    ].join(' · ');
    final semanticsDetails = [
      ?city,
      ?contact,
    ].join('. ');

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsDetails.isEmpty ? name : '$name. $semanticsDetails',
      child: Material(
        color: selected ? AppColors.dueSoonFill : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(12),
          focusColor: AppColors.focus.withValues(alpha: 0.35),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.forest : AppColors.line,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.overdueFill,
                      foregroundColor: AppColors.copperDark,
                      child: Text(
                        dashboardCustomerInitials(
                          lastName: customer.lastName,
                          firstName: customer.firstName,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.hasQuery});

  final CustomerStatusFilter filter;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? clientsEmptySearchTitle
        : (filter == CustomerStatusFilter.archived
              ? clientsEmptyArchivedTitle
              : clientsEmptyActiveTitle);
    final body = hasQuery
        ? clientsEmptySearchBody
        : (filter == CustomerStatusFilter.archived
              ? clientsEmptyArchivedBody
              : clientsEmptyActiveBody);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientsStatus extends StatelessWidget {
  const _ClientsStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}
