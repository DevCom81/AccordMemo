import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/dev/seed_demo_dashboard.dart';
import 'infrastructure/ids/uuid_id_generator.dart';
import 'infrastructure/persistence/app_database.dart';
import 'infrastructure/persistence/drift_activity_repository.dart';
import 'infrastructure/persistence/drift_customer_repository.dart';
import 'infrastructure/persistence/drift_piano_repository.dart';
import 'infrastructure/persistence/drift_reminder_repository.dart';
import 'infrastructure/persistence/drift_transaction_runner.dart';
import 'infrastructure/persistence/drift_tuning_repository.dart';
import 'infrastructure/time/system_clock.dart';
import 'main.dart';
import 'presentation/app_providers.dart';
import 'presentation/dev/demo_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kDebugMode) {
    throw StateError(
      'lib/main_demo.dart est réservé au mode debug. '
      'Utiliser lib/main.dart pour un lancement production.',
    );
  }

  final database = openDemoAppDatabase();
  try {
    await SeedDemoDashboard(
      clock: const SystemClock(),
      idGenerator: UuidIdGenerator(),
      transactions: DriftTransactionRunner(database),
      customers: DriftCustomerRepository(database),
      pianos: DriftPianoRepository(database),
      tunings: DriftTuningRepository(database),
      reminders: DriftReminderRepository(database),
      activities: DriftActivityRepository(database),
    ).run();
  } catch (_) {
    await database.close();
    rethrow;
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(() {
            database.close();
          });
          return database;
        }),
        demoModeProvider.overrideWith((ref) => true),
      ],
      child: const AccordMemoApp(),
    ),
  );
}
