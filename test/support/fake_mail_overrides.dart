import 'package:accord_memo/infrastructure/email/fake_email_sender.dart';
import 'package:accord_memo/infrastructure/google/fake_google_auth_session.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:flutter_riverpod/misc.dart';

List<Override> fakeMailOverrides({
  FakeGoogleAuthSession? google,
  FakeEmailSender? emailSender,
}) {
  return [
    googleAuthSessionProvider.overrideWith(
      (ref) => google ?? FakeGoogleAuthSession.disconnected(),
    ),
    emailSenderProvider.overrideWith(
      (ref) => emailSender ?? FakeEmailSender(),
    ),
  ];
}
