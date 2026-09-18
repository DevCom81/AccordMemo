final class OutgoingEmail {
  const OutgoingEmail({
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;
}

final class SentEmailReceipt {
  const SentEmailReceipt({this.providerMessageId});

  final String? providerMessageId;
}

enum EmailSendFailureKind { network, authentication, refused, unavailable }

final class EmailSendFailed implements Exception {
  const EmailSendFailed(this.kind);

  final EmailSendFailureKind kind;

  @override
  String toString() => 'EmailSendFailed($kind)';
}

abstract interface class EmailSender {
  Future<SentEmailReceipt> send(OutgoingEmail email);
}
