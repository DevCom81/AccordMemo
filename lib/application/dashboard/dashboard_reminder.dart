import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/shared/calendar_date.dart';

/// Projection dashboard. Ce n'est pas une entité du domaine.
final class DashboardReminder {
  const DashboardReminder({
    required this.reminderId,
    required this.pianoId,
    required this.customerId,
    required this.dueDate,
    required this.lastName,
    this.firstName,
    this.city,
    this.brand,
    this.model,
    this.type,
  });

  final ReminderId reminderId;
  final PianoId pianoId;
  final CustomerId customerId;
  final CalendarDate dueDate;
  final String lastName;
  final String? firstName;
  final String? city;
  final String? brand;
  final String? model;
  final PianoType? type;
}
