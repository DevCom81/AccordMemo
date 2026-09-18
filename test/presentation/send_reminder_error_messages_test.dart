import 'package:accord_memo/application/ports/email_sender.dart';
import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/application/reminder/send_reminder_exceptions.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/presentation/dashboard/dashboard_strings.dart';
import 'package:accord_memo/presentation/dashboard/send_reminder_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mappe les erreurs d’envoi sans détail technique', () {
    expect(
      sendReminderMessage(const ReminderEmailMissing()),
      dashboardSendReminderMissingEmail,
    );
    expect(
      sendReminderMessage(const ReminderEmailInvalid()),
      dashboardSendReminderInvalidEmail,
    );
    expect(
      sendReminderMessage(const GoogleSessionDisconnected()),
      dashboardSendReminderGoogleDisconnected,
    );
    expect(
      sendReminderMessage(
        const ReminderEmailSendRejected(EmailSendFailureKind.authentication),
      ),
      dashboardSendReminderAuthError,
    );
    expect(
      sendReminderMessage(
        const ReminderEmailSendRejected(EmailSendFailureKind.network),
      ),
      dashboardSendReminderNetworkError,
    );
    expect(
      sendReminderMessage(
        ReminderEmailSentButNotRecorded(reminderId: ReminderId('r1')),
      ),
      dashboardSendReminderSentButNotRecorded,
    );
    expect(
      sendReminderMessage(Exception('Gmail 401 token=ya29.secret')),
      dashboardSendReminderGenericError,
    );
    expect(
      sendReminderMessage(Exception('Gmail 401 token=ya29.secret')),
      isNot(contains('ya29')),
    );
  });
}
