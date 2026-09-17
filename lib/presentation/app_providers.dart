import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customer/customer_service.dart';
import '../application/piano/piano_service.dart';
import '../application/ports/id_generator.dart';
import '../application/tuning/tuning_service.dart';
import '../domain/clock.dart';
import '../domain/customer/customer_repository.dart';
import '../domain/piano/piano_repository.dart';
import '../domain/tuning/tuning_repository.dart';
import '../infrastructure/ids/uuid_id_generator.dart';
import '../infrastructure/persistence/app_database.dart';
import '../infrastructure/persistence/drift_customer_repository.dart';
import '../infrastructure/persistence/drift_piano_repository.dart';
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

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return DriftCustomerRepository(ref.watch(appDatabaseProvider));
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    repository: ref.watch(customerRepositoryProvider),
  );
});

final pianoRepositoryProvider = Provider<PianoRepository>((ref) {
  return DriftPianoRepository(ref.watch(appDatabaseProvider));
});

final pianoServiceProvider = Provider<PianoService>((ref) {
  return PianoService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    pianos: ref.watch(pianoRepositoryProvider),
    customers: ref.watch(customerRepositoryProvider),
  );
});

final tuningRepositoryProvider = Provider<TuningRepository>((ref) {
  return DriftTuningRepository(ref.watch(appDatabaseProvider));
});

final tuningServiceProvider = Provider<TuningService>((ref) {
  return TuningService(
    clock: ref.watch(clockProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    tunings: ref.watch(tuningRepositoryProvider),
    pianos: ref.watch(pianoRepositoryProvider),
  );
});
