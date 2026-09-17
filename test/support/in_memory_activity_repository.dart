import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/activity/activity_repository.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';

final class InMemoryActivityRepository implements ActivityRepository {
  InMemoryActivityRepository(this._pianos);

  final PianoRepository _pianos;
  final List<Activity> _activities = [];

  @override
  Future<void> insert(Activity activity) async {
    _activities.add(activity);
  }

  @override
  Future<List<Activity>> findRecent({required int limit}) async {
    requirePositiveActivityLimit(limit);
    return _sorted.take(limit).toList();
  }

  @override
  Future<List<Activity>> findByPianoId({
    required PianoId pianoId,
    required int limit,
  }) async {
    requirePositiveActivityLimit(limit);
    return _sorted
        .where((activity) => activity.pianoId == pianoId)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Activity>> findByCustomerId({
    required CustomerId customerId,
    required int limit,
  }) async {
    requirePositiveActivityLimit(limit);
    final matches = <Activity>[];
    for (final activity in _sorted) {
      final piano = await _pianos.findById(activity.pianoId);
      if (piano?.customerId == customerId) {
        matches.add(activity);
      }
    }
    return matches.take(limit).toList();
  }

  List<Activity> get _sorted {
    final copy = [..._activities];
    copy.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return copy;
  }
}
