import '../../domain/reminder/reminder.dart';
import '../ports/email_sender.dart';

sealed class SendReminderException implements Exception {
  const SendReminderException();
}

final class ReminderEmailMissing extends SendReminderException {
  const ReminderEmailMissing();

  @override
  String toString() => 'ReminderEmailMissing';
}

final class ReminderEmailInvalid extends SendReminderException {
  const ReminderEmailInvalid();

  @override
  String toString() => 'ReminderEmailInvalid';
}

final class ReminderEmailSentButNotRecorded extends SendReminderException {
  const ReminderEmailSentButNotRecorded({
    required this.reminderId,
    this.providerMessageId,
  });

  final ReminderId reminderId;
  final String? providerMessageId;

  @override
  String toString() => 'ReminderEmailSentButNotRecorded($reminderId)';
}

final class ReminderEmailSendRejected extends SendReminderException {
  const ReminderEmailSendRejected(this.kind);

  final EmailSendFailureKind kind;

  @override
  String toString() => 'ReminderEmailSendRejected($kind)';
}
