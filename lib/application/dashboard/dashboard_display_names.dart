import '../../domain/piano/piano_type.dart';

String formatDashboardCustomerName({
  required String lastName,
  String? firstName,
}) {
  if (firstName == null) {
    return lastName;
  }
  return '$firstName $lastName';
}

String formatDashboardPianoName({
  String? brand,
  String? model,
  PianoType? type,
}) {
  if (brand != null && model != null) {
    return '$brand $model';
  }
  if (brand != null) {
    return brand;
  }
  if (model != null) {
    return model;
  }
  return switch (type) {
    PianoType.droit => 'Piano droit',
    PianoType.queue => 'Piano à queue',
    null => '',
  };
}

String dashboardCustomerInitials({
  required String lastName,
  String? firstName,
}) {
  if (firstName != null && firstName.isNotEmpty) {
    return '${firstName[0]}${lastName[0]}'.toUpperCase();
  }
  if (lastName.length >= 2) {
    return lastName.substring(0, 2).toUpperCase();
  }
  return lastName.toUpperCase();
}
