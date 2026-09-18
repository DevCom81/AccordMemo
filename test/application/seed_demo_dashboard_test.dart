import 'package:accord_memo/application/dashboard/dashboard_service.dart';
import 'package:accord_memo/application/dev/seed_demo_dashboard.dart';
import 'package:accord_memo/domain/activity/activity_type.dart';
import 'package:accord_memo/domain/customer/customer_repository.dart';
import 'package:accord_memo/domain/piano/piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/app_database.dart';
import 'package:accord_memo/infrastructure/persistence/drift_activity_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_customer_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_dashboard_reminder_query.dart';
import 'package:accord_memo/infrastructure/persistence/drift_piano_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_reminder_repository.dart';
import 'package:accord_memo/infrastructure/persistence/drift_transaction_runner.dart';
import 'package:accord_memo/infrastructure/persistence/drift_tuning_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_id_generator.dart';
import '../support/fixed_clock.dart';

void main() {
  late AppDatabase database;
  late DriftCustomerRepository customers;
  late DriftPianoRepository pianos;
  late DriftTuningRepository tunings;
  late DriftReminderRepository reminders;
  late DriftActivityRepository activities;
  late SeedDemoDashboard seeder;
  late DashboardService dashboard;
  final now = DateTime.utc(2026, 9, 17, 10);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = DriftCustomerRepository(database);
    pianos = DriftPianoRepository(database);
    tunings = DriftTuningRepository(database);
    reminders = DriftReminderRepository(database);
    activities = DriftActivityRepository(database);
    seeder = SeedDemoDashboard(
      clock: FixedClock(now),
      idGenerator: FakeIdGenerator(spareIds(48)),
      transactions: DriftTransactionRunner(database),
      customers: customers,
      pianos: pianos,
      tunings: tunings,
      reminders: reminders,
      activities: activities,
    );
    dashboard = DashboardService(
      clock: FixedClock(now),
      query: DriftDashboardReminderQuery(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('peuple 2+2+2 rappels dashboard et le journal Activity prévu', () async {
    final inserted = await seeder.run();
    expect(inserted, isTrue);

    final activeCustomers = await customers.search(
      filter: CustomerStatusFilter.active,
      query: '',
    );
    expect(activeCustomers, hasLength(5));

    var pianoCount = 0;
    var tuningCount = 0;
    var scheduledCount = 0;
    for (final customer in activeCustomers) {
      final owned = await pianos.findByCustomerId(
        customerId: customer.id,
        filter: PianoStatusFilter.active,
      );
      pianoCount += owned.length;
      for (final piano in owned) {
        final pianoTunings = await tunings.findByPianoId(piano.id);
        tuningCount += pianoTunings.length;
        if (await reminders.findScheduledByPianoId(piano.id) != null) {
          scheduledCount += 1;
        }
      }
    }
    expect(pianoCount, 6);
    expect(tuningCount, 8);
    expect(scheduledCount, 6);

    final snapshot = await dashboard.load();
    expect(snapshot.overdue, hasLength(2));
    expect(snapshot.dueSoon, hasLength(2));
    expect(snapshot.upcoming, hasLength(2));

    final journal = await activities.findRecent(limit: 20);
    expect(journal, hasLength(11));

    expect(
      journal.where((item) => item.type == ActivityType.tuningCreated),
      hasLength(8),
    );
    expect(
      journal.where((item) => item.type == ActivityType.tuningUpdated),
      hasLength(1),
    );
    expect(
      journal.where((item) => item.type == ActivityType.reminderRescheduled),
      hasLength(2),
    );
    expect(
      journal.where((item) => item.type == ActivityType.reminderSent),
      isEmpty,
    );
    expect(
      journal.where((item) => item.type == ActivityType.reminderDisabled),
      isEmpty,
    );
    expect(
      journal.where((item) => item.type == ActivityType.reminderReenabled),
      isEmpty,
    );

    final notesOnly = journal.singleWhere(
      (item) => item.type == ActivityType.tuningUpdated,
    );
    expect(notesOnly.previousDate, isNull);
    expect(notesOnly.newDate, isNull);
  });

  test('ne réinsère rien si la base démo est déjà peuplée', () async {
    expect(await seeder.run(), isTrue);
    expect(await seeder.run(), isFalse);

    final activeCustomers = await customers.search(
      filter: CustomerStatusFilter.active,
      query: '',
    );
    expect(activeCustomers, hasLength(5));

    final journal = await activities.findRecent(limit: 20);
    expect(journal, hasLength(11));
  });
}
