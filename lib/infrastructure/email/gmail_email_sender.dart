import 'dart:convert';
import 'dart:io';

import 'package:googleapis/gmail/v1.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart';

import '../../application/ports/email_sender.dart';
import '../../application/ports/google_auth_session.dart';
import '../google/google_apis_auth_session.dart';

final class GmailEmailSender implements EmailSender {
  GmailEmailSender(this._session);

  final GoogleApisAuthSession _session;

  @override
  Future<SentEmailReceipt> send(OutgoingEmail email) async {
    late final AuthClient client;
    try {
      client = await _session.authorizedClient();
    } on GoogleSessionDisconnected {
      rethrow;
    } on GoogleAuthException {
      throw const EmailSendFailed(EmailSendFailureKind.authentication);
    }

    try {
      final from = await _session.senderAddress();
      final api = GmailApi(client);
      final sent = await api.users.messages.send(
        Message(raw: encodeGmailRawMessage(
          from: from,
          to: email.to,
          subject: email.subject,
          body: email.body,
          htmlBody: email.htmlBody,
        )),
        'me',
      );
      return SentEmailReceipt(providerMessageId: sent.id);
    } on AccessDeniedException {
      throw const EmailSendFailed(EmailSendFailureKind.authentication);
    } on SocketException {
      throw const EmailSendFailed(EmailSendFailureKind.network);
    } on ClientException {
      throw const EmailSendFailed(EmailSendFailureKind.network);
    } on GoogleSessionDisconnected {
      throw const EmailSendFailed(EmailSendFailureKind.authentication);
    } catch (_) {
      throw const EmailSendFailed(EmailSendFailureKind.unavailable);
    } finally {
      client.close();
    }
  }
}

const gmailAlternativeBoundary = 'accord_memo_alt';

String encodeGmailRawMessage({
  required String from,
  required String to,
  required String subject,
  required String body,
  String? htmlBody,
}) {
  final encodedSubject =
      '=?utf-8?B?${base64.encode(utf8.encode(subject))}?=';
  final headers = 'From: $from\r\n'
      'To: $to\r\n'
      'Subject: $encodedSubject\r\n'
      'MIME-Version: 1.0\r\n';
  final rfc2822 = htmlBody == null
      ? '$headers'
          'Content-Type: text/plain; charset=utf-8\r\n'
          'Content-Transfer-Encoding: base64\r\n'
          '\r\n'
          '${base64.encode(utf8.encode(body))}'
      : '$headers'
          'Content-Type: multipart/alternative; boundary="$gmailAlternativeBoundary"\r\n'
          '\r\n'
          '--$gmailAlternativeBoundary\r\n'
          'Content-Type: text/plain; charset=utf-8\r\n'
          'Content-Transfer-Encoding: base64\r\n'
          '\r\n'
          '${base64.encode(utf8.encode(body))}\r\n'
          '--$gmailAlternativeBoundary\r\n'
          'Content-Type: text/html; charset=utf-8\r\n'
          'Content-Transfer-Encoding: base64\r\n'
          '\r\n'
          '${base64.encode(utf8.encode(htmlBody))}\r\n'
          '--$gmailAlternativeBoundary--';
  return base64Url.encode(utf8.encode(rfc2822)).replaceAll('=', '');
}
