import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_status.dart';
import '../ports/email_sender.dart';
import '../ports/google_auth_session.dart';
import 'recipient_email.dart';
import 'reminder_email_composer.dart';
import 'reminder_service.dart';
import 'send_reminder_exceptions.dart';

final class SendReminderPreview {
  const SendReminderPreview({
    required this.reminderId,
    required this.recipient,
    required this.subject,
    required this.body,
  });

  final ReminderId reminderId;
  final String recipient;
  final String subject;
  final String body;
}

final class SendReminder {
  SendReminder({
    required this._reminders,
    required this._pianos,
    required this._customers,
    required this._googleAuth,
    required this._emailSender,
    this._composer = const ReminderEmailComposer(),
  });

  final ReminderService _reminders;
  final PianoRepository _pianos;
  final CustomerRepository _customers;
  final GoogleAuthSession _googleAuth;
  final EmailSender _emailSender;
  final ReminderEmailComposer _composer;

  Future<SendReminderPreview> preview(ReminderId id) async {
    final prepared = await _prepare(id);
    return SendReminderPreview(
      reminderId: id,
      recipient: prepared.email.value,
      subject: prepared.message.subject,
      body: prepared.message.body,
    );
  }

  Future<Reminder> execute(ReminderId id) async {
    final prepared = await _prepare(id);
    late final SentEmailReceipt receipt;
    try {
      receipt = await _emailSender.send(prepared.message);
    } on EmailSendFailed catch (error) {
      throw ReminderEmailSendRejected(error.kind);
    }

    try {
      return await _reminders.markSent(id);
    } on ReminderAlreadySent {
      final current = await _reminders.getById(id);
      if (current == null) {
        throw ReminderNotFound(id);
      }
      return current;
    } catch (_) {
      throw ReminderEmailSentButNotRecorded(
        reminderId: id,
        providerMessageId: receipt.providerMessageId,
      );
    }
  }

  Future<({OutgoingEmail message, RecipientEmail email})> _prepare(
    ReminderId id,
  ) async {
    final reminder = await _requireScheduled(id);
    final piano = await _requirePiano(reminder.pianoId);
    final customer = await _requireCustomer(piano.customerId);
    final email = _requireRecipient(customer.email);
    final google = await _googleAuth.currentState();
    if (!google.isConnected) {
      throw const GoogleSessionDisconnected();
    }
    final message = _composer.compose(to: email.value, dueDate: reminder.dueDate);
    return (message: message, email: email);
  }

  Future<Reminder> _requireScheduled(ReminderId id) async {
    final reminder = await _reminders.getById(id);
    if (reminder == null) {
      throw ReminderNotFound(id);
    }
    switch (reminder.status) {
      case ReminderStatus.scheduled:
        return reminder;
      case ReminderStatus.sent:
        throw const ReminderAlreadySent();
      case ReminderStatus.cancelled:
        throw const ReminderAlreadyCancelled();
    }
  }

  Future<Piano> _requirePiano(PianoId id) async {
    final piano = await _pianos.findById(id);
    if (piano == null) {
      throw PianoNotFound(id);
    }
    return piano;
  }

  Future<Customer> _requireCustomer(CustomerId id) async {
    final customer = await _customers.findById(id);
    if (customer == null) {
      throw CustomerNotFound(id);
    }
    return customer;
  }

  RecipientEmail _requireRecipient(String? raw) {
    if (RecipientEmail.isBlank(raw)) {
      throw const ReminderEmailMissing();
    }
    final email = RecipientEmail.tryParse(raw);
    if (email == null) {
      throw const ReminderEmailInvalid();
    }
    return email;
  }
}
