import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dashboard/dashboard_display_names.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../theme/app_colors.dart';
import 'client_detail_pane.dart';
import 'clients_providers.dart';
import 'clients_strings.dart';
import 'customer_confirm_dialog.dart';
import 'customer_form_dialog.dart';

const clientsMasterDetailBreakpoint = 960.0;
const _listPaneWidth = 340.0;

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

  void _selectActiveCustomer(Customer customer) {
    _searchController.clear();
    ref.read(clientsQueryProvider.notifier).setImmediate('');
    ref.read(clientsFilterProvider.notifier).setFilter(
      CustomerStatusFilter.active,
      clearSelection: false,
    );
    ref.read(selectedCustomerIdProvider.notifier).select(customer.id);
    ref.invalidate(clientsSearchProvider);
  }

  Future<void> _createCustomer() async {
    final created = await showCustomerFormDialog(context: context, ref: ref);
    if (!mounted || created == null) {
      return;
    }
    _selectActiveCustomer(created);
  }

  Future<void> _editCustomer(Customer customer) async {
    final updated = await showCustomerFormDialog(
      context: context,
      ref: ref,
      existing: customer,
    );
    if (!mounted || updated == null) {
      return;
    }
    ref.invalidate(clientsSearchProvider);
  }

  Future<void> _archiveCustomer(Customer customer) async {
    final archived = await showArchiveCustomerDialog(
      context: context,
      ref: ref,
      customerId: customer.id,
    );
    if (!mounted || !archived) {
      return;
    }
    ref.invalidate(clientsSearchProvider);
  }

  Future<void> _restoreCustomer(Customer customer) async {
    final restored = await showRestoreCustomerDialog(
      context: context,
      ref: ref,
      customerId: customer.id,
    );
    if (!mounted || restored == null) {
      return;
    }
    _selectActiveCustomer(restored);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(clientsFilterProvider);
    final selectedId = ref.watch(selectedCustomerIdProvider);
    final async = ref.watch(clientsSearchProvider);

    ref.listen(clientsSearchProvider, (previous, next) {
      if (next.isLoading) {
        return;
      }
      final customers = next.value;
      if (customers == null) {
        return;
      }
      final selected = ref.read(selectedCustomerIdProvider);
      if (selected == null) {
        return;
      }
      if (!customers.any((customer) => customer.id == selected)) {
        ref.read(selectedCustomerIdProvider.notifier).clear();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= clientsMasterDetailBreakpoint;
        final selectedCustomer = async.asData?.value
            .where((customer) => customer.id == selectedId)
            .firstOrNull;
        final compactDetail = !wide && selectedCustomer != null;

        if (compactDetail) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 40, 0),
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(selectedCustomerIdProvider.notifier).clear();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(clientsBackToList),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
                  child: ClientDetailPane(
                    customer: selectedCustomer,
                    onEdit: () => _editCustomer(selectedCustomer),
                    onArchive: () => _archiveCustomer(selectedCustomer),
                    onRestore: () => _restoreCustomer(selectedCustomer),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 36, 40, 16),
              child: _ClientsHeader(
                controller: _searchController,
                filter: filter,
                onQueryChanged: (value) {
                  ref.read(clientsQueryProvider.notifier).schedule(value);
                },
                onFilterChanged: (value) {
                  ref.read(clientsFilterProvider.notifier).setFilter(value);
                },
                onCreate: _createCustomer,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                child: async.when(
                  skipLoadingOnReload: true,
                  loading: () => const _ClientsStatus(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(clientsLoadingMessage),
                      ],
                    ),
                  ),
                  error: (_, _) => _ClientsStatus(
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
                  data: (customers) {
                    if (customers.isEmpty) {
                      return _EmptyState(
                        filter: filter,
                        hasQuery: ref.read(clientsQueryProvider).isNotEmpty,
                      );
                    }
                    final list = _ClientsList(
                      customers: customers,
                      selectedId: selectedId,
                      onSelect: (id) {
                        ref.read(selectedCustomerIdProvider.notifier).select(id);
                      },
                    );
                    if (!wide) {
                      return list;
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: _listPaneWidth, child: list),
                        const SizedBox(width: 24),
                        Expanded(
                          child: selectedCustomer == null
                              ? const _SelectPrompt()
                              : ClientDetailPane(
                                  customer: selectedCustomer,
                                  onEdit: () => _editCustomer(selectedCustomer),
                                  onArchive: () =>
                                      _archiveCustomer(selectedCustomer),
                                  onRestore: () =>
                                      _restoreCustomer(selectedCustomer),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClientsHeader extends StatelessWidget {
  const _ClientsHeader({
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onCreate,
  });

  final TextEditingController controller;
  final CustomerStatusFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CustomerStatusFilter> onFilterChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              clientsPageTitle,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: AppColors.onForest,
              ),
              icon: const Icon(Icons.add),
              label: const Text(clientsNewCustomer),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Semantics(
          textField: true,
          label: clientsSearchSemanticsLabel,
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onQueryChanged,
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
        _FilterToggle(filter: filter, onChanged: onFilterChanged),
      ],
    );
  }
}

class _ClientsList extends StatelessWidget {
  const _ClientsList({
    required this.customers,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Customer> customers;
  final CustomerId? selectedId;
  final ValueChanged<CustomerId> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _ClientRow(
          customer: customer,
          selected: customer.id == selectedId,
          onSelect: () => onSelect(customer.id),
        );
      },
    );
  }
}

class _SelectPrompt extends StatelessWidget {
  const _SelectPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        clientsSelectPrompt,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.muted,
        ),
        textAlign: TextAlign.center,
      ),
    );
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
