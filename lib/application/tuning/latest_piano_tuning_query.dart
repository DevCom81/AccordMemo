import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/shared/calendar_date.dart';

abstract interface class LatestPianoTuningQuery {
  Future<Map<PianoId, CalendarDate>> findLatestDatesByCustomerId(
    CustomerId customerId,
  );
}
