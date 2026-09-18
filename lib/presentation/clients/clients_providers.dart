import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../app_providers.dart';

const clientsSearchDebounce = Duration(milliseconds: 300);

final clientsFilterProvider =
    NotifierProvider<ClientsFilter, CustomerStatusFilter>(ClientsFilter.new);

final clientsQueryProvider =
    NotifierProvider<ClientsQuery, String>(ClientsQuery.new);

final selectedCustomerIdProvider =
    NotifierProvider<SelectedCustomerId, CustomerId?>(SelectedCustomerId.new);

final clientsSearchProvider = FutureProvider<List<Customer>>((ref) {
  final filter = ref.watch(clientsFilterProvider);
  final query = ref.watch(clientsQueryProvider);
  return ref.watch(customerServiceProvider).search(
    filter: filter,
    query: query,
  );
});

final class ClientsFilter extends Notifier<CustomerStatusFilter> {
  @override
  CustomerStatusFilter build() => CustomerStatusFilter.active;

  void setFilter(CustomerStatusFilter filter) {
    if (state == filter) {
      return;
    }
    state = filter;
    ref.read(selectedCustomerIdProvider.notifier).clear();
  }
}

final class ClientsQuery extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return '';
  }

  void schedule(String raw) {
    _debounce?.cancel();
    _debounce = Timer(clientsSearchDebounce, () {
      final next = raw.trim();
      if (state != next) {
        state = next;
      }
    });
  }
}

final class SelectedCustomerId extends Notifier<CustomerId?> {
  @override
  CustomerId? build() => null;

  void select(CustomerId id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}
