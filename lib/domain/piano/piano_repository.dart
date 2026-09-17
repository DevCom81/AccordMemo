import '../customer/customer.dart';
import 'piano.dart';

enum PianoStatusFilter { active, archived }

abstract interface class PianoRepository {
  Future<Piano?> findById(PianoId id);

  Future<void> insert(Piano piano);

  Future<void> update(Piano piano);

  Future<List<Piano>> findByCustomerId({
    required CustomerId customerId,
    required PianoStatusFilter filter,
  });
}
