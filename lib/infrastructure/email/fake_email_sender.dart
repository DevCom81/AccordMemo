import '../../application/ports/email_sender.dart';

final class FakeEmailSender implements EmailSender {
  FakeEmailSender({this.error});

  Object? error;
  final List<OutgoingEmail> sent = [];

  @override
  Future<SentEmailReceipt> send(OutgoingEmail email) async {
    sent.add(email);
    if (error != null) {
      throw error!;
    }
    return SentEmailReceipt(
      providerMessageId: 'fake-${sent.length}',
    );
  }
}
