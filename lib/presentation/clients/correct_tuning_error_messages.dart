import '../../domain/piano/piano.dart';
import '../../domain/tuning/tuning.dart';
import 'clients_strings.dart';

String correctTuningMessage(Object error) {
  if (error is TuningDateInFuture) {
    return clientsTuningDateInFuture;
  }
  if (error is TuningNotFound) {
    return clientsTuningNotFound;
  }
  if (error is PianoNotFound) {
    return clientsPianoNotFound;
  }
  return clientsCorrectTuningGenericError;
}
