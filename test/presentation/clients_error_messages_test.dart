import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/presentation/clients/clients_error_messages.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mappe les erreurs CustomerService sans détail technique', () {
    expect(
      customerMutationMessage(const CustomerLastNameRequired()),
      clientsLastNameRequired,
    );
    expect(
      customerMutationMessage(const CustomerArchivedNotModifiable()),
      clientsArchivedNotModifiable,
    );
    expect(
      customerMutationMessage(const CustomerAlreadyArchived()),
      clientsAlreadyArchived,
    );
    expect(
      customerMutationMessage(const CustomerNotArchived()),
      clientsNotArchived,
    );
    expect(
      customerMutationMessage(CustomerNotFound(CustomerId('c1'))),
      clientsNotFound,
    );
    expect(
      customerMutationMessage(Exception('SQLite constraint failed')),
      clientsMutationGenericError,
    );
  });
}
