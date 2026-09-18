import 'dart:convert';

import 'package:accord_memo/application/reminder/reminder_email_composer.dart';
import 'package:accord_memo/infrastructure/email/gmail_email_sender.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sans htmlBody conserve un message text/plain UTF-8', () {
    final raw = encodeGmailRawMessage(
      from: 'eleonore@example.com',
      to: 'jean@example.com',
      subject: reminderEmailSubject,
      body: 'Éléonore\nPianos d’Occitanie',
    );
    final rfc2822 = _decodeGmailRaw(raw);

    expect(rfc2822, contains('MIME-Version: 1.0'));
    expect(
      rfc2822,
      contains('Subject: =?utf-8?B?${base64.encode(utf8.encode(reminderEmailSubject))}?='),
    );
    expect(rfc2822, contains('Content-Type: text/plain; charset=utf-8'));
    expect(rfc2822, contains('Content-Transfer-Encoding: base64'));
    expect(rfc2822, isNot(contains('multipart/alternative')));
    expect(rfc2822, isNot(contains('text/html')));
    expect(
      rfc2822,
      contains(base64.encode(utf8.encode('Éléonore\nPianos d’Occitanie'))),
    );
  });

  test('avec htmlBody émet multipart/alternative texte + HTML', () {
    const plain =
        '$reminderCallbackLabel :\n$reminderCallbackUrl';
    const html =
        '<a href="$reminderCallbackUrl">$reminderCallbackLabel</a>';
    final raw = encodeGmailRawMessage(
      from: 'eleonore@example.com',
      to: 'jean@example.com',
      subject: reminderEmailSubject,
      body: plain,
      htmlBody: html,
    );
    final rfc2822 = _decodeGmailRaw(raw);

    expect(
      rfc2822,
      contains(
        'Content-Type: multipart/alternative; boundary="$gmailAlternativeBoundary"',
      ),
    );
    expect(rfc2822, contains('Content-Type: text/plain; charset=utf-8'));
    expect(rfc2822, contains('Content-Type: text/html; charset=utf-8'));
    expect(
      rfc2822,
      contains('Subject: =?utf-8?B?${base64.encode(utf8.encode(reminderEmailSubject))}?='),
    );
    expect(rfc2822, contains(base64.encode(utf8.encode(plain))));
    expect(rfc2822, contains(base64.encode(utf8.encode(html))));
    expect(rfc2822.contains('?customer'), isFalse);
    expect(html.contains('?'), isFalse);
  });
}

String _decodeGmailRaw(String raw) {
  final remainder = raw.length % 4;
  final padded = remainder == 0 ? raw : raw.padRight(raw.length + (4 - remainder), '=');
  return utf8.decode(base64Url.decode(padded));
}
