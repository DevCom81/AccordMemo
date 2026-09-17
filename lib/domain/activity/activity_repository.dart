import '../customer/customer.dart';
import '../piano/piano.dart';
import 'activity.dart';

abstract interface class ActivityRepository {
  Future<void> insert(Activity activity);

  Future<List<Activity>> findRecent({required int limit});

  Future<List<Activity>> findByPianoId({
    required PianoId pianoId,
    required int limit,
  });

  Future<List<Activity>> findByCustomerId({
    required CustomerId customerId,
    required int limit,
  });
}

void requirePositiveActivityLimit(int limit) {
  if (limit <= 0) {
    throw ActivityLimitInvalid(limit);
  }
}
