import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import 'clients_strings.dart';

String pianoMutationMessage(Object error) {
  if (error is PianoIdentificationRequired) {
    return clientsPianoIdentificationRequired;
  }
  if (error is PianoReminderIntervalOutOfRange) {
    return clientsPianoIntervalInvalid;
  }
  if (error is PianoArchivedNotModifiable) {
    return clientsPianoArchivedNotModifiable;
  }
  if (error is PianoAlreadyArchived) {
    return clientsPianoAlreadyArchived;
  }
  if (error is PianoNotArchived) {
    return clientsPianoNotArchived;
  }
  if (error is PianoNotFound) {
    return clientsPianoNotFound;
  }
  if (error is PianoCustomerArchived) {
    return clientsPianoCustomerArchived;
  }
  if (error is CustomerNotFound) {
    return clientsNotFound;
  }
  return clientsPianoMutationGenericError;
}
