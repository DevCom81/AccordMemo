import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_memo/application/ports/email_sender.dart';
import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/application/reminder/reminder_email_composer.dart';
import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/application/reminder/send_reminder.dart';
import 'package:accord_memo/application/reminder/send_reminder_exceptions.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/email/gmail_email_sender.dart';
import 'package:accord_memo/infrastructure/google/android_google_sign_in.dart';
import 'package:accord_memo/infrastructure/google/google_android_auth_session.dart';
import 'package:accord_memo/infrastructure/google/google_apis_auth_session.dart';
import 'package:accord_memo/infrastructure/google/google_authorized_session.dart';
import 'package:accord_memo/infrastructure/google/google_oauth_desktop_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/immediate_transaction_runner.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_customer_repository.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';
import '../support/in_memory_secret_store.dart';

final _now = DateTime.utc(2026, 9, 30);
final _due = CalendarDate(2026, 10, 1);
final _id = ReminderId('reminder-test');

/// Les seules frontières simulées sont Google natif, HTTP et les repositories.
/// Sessions, GmailEmailSender, SendReminder et ReminderService restent réels.
final class _World {
  final native = _Native();
  final store = InMemorySecretStore();
  final customers = InMemoryCustomerRepository();
  final pianos = InMemoryPianoRepository();
  final reminders = InMemoryReminderRepository();
  late final activities = InMemoryActivityRepository(pianos);
  final requests = <http.Request>[];
  late GoogleAuthorizedSession session;
  late SendReminder useCase;
  Future<http.Response> Function(http.Request) respond = (_) async =>
      http.Response(
        '{"id":"gmail-message-test"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Future<void> initialize({required bool android}) async {
    final customer = Customer.create(
      id: CustomerId('customer-test'),
      lastName: 'Client de recette',
      email: 'recipient@example.com',
      now: _now,
    );
    final piano = Piano.create(
      id: PianoId('piano-test'),
      customerId: customer.id,
      brand: 'Piano de recette',
      now: _now,
    );
    await customers.insert(customer);
    await pianos.insert(piano);
    await reminders.insert(Reminder.schedule(
      id: _id,
      pianoId: piano.id,
      originTuningId: TuningId('tuning-test'),
      dueDate: _due,
      now: _now,
    ));

    http.Client transport() => MockClient((request) async {
      requests.add(request);
      return respond(request);
    });

    if (android) {
      session = GoogleAndroidAuthSession(
        signIn: native,
        store: store,
        serverClientId: 'test-only-web-client',
        clientFactory: transport,
      );
      await session.connect();
    } else {
      await store.write(googleRefreshTokenStorageKey, 'test-refresh-token');
      await store.write(googleAccountEmailStorageKey, native.account.email);
      session = GoogleApisAuthSession(
        desktopClient: const GoogleOAuthDesktopClient(
          clientId: 'test-only-desktop-client',
          clientSecret: 'test-only-desktop-secret',
        ),
        store: store,
        obtainConsent: ({required clientId, required scopes, required prompt}) {
          throw StateError('Aucun nouveau consentement Desktop attendu.');
        },
        openRefreshClient: ({required clientId, required refreshToken,
          required scopes}) async {
          expect(clientId.identifier, 'test-only-desktop-client');
          expect(refreshToken, 'test-refresh-token');
          expect(scopes, googleMailSendScopes);
          return authenticatedClient(
            transport(),
            AccessCredentials(
              AccessToken('Bearer', 'desktop-access-token', DateTime.utc(2100)),
              refreshToken,
              scopes,
            ),
            closeUnderlyingClient: true,
          );
        },
      );
    }
    useCase = SendReminder(
      reminders: ReminderService(
        clock: FixedClock(_now),
        idGenerator: FakeIdGenerator(spareIds()),
        transactions: const ImmediateTransactionRunner(),
        reminders: reminders,
        activities: activities,
      ),
      pianos: pianos,
      customers: customers,
      googleAuth: session,
      emailSender: GmailEmailSender(session),
    );
  }

  Future<void> expectUnsent() async {
    expect((await reminders.findById(_id))!.status, ReminderStatus.scheduled);
    expect(await activities.findRecent(limit: 10), isEmpty);
  }
}

final class _Native implements AndroidGoogleSignIn {
  final account = _Account();
  Object? authenticationError;

  @override
  Future<void> initialize() async {}

  @override
  Future<AndroidGoogleAccount> authenticate() async {
    if (authenticationError != null) {
      throw authenticationError!;
    }
    return account;
  }

  @override
  Future<AndroidGoogleAccount?> restore() async => account;

  @override
  Future<void> signOut() async {}
}

final class _Account implements AndroidGoogleAccount {
  @override
  String get id => 'google-account-test';
  @override
  String get email => 'sender@example.com';
  final clearedTokens = <String>[];
  Object? authorizationError;
  bool failInvalidation = false;

  @override
  Future<String?> accessToken(List<String> scopes, {
    required bool interactive,
  }) async {
    expect(scopes, [
      'openid',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/gmail.send',
    ]);
    if (authorizationError != null) {
      throw authorizationError!;
    }
    return 'android-access-token';
  }

  @override
  Future<void> clearToken(String token) async {
    clearedTokens.add(token);
    if (failInvalidation) {
      throw StateError('SDK indisponible');
    }
  }
}

void main() {
  for (final android in [true, false]) {
    group(android ? 'Android' : 'Desktop', () {
      late _World world;
      setUp(() async {
        world = _World();
        await world.initialize(android: android);
      });

      test('preview sans HTTP ; succès Gmail avant markSent', () async {
        final preview = await world.useCase.preview(_id);
        expect(preview.recipient, 'recipient@example.com');
        expect(world.requests, isEmpty);
        await world.expectUnsent();

        final started = Completer<void>();
        final response = Completer<http.Response>();
        world.respond = (_) {
          started.complete();
          return response.future;
        };
        final sending = world.useCase.execute(_id);
        await started.future;
        await world.expectUnsent();
        response.complete(http.Response(
          '{"id":"gmail-message-test"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
        expect((await sending).status, ReminderStatus.sent);
        final journal = await world.activities.findRecent(limit: 10);
        expect(journal.single.type, ActivityType.reminderSent);
        final request = world.requests.single;
        expect(request.method, 'POST');
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'gmail.googleapis.com');
        expect(request.url.path, '/gmail/v1/users/me/messages/send');
        expect(request.headers['Authorization'],
            'Bearer ${android ? 'android' : 'desktop'}-access-token');
      });

      for (final status in [401, 403, 429, 500, 503]) {
        test('HTTP $status : une tentative, aucun markSent', () async {
          world.respond = (_) async => http.Response(
            jsonEncode({'error': {'code': status, 'message': 'Google error'}}),
            status,
            headers: status == 401
                ? {'www-authenticate': 'Bearer error="invalid_token"'}
                : {},
          );
          await expectLater(world.useCase.execute(_id),
              throwsA(isA<ReminderEmailSendRejected>().having(
                (error) => error.kind,
                'kind',
                status == 401 ? EmailSendFailureKind.authentication
                    : EmailSendFailureKind.unavailable,
              )));
          expect(world.requests, hasLength(1));
          await world.expectUnsent();
          expect(world.native.account.clearedTokens,
              android && status == 401 ? ['android-access-token'] : isEmpty);
        });
      }

      for (final failure in <Object>[
        const SocketException('connexion interrompue'),
        http.ClientException('connexion interrompue'),
        StateError('résultat ambigu après émission'),
      ]) {
        test('${failure.runtimeType} : aucun rejeu ni markSent', () async {
          world.respond = (_) async => throw failure;
          await expectLater(world.useCase.execute(_id),
              throwsA(isA<ReminderEmailSendRejected>().having(
                (error) => error.kind,
                'kind',
                failure is SocketException || failure is http.ClientException
                    ? EmailSendFailureKind.network
                    : EmailSendFailureKind.unavailable,
              )));
          expect(world.requests, hasLength(1));
          await world.expectUnsent();
        });
      }

      test('réponse illisible : aucun rejeu ni markSent', () async {
        world.respond = (_) async => http.Response('JSON incomplet {', 200);
        await expectLater(world.useCase.execute(_id),
            throwsA(isA<ReminderEmailSendRejected>()));
        expect(world.requests, hasLength(1));
        await world.expectUnsent();
      });
    });
  }

  test('Android : annulation OAuth, aucun envoi', () async {
    final world = _World();
    await world.initialize(android: true);
    world.native.authenticationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    await expectLater(world.session.reconnect(),
        throwsA(isA<GoogleAuthorizationCancelled>()));
    await expectLater(world.useCase.execute(_id),
        throwsA(isA<GoogleSessionDisconnected>()));
    expect(world.requests, isEmpty);
    await world.expectUnsent();
  });

  test('Android : erreur OAuth avant HTTP, aucun envoi', () async {
    final world = _World();
    await world.initialize(android: true);
    world.native.account.authorizationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.unknownError,
    );
    await expectLater(world.useCase.execute(_id),
        throwsA(isA<GoogleAuthorizationFailed>()));
    expect(world.requests, isEmpty);
    await world.expectUnsent();
  });

  test('Android : invalidation 401 en échec, aucun rejeu ni markSent', () async {
    final world = _World();
    await world.initialize(android: true);
    world.native.account.failInvalidation = true;
    world.respond = (_) async => http.Response('', 401);
    await expectLater(world.useCase.execute(_id),
        throwsA(isA<ReminderEmailSendRejected>().having(
          (error) => error.kind, 'kind', EmailSendFailureKind.authentication,
        )));
    expect(world.native.account.clearedTokens, ['android-access-token']);
    expect(world.requests, hasLength(1));
    await world.expectUnsent();
  });

  test('Android et Desktop : payload MIME strictement identique', () async {
    final payloads = <String>[];
    for (final android in [true, false]) {
      final world = _World();
      await world.initialize(android: android);
      await world.useCase.execute(_id);
      final json = jsonDecode(world.requests.single.body) as Map<String, dynamic>;
      payloads.add(json['raw'] as String);
    }
    expect(payloads[0], payloads[1]);
    final mime = utf8.decode(base64Url.decode(base64Url.normalize(payloads[0])));
    expect(mime, contains('From: sender@example.com\r\n'));
    expect(mime, contains('To: recipient@example.com\r\n'));
    expect(mime, contains('multipart/alternative'));
    expect(mime, contains('Subject: =?utf-8?B?'
        '${base64.encode(utf8.encode(reminderEmailSubject))}?='));
    final parts = mime.split('--$gmailAlternativeBoundary');
    for (final type in ['text/plain', 'text/html']) {
      final part = parts.singleWhere((part) =>
          part.contains('Content-Type: $type; charset=utf-8'));
      final content = utf8.decode(base64.decode(part.split('\r\n\r\n')[1].trim()));
      expect(content, contains(reminderCallbackLabel));
      expect(content, contains(reminderCallbackUrl));
      if (type == 'text/html') {
        expect(content, contains('href="$reminderCallbackUrl"'));
      }
    }
  });
}
