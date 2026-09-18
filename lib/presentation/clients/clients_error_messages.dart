import '../../domain/customer/customer.dart';
import 'clients_strings.dart';

String customerMutationMessage(Object error) {
  if (error is CustomerLastNameRequired) {
    return clientsLastNameRequired;
  }
  if (error is CustomerArchivedNotModifiable) {
    return clientsArchivedNotModifiable;
  }
  if (error is CustomerAlreadyArchived) {
    return clientsAlreadyArchived;
  }
  if (error is CustomerNotArchived) {
    return clientsNotArchived;
  }
  if (error is CustomerNotFound) {
    return clientsNotFound;
  }
  return clientsMutationGenericError;
}
