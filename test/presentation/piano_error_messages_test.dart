import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/piano_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mappe les erreurs PianoService sans détail technique', () {
    expect(
      pianoMutationMessage(const PianoIdentificationRequired()),
      clientsPianoIdentificationRequired,
    );
    expect(
      pianoMutationMessage(const PianoReminderIntervalOutOfRange(0)),
      clientsPianoIntervalInvalid,
    );
    expect(
      pianoMutationMessage(const PianoArchivedNotModifiable()),
      clientsPianoArchivedNotModifiable,
    );
    expect(
      pianoMutationMessage(const PianoAlreadyArchived()),
      clientsPianoAlreadyArchived,
    );
    expect(
      pianoMutationMessage(const PianoNotArchived()),
      clientsPianoNotArchived,
    );
    expect(
      pianoMutationMessage(PianoNotFound(PianoId('p1'))),
      clientsPianoNotFound,
    );
    expect(
      pianoMutationMessage(PianoCustomerArchived(CustomerId('c1'))),
      clientsPianoCustomerArchived,
    );
    expect(
      pianoMutationMessage(CustomerNotFound(CustomerId('c1'))),
      clientsNotFound,
    );
    expect(
      pianoMutationMessage(Exception('SQLite constraint failed')),
      clientsPianoMutationGenericError,
    );
  });
}
