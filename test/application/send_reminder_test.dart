import 'package:accord_memo/application/ports/email_sender.dart';
import 'package:accord_memo/application/ports/google_auth_session.dart';
import 'package:accord_memo/application/reminder/send_reminder.dart';
import 'package:accord_memo/application/reminder/send_reminder_exceptions.dart';
import 'package:accord_memo/application/reminder/reminder_service.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/reminder/reminder.dart';
import 'package:accord_memo/domain/reminder/reminder_repository.dart';
import 'package:accord_memo/domain/reminder/reminder_status.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/infrastructure/email/fake_email_sender.dart';
import 'package:accord_memo/infrastructure/google/fake_google_auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';
import '../support/immediate_transaction_runner.dart';
import '../support/in_memory_activity_repository.dart';
import '../support/in_memory_customer_repository.dart';
import '../support/in_memory_piano_repository.dart';
import '../support/in_memory_reminder_repository.dart';

final class _FailOnceReminders implements ReminderRepository {
  _FailOnceReminders(this._inner);

  final ReminderRepository _inner;
  var failNextUpdate = true;

  @override
  Future<Reminder?> findById(ReminderId id) => _inner.findById(id);

  @override
  Future<void> insert(Reminder reminder) => _inner.insert(reminder);

  @override
  Future<void> update(Reminder reminder) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('sqlite locked');
    }
    await _inner.update(reminder);
  }

  @override
  Future<Reminder?> findScheduledByPianoId(PianoId pianoId) {
    return _inner.findScheduledByPianoId(pianoId);
  }

  @override
  Future<Reminder?> findByOriginTuningId(TuningId originTuningId) {
    return _inner.findByOriginTuningId(originTuningId);
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);
  final dueDate = CalendarDate(2026, 10, 1);

  late InMemoryCustomerRepository customers;
  late InMemoryPianoRepository pianos;
  late ReminderRepository reminders;
  late InMemoryActivityRepository activities;
  late FakeEmailSender emailSender;
  late FakeGoogleAuthSession google;
  late ReminderService reminderService;
  late SendReminder sendReminder;

  Future<Reminder> seed({
    String? email = 'jean@example.com',
    ReminderStatus status = ReminderStatus.scheduled,
  }) async {
    final customer = Customer.create(
      id: CustomerId('customer-1'),
      lastName: 'Dupont',
      email: email,
      now: now,
    );
    await customers.insert(customer);
    final piano = Piano.create(
      id: PianoId('piano-1'),
      customerId: customer.id,
      brand: 'Yamaha',
      now: now,
    );
    await pianos.insert(piano);
    var reminder = Reminder.schedule(
      id: ReminderId('reminder-1'),
      pianoId: piano.id,
      originTuningId: TuningId('tuning-1'),
      dueDate: dueDate,
      now: now,
    );
    if (status == ReminderStatus.sent) {
      reminder = reminder.markSent(now);
    }
    await reminders.insert(reminder);
    return reminder;
  }

  SendReminder buildUseCase() {
    reminderService = ReminderService(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator(spareIds()),
      transactions: const ImmediateTransactionRunner(),
      reminders: reminders,
      activities: activities,
    );
    return SendReminder(
      reminders: reminderService,
      pianos: pianos,
      customers: customers,
      googleAuth: google,
      emailSender: emailSender,
    );
  }

  setUp(() {
    customers = InMemoryCustomerRepository();
    pianos = InMemoryPianoRepository();
    reminders = InMemoryReminderRepository();
    activities = InMemoryActivityRepository(pianos);
    emailSender = FakeEmailSender();
    google = FakeGoogleAuthSession.connected(accountEmail: 'eleonore@example.com');
    sendReminder = buildUseCase();
  });

  test('succès : un send, markSent et Activity reminderSent', () async {
    final created = await seed();
    final sent = await sendReminder.execute(created.id);

    expect(emailSender.sent, hasLength(1));
    expect(emailSender.sent.single.to, 'jean@example.com');
    expect(sent.status, ReminderStatus.sent);
    final journal = await activities.findRecent(limit: 10);
    expect(journal, hasLength(1));
    expect(journal.single.type, ActivityType.reminderSent);
  });

  test('email absent = 0 send', () async {
    final created = await seed(email: null);
    await expectLater(
      sendReminder.execute(created.id),
      throwsA(isA<ReminderEmailMissing>()),
    );
    expect(emailSender.sent, isEmpty);
  });

  test('email invalide = 0 send', () async {
    final created = await seed(email: 'pas une adresse');
    await expectLater(
      sendReminder.execute(created.id),
      throwsA(isA<ReminderEmailInvalid>()),
    );
    expect(emailSender.sent, isEmpty);
  });

  test('Google disconnected = 0 send', () async {
    google = FakeGoogleAuthSession.disconnected();
    sendReminder = buildUseCase();
    final created = await seed();
    await expectLater(
      sendReminder.execute(created.id),
      throwsA(isA<GoogleSessionDisconnected>()),
    );
    expect(emailSender.sent, isEmpty);
  });

  test('Reminder plus scheduled = 0 send', () async {
    final created = await seed(status: ReminderStatus.sent);
    await expectLater(
      sendReminder.execute(created.id),
      throwsA(isA<ReminderAlreadySent>()),
    );
    expect(emailSender.sent, isEmpty);
  });

  test('échec Gmail = 1 tentative, 0 markSent', () async {
    emailSender.error = const EmailSendFailed(EmailSendFailureKind.unavailable);
    final created = await seed();
    await expectLater(
      sendReminder.execute(created.id),
      throwsA(isA<ReminderEmailSendRejected>()),
    );
    expect(emailSender.sent, hasLength(1));
    expect(
      (await reminders.findById(created.id))!.status,
      ReminderStatus.scheduled,
    );
    expect(await activities.findRecent(limit: 10), isEmpty);
  });

  test('Gmail OK / DB KO = 1 send, pas de markSent, récupération 0 send', () async {
    reminders = _FailOnceReminders(InMemoryReminderRepository());
    activities = InMemoryActivityRepository(pianos);
    sendReminder = buildUseCase();
    final created = await seed();

    await expectLater(
      sendReminder.execute(created.id),
      throwsA(isA<ReminderEmailSentButNotRecorded>()),
    );
    expect(emailSender.sent, hasLength(1));
    expect(
      (await reminders.findById(created.id))!.status,
      ReminderStatus.scheduled,
    );

    final recorded = await reminderService.markSent(created.id);
    expect(recorded.status, ReminderStatus.sent);
    expect(emailSender.sent, hasLength(1));
  });

  test('preview n’envoie pas', () async {
    final created = await seed();
    final preview = await sendReminder.preview(created.id);
    expect(preview.recipient, 'jean@example.com');
    expect(emailSender.sent, isEmpty);
    expect(
      (await reminders.findById(created.id))!.status,
      ReminderStatus.scheduled,
    );
  });
}
