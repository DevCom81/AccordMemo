import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customer/customer_service.dart';
import '../application/dashboard/dashboard_reminder_query.dart';
import '../application/dashboard/dashboard_service.dart';
import '../application/dashboard/dashboard_snapshot.dart';
import '../application/piano/piano_service.dart';
import '../application/ports/id_generator.dart';
import '../application/ports/transaction_runner.dart';
import '../application/reminder/reminder_service.dart';
import '../application/tuning/correct_tuning.dart';
import '../application/tuning/latest_piano_tuning_query.dart';
import '../application/tuning/record_tuning.dart';
import '../application/tuning/tuning_service.dart';
import '../domain/activity/activity_repository.dart';
import '../domain/clock.dart';
import '../domain/customer/customer_repository.dart';
import '../domain/piano/piano_repository.dart';
import '../domain/reminder/reminder_repository.dart';
import '../domain/tuning/tuning_repository.dart';
import '../infrastructure/ids/uuid_id_generator.dart';
import '../infrastructure/persistence/app_database.dart';
import '../infrastructure/persistence/drift_activity_repository.dart';
import '../infrastructure/persistence/drift_customer_repository.dart';
import '../infrastructure/persistence/drift_dashboard_reminder_query.dart';
import '../infrastructure/persistence/drift_latest_piano_tuning_query.dart';
import '../infrastructure/persistence/drift_piano_repository.dart';
import '../infrastructure/persistence/drift_reminder_repository.dart';
import '../infrastructure/persistence/drift_transaction_runner.dart';
import '../infrastructure/persistence/drift_tuning_repository.dart';
import '../infrastructure/time/system_clock.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = openProductionAppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

final idGeneratorProvider = Provider<IdGenerator>((ref) {
  return UuidIdGenerator();
});

final transactionRunnerProvider = Provider<TransactionRunner>((ref) {
  return DriftTransactionRunner(ref.watch(appDatabaseProvider));
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return DriftActivityRepository(ref.watch(appDatabaseProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return DriftCustomerRepository(ref.watch(appDatabaseProvider));
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    transactions: ref.watch(transactionRunnerProvider),
    repository: ref.watch(customerRepositoryProvider),
    pianos: ref.watch(pianoRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activities: ref.watch(activityRepositoryProvider),
  );
});

final pianoRepositoryProvider = Provider<PianoRepository>((ref) {
  return DriftPianoRepository(ref.watch(appDatabaseProvider));
});

final pianoServiceProvider = Provider<PianoService>((ref) {
  return PianoService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    transactions: ref.watch(transactionRunnerProvider),
    pianos: ref.watch(pianoRepositoryProvider),
    customers: ref.watch(customerRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activities: ref.watch(activityRepositoryProvider),
  );
});

final tuningRepositoryProvider = Provider<TuningRepository>((ref) {
  return DriftTuningRepository(ref.watch(appDatabaseProvider));
});

final tuningServiceProvider = Provider<TuningService>((ref) {
  return TuningService(tunings: ref.watch(tuningRepositoryProvider));
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return DriftReminderRepository(ref.watch(appDatabaseProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    transactions: ref.watch(transactionRunnerProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activities: ref.watch(activityRepositoryProvider),
  );
});

final recordTuningProvider = Provider<RecordTuning>((ref) {
  return RecordTuning(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    transactions: ref.watch(transactionRunnerProvider),
    tunings: ref.watch(tuningRepositoryProvider),
    pianos: ref.watch(pianoRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activities: ref.watch(activityRepositoryProvider),
  );
});

final latestPianoTuningQueryProvider = Provider<LatestPianoTuningQuery>((ref) {
  return DriftLatestPianoTuningQuery(ref.watch(appDatabaseProvider));
});

final correctTuningProvider = Provider<CorrectTuning>((ref) {
  return CorrectTuning(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    transactions: ref.watch(transactionRunnerProvider),
    tunings: ref.watch(tuningRepositoryProvider),
    pianos: ref.watch(pianoRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activities: ref.watch(activityRepositoryProvider),
  );
});

final dashboardReminderQueryProvider = Provider<DashboardReminderQuery>((ref) {
  return DriftDashboardReminderQuery(ref.watch(appDatabaseProvider));
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(
    clock: ref.watch(clockProvider),
    query: ref.watch(dashboardReminderQueryProvider),
  );
});

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((ref) {
  return ref.watch(dashboardServiceProvider).load();
});
