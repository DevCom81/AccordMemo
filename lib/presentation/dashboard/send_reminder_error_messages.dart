import '../../application/ports/email_sender.dart';
import '../../application/ports/google_auth_session.dart';
import '../../application/reminder/send_reminder_exceptions.dart';
import '../../domain/customer/customer.dart';
import '../../domain/piano/piano.dart';
import '../../domain/reminder/reminder.dart';
import 'dashboard_strings.dart';

String sendReminderMessage(Object error) {
  if (error is ReminderEmailMissing) {
    return dashboardSendReminderMissingEmail;
  }
  if (error is ReminderEmailInvalid) {
    return dashboardSendReminderInvalidEmail;
  }
  if (error is GoogleSessionDisconnected ||
      error is GoogleOAuthClientNotConfigured) {
    return dashboardSendReminderGoogleDisconnected;
  }
  if (error is GoogleAuthorizationFailed) {
    return dashboardSendReminderAuthError;
  }
  if (error is ReminderEmailSendRejected) {
    return switch (error.kind) {
      EmailSendFailureKind.authentication => dashboardSendReminderAuthError,
      EmailSendFailureKind.network => dashboardSendReminderNetworkError,
      EmailSendFailureKind.refused => dashboardSendReminderRefusedError,
      EmailSendFailureKind.unavailable => dashboardSendReminderUnavailableError,
    };
  }
  if (error is ReminderEmailSentButNotRecorded) {
    return dashboardSendReminderSentButNotRecorded;
  }
  if (error is ReminderNotFound ||
      error is ReminderAlreadySent ||
      error is ReminderAlreadyCancelled ||
      error is CustomerNotFound ||
      error is PianoNotFound) {
    return dashboardSendReminderNoLongerDue;
  }
  return dashboardSendReminderGenericError;
}

const dashboardSendReminderAuthError =
    'La connexion Gmail a expiré ou a été refusée. Reconnectez le compte dans Paramètres.';

const dashboardSendReminderNetworkError =
    'Impossible d’envoyer le rappel. Vérifiez la connexion internet.';

const dashboardSendReminderRefusedError =
    'L’envoi a été refusé. Vérifiez l’adresse du destinataire.';

const dashboardSendReminderUnavailableError =
    'Le service d’envoi est indisponible pour le moment.';

const dashboardSendReminderSentButNotRecorded =
    'Le message a bien été envoyé, mais AccordMémo n’a pas pu enregistrer le rappel. N’envoyez pas de nouveau message.';

const dashboardSendReminderNoLongerDue = 'Ce rappel n’est plus à traiter.';

const dashboardSendReminderGenericError = 'Impossible d’envoyer le rappel.';
