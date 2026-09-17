import '../piano/piano.dart';
import '../shared/calendar_date.dart';
import '../tuning/tuning.dart';
import 'reminder_cancellation_reason.dart';
import 'reminder_status.dart';

final class ReminderId {
  const ReminderId._(this.value);

  factory ReminderId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const ReminderIdInvalid();
    }
    return ReminderId._(value);
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      other is ReminderId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

sealed class ReminderException implements Exception {
  const ReminderException();
}

final class ReminderIdInvalid extends ReminderException {
  const ReminderIdInvalid();

  @override
  String toString() => 'ReminderIdInvalid';
}

final class ReminderDueDateInPast extends ReminderException {
  const ReminderDueDateInPast({required this.dueDate, required this.today});

  final CalendarDate dueDate;
  final CalendarDate today;

  @override
  String toString() => 'ReminderDueDateInPast($dueDate, today: $today)';
}

final class ReminderAlreadySent extends ReminderException {
  const ReminderAlreadySent();

  @override
  String toString() => 'ReminderAlreadySent';
}

final class ReminderAlreadyCancelled extends ReminderException {
  const ReminderAlreadyCancelled();

  @override
  String toString() => 'ReminderAlreadyCancelled';
}

final class ReminderManuallyRescheduled extends ReminderException {
  const ReminderManuallyRescheduled();

  @override
  String toString() => 'ReminderManuallyRescheduled';
}

final class ReminderNotFound extends ReminderException {
  const ReminderNotFound(this.id);

  final ReminderId id;

  @override
  String toString() => 'ReminderNotFound($id)';
}

final class Reminder {
  const Reminder._({
    required this.id,
    required this.pianoId,
    required this.originTuningId,
    required this.dueDate,
    required this.status,
    required this.manuallyRescheduled,
    required this.cancellationReason,
    required this.sentAt,
    required this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reminder.schedule({
    required ReminderId id,
    required PianoId pianoId,
    required TuningId originTuningId,
    required CalendarDate dueDate,
    required DateTime now,
  }) {
    return Reminder._(
      id: id,
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: dueDate,
      status: ReminderStatus.scheduled,
      manuallyRescheduled: false,
      cancellationReason: null,
      sentAt: null,
      cancelledAt: null,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  }

  /// Hydratation depuis la persistance. Ne pas utiliser pour modifier une relance.
  factory Reminder.reconstitute({
    required ReminderId id,
    required PianoId pianoId,
    required TuningId originTuningId,
    required CalendarDate dueDate,
    required ReminderStatus status,
    required bool manuallyRescheduled,
    ReminderCancellationReason? cancellationReason,
    DateTime? sentAt,
    DateTime? cancelledAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Reminder._(
      id: id,
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: dueDate,
      status: status,
      manuallyRescheduled: manuallyRescheduled,
      cancellationReason: cancellationReason,
      sentAt: sentAt?.toUtc(),
      cancelledAt: cancelledAt?.toUtc(),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }

  final ReminderId id;
  final PianoId pianoId;
  final TuningId originTuningId;
  final CalendarDate dueDate;
  final ReminderStatus status;
  final bool manuallyRescheduled;
  final ReminderCancellationReason? cancellationReason;
  final DateTime? sentAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder reschedule({
    required CalendarDate newDueDate,
    required CalendarDate today,
    required DateTime now,
  }) {
    _assertScheduled();
    if (newDueDate < today) {
      throw ReminderDueDateInPast(dueDate: newDueDate, today: today);
    }

    return Reminder._(
      id: id,
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: newDueDate,
      status: ReminderStatus.scheduled,
      manuallyRescheduled: true,
      cancellationReason: null,
      sentAt: null,
      cancelledAt: null,
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  Reminder markSent(DateTime now) {
    _assertScheduled();
    final instant = now.toUtc();
    return Reminder._(
      id: id,
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: dueDate,
      status: ReminderStatus.sent,
      manuallyRescheduled: manuallyRescheduled,
      cancellationReason: null,
      sentAt: instant,
      cancelledAt: null,
      createdAt: createdAt,
      updatedAt: instant,
    );
  }

  Reminder cancel({
    required ReminderCancellationReason reason,
    required DateTime now,
  }) {
    _assertScheduled();
    final instant = now.toUtc();
    return Reminder._(
      id: id,
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: dueDate,
      status: ReminderStatus.cancelled,
      manuallyRescheduled: manuallyRescheduled,
      cancellationReason: reason,
      sentAt: null,
      cancelledAt: instant,
      createdAt: createdAt,
      updatedAt: instant,
    );
  }

  Reminder recalculateAutomaticDueDate({
    required CalendarDate dueDate,
    required DateTime now,
  }) {
    _assertScheduled();
    if (manuallyRescheduled) {
      throw const ReminderManuallyRescheduled();
    }

    return Reminder._(
      id: id,
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: dueDate,
      status: ReminderStatus.scheduled,
      manuallyRescheduled: false,
      cancellationReason: null,
      sentAt: null,
      cancelledAt: null,
      createdAt: createdAt,
      updatedAt: now.toUtc(),
    );
  }

  void _assertScheduled() {
    switch (status) {
      case ReminderStatus.scheduled:
        return;
      case ReminderStatus.sent:
        throw const ReminderAlreadySent();
      case ReminderStatus.cancelled:
        throw const ReminderAlreadyCancelled();
    }
  }

  @override
  bool operator ==(Object other) => other is Reminder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
