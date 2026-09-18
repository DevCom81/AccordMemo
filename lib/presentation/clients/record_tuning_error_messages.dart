import '../../domain/piano/piano.dart';
import '../../domain/tuning/tuning.dart';
import 'clients_strings.dart';

String recordTuningMessage(Object error) {
  if (error is TuningDateInFuture) {
    return clientsTuningDateInFuture;
  }
  if (error is PianoNotFound) {
    return clientsPianoNotFound;
  }
  return clientsRecordTuningGenericError;
}
