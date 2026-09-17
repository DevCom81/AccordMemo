import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';

final class InMemoryPianoRepository implements PianoRepository {
  final Map<String, Piano> _pianos = {};

  @override
  Future<Piano?> findById(PianoId id) async {
    return _pianos[id.value];
  }

  @override
  Future<void> insert(Piano piano) async {
    _pianos[piano.id.value] = piano;
  }

  @override
  Future<void> update(Piano piano) async {
    if (!_pianos.containsKey(piano.id.value)) {
      throw PianoNotFound(piano.id);
    }
    _pianos[piano.id.value] = piano;
  }

  @override
  Future<List<Piano>> findByCustomerId({
    required CustomerId customerId,
    required PianoStatusFilter filter,
  }) async {
    final archived = filter == PianoStatusFilter.archived;
    final matches = _pianos.values.where((piano) {
      return piano.customerId == customerId && piano.isArchived == archived;
    }).toList();
    matches.sort((a, b) {
      final brand = (a.brand ?? '').compareTo(b.brand ?? '');
      if (brand != 0) {
        return brand;
      }
      return (a.model ?? '').compareTo(b.model ?? '');
    });
    return matches;
  }
}
