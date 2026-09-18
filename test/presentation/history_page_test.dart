import 'dart:async';
import 'dart:io';

import 'package:accord_memo/application/history/history_entry.dart';
import 'package:accord_memo/application/history/history_kind.dart';
import 'package:accord_memo/application/history/history_query.dart';
import 'package:accord_memo/domain/activity/activity.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/presentation/app_providers.dart';
import 'package:accord_memo/presentation/formatters/french_date_label.dart';
import 'package:accord_memo/presentation/history/history_page.dart';
import 'package:accord_memo/presentation/history/history_providers.dart';
import 'package:accord_memo/presentation/history/history_strings.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_history_query.dart';

HistoryEntry _entry({
  required String id,
  required DateTime occurredAt,
  required HistoryKind kind,
  String lastName = 'Dupont',
  String? firstName = 'Jean',
  bool customerArchived = false,
  String? brand = 'Yamaha',
  String? model = 'U1',
  bool pianoArchived = false,
  CalendarDate? previousDate,
  CalendarDate? newDate,
  CalendarDate? tuningDate,
  CalendarDate? reminderDueDate,
}) {
  return HistoryEntry(
    activityId: ActivityId(id),
    occurredAt: occurredAt,
    kind: kind,
    customerLastName: lastName,
    customerFirstName: firstName,
    customerArchived: customerArchived,
    pianoBrand: brand,
    pianoModel: model,
    pianoArchived: pianoArchived,
    previousDate: previousDate,
    newDate: newDate,
    tuningDate: tuningDate,
    reminderDueDate: reminderDueDate,
  );
}

Widget _historyApp({
  HistoryQuery? query,
  Future<List<HistoryEntry>> Function()? loadSnapshot,
}) {
  return ProviderScope(
    overrides: [
      if (loadSnapshot != null)
        historySnapshotProvider.overrideWith((ref) => loadSnapshot())
      else
        historyQueryProvider.overrideWith(
          (ref) => query ?? InMemoryHistoryQuery(),
        ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: HistoryPage()),
    ),
  );
}

Future<void> _prepareDesktop(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final occurred = DateTime.utc(2026, 9, 17, 8, 30);

  testWidgets('affiche empty, libellés français et identités sans IDs', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(_historyApp());
    await tester.pumpAndSettle();

    expect(find.text(historyPageTitle), findsOneWidget);
    expect(find.text(historyFilterAll), findsOneWidget);
    expect(find.text(historyFilterTunings), findsOneWidget);
    expect(find.text(historyFilterReminders), findsOneWidget);
    expect(find.text(historyEmptyAllTitle), findsOneWidget);
    expect(find.text(historyEmptyAllBody), findsOneWidget);
    expect(
      find.text('Cette section sera disponible prochainement.'),
      findsNothing,
    );
  });

  testWidgets('affiche les événements, dates et badges archivés', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(
      _historyApp(
        query: InMemoryHistoryQuery([
          _entry(
            id: 'activity-created-secret',
            occurredAt: occurred,
            kind: HistoryKind.tuningCreated,
            tuningDate: CalendarDate(2026, 9, 17),
          ),
          _entry(
            id: 'activity-updated-secret',
            occurredAt: DateTime.utc(2026, 9, 17, 9),
            kind: HistoryKind.tuningUpdated,
            previousDate: CalendarDate(2026, 1, 1),
            newDate: CalendarDate(2026, 2, 1),
          ),
          _entry(
            id: 'activity-rescheduled-secret',
            occurredAt: DateTime.utc(2026, 9, 17, 10),
            kind: HistoryKind.reminderRescheduled,
            previousDate: CalendarDate(2027, 9, 17),
            newDate: CalendarDate(2027, 10, 1),
          ),
          _entry(
            id: 'activity-sent-secret',
            occurredAt: DateTime.utc(2026, 9, 17, 11),
            kind: HistoryKind.reminderSent,
            reminderDueDate: CalendarDate(2027, 3, 1),
          ),
          _entry(
            id: 'activity-disabled-secret',
            occurredAt: DateTime.utc(2026, 9, 17, 12),
            kind: HistoryKind.reminderDisabled,
            customerArchived: true,
            pianoArchived: true,
          ),
          _entry(
            id: 'activity-reenabled-secret',
            occurredAt: DateTime.utc(2026, 9, 17, 13),
            kind: HistoryKind.reminderReenabled,
          ),
          _entry(
            id: 'activity-notes-only-secret',
            occurredAt: DateTime.utc(2026, 9, 17, 7),
            kind: HistoryKind.tuningUpdated,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(historyKindTuningCreated), findsOneWidget);
    expect(find.text(historyKindTuningUpdated), findsNWidgets(2));
    expect(find.text(historyKindReminderRescheduled), findsOneWidget);
    expect(find.text(historyKindReminderSent), findsOneWidget);
    expect(find.text(historyKindReminderDisabled), findsOneWidget);
    expect(find.text(historyKindReminderReenabled), findsOneWidget);
    expect(find.text('Jean Dupont · Yamaha U1'), findsWidgets);
    expect(find.text('17/09/2026'), findsOneWidget);
    expect(find.text('01/01/2026 → 01/02/2026'), findsOneWidget);
    expect(find.text('17/09/2027 → 01/10/2027'), findsOneWidget);
    expect(find.text('01/03/2027'), findsOneWidget);
    expect(find.text(formatFrenchDateTime(occurred)), findsOneWidget);
    expect(find.text(historyCustomerArchivedBadge), findsOneWidget);
    expect(find.text(historyPianoArchivedBadge), findsOneWidget);
    expect(find.text('activity-created-secret'), findsNothing);
    expect(find.text('tuningCreated'), findsNothing);
    expect(find.text('reminderDisabled'), findsNothing);
    expect(find.text('HistoryKind'), findsNothing);
    expect(find.textContaining('archivage'), findsNothing);
    expect(find.textContaining('manuelle'), findsNothing);
  });

  testWidgets('filtre Accords et Rappels via la query, limit 100', (
    tester,
  ) async {
    await _prepareDesktop(tester);
    final recording = _RecordingHistoryQuery(
      InMemoryHistoryQuery([
        _entry(
          id: 'activity-created',
          occurredAt: occurred,
          kind: HistoryKind.tuningCreated,
          tuningDate: CalendarDate(2026, 9, 17),
        ),
        _entry(
          id: 'activity-sent',
          occurredAt: DateTime.utc(2026, 9, 17, 11),
          kind: HistoryKind.reminderSent,
          reminderDueDate: CalendarDate(2027, 3, 1),
        ),
      ]),
    );
    await tester.pumpWidget(_historyApp(query: recording));
    await tester.pumpAndSettle();

    expect(recording.filters, [HistoryKindFilter.all]);
    expect(recording.limits, [historyDefaultLimit]);
    expect(find.text(historyKindTuningCreated), findsOneWidget);
    expect(find.text(historyKindReminderSent), findsOneWidget);

    await tester.tap(find.text(historyFilterTunings));
    await tester.pumpAndSettle();
    expect(recording.filters.last, HistoryKindFilter.tunings);
    expect(find.text(historyKindTuningCreated), findsOneWidget);
    expect(find.text(historyKindReminderSent), findsNothing);

    await tester.tap(find.text(historyFilterReminders));
    await tester.pumpAndSettle();
    expect(recording.filters.last, HistoryKindFilter.reminders);
    expect(find.text(historyKindReminderSent), findsOneWidget);
    expect(find.text(historyKindTuningCreated), findsNothing);
    expect(find.text(historyEmptyRemindersTitle), findsNothing);
  });

  testWidgets('empty filtré Accords', (tester) async {
    await _prepareDesktop(tester);
    await tester.pumpWidget(
      _historyApp(
        query: InMemoryHistoryQuery([
          _entry(
            id: 'activity-sent',
            occurredAt: occurred,
            kind: HistoryKind.reminderSent,
            reminderDueDate: CalendarDate(2027, 3, 1),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(historyFilterTunings));
    await tester.pumpAndSettle();
    expect(find.text(historyEmptyTuningsTitle), findsOneWidget);
    expect(find.text(historyEmptyTuningsBody), findsOneWidget);
  });

  testWidgets('affiche le chargement puis l’erreur avec retry', (tester) async {
    await _prepareDesktop(tester);
    var fail = true;
    var loads = 0;
    final pending = Completer<List<HistoryEntry>>();
    await tester.pumpWidget(
      _historyApp(
        loadSnapshot: () {
          loads += 1;
          if (fail) {
            return pending.future;
          }
          return Future.value(const <HistoryEntry>[]);
        },
      ),
    );
    await tester.pump();
    expect(find.text(historyLoadingMessage), findsOneWidget);
    expect(loads, 1);

    pending.completeError(Exception('SQLite constraint failed'));
    await tester.pumpAndSettle();
    expect(find.text(historyLoadErrorMessage), findsOneWidget);
    expect(find.text(historyRetry), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);

    fail = false;
    final loadsBeforeRetry = loads;
    await tester.tap(find.text(historyRetry));
    await tester.pumpAndSettle();
    expect(loads, greaterThan(loadsBeforeRetry));
    expect(find.text(historyEmptyAllTitle), findsOneWidget);
    expect(find.text(historyLoadErrorMessage), findsNothing);
  });

  testWidgets('n’overflow pas à 900×700', (tester) async {
    await _prepareDesktop(tester, size: const Size(900, 700));
    await tester.pumpWidget(
      _historyApp(
        query: InMemoryHistoryQuery([
          for (var i = 0; i < 12; i++)
            _entry(
              id: 'activity-$i',
              occurredAt: DateTime.utc(2026, 9, 17, 8, i),
              kind: HistoryKind.tuningCreated,
              lastName: 'ClientAvecUnNomTrèsLongPourTesterLeWrap',
              firstName: 'Jean-Baptiste',
              brand: 'Yamaha',
              model: 'Conservatory Collection U1',
              tuningDate: CalendarDate(2026, 9, 17),
            ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(historyPageTitle), findsOneWidget);
    expect(find.text(historyFilterAll), findsOneWidget);
  });

  test('présentation sans Drift ni SQL, query application dédiée', () {
    const files = [
      'lib/presentation/history/history_page.dart',
      'lib/presentation/history/history_event_card.dart',
      'lib/presentation/history/history_providers.dart',
      'lib/presentation/history/history_kind_label.dart',
      'lib/presentation/history/history_strings.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('app_database'), isFalse, reason: path);
      expect(source.contains('customSelect'), isFalse, reason: path);
      expect(source.contains('DriftHistoryQuery'), isFalse, reason: path);
    }
    final card = File(
      'lib/presentation/history/history_event_card.dart',
    ).readAsStringSync();
    expect(card.contains('activityId'), isFalse);
    expect(card.contains('ActivityType'), isFalse);

    final query = File(
      'lib/application/history/history_query.dart',
    ).readAsStringSync();
    expect(query.contains('select('), isFalse);
    expect(query.contains('JOIN'), isFalse);

    final drift = File(
      'lib/infrastructure/persistence/drift_history_query.dart',
    ).readAsStringSync();
    expect(drift.contains('innerJoin'), isTrue);
    expect(drift.contains('leftOuterJoin'), isTrue);
    expect(drift.contains('query.limit(limit)'), isTrue);
    expect(drift.contains('offset'), isFalse);

    final schema = File(
      'lib/infrastructure/persistence/app_database.dart',
    ).readAsStringSync();
    expect(schema.contains('schemaVersion => 6'), isTrue);

    final shell = File(
      'lib/presentation/shell/app_shell.dart',
    ).readAsStringSync();
    expect(shell.contains('HistoryPage'), isTrue);
    expect(shell.contains("ComingSoonPage(title: 'Historique')"), isFalse);
    expect(shell.contains('invalidate(historySnapshotProvider)'), isTrue);
    final dashboard = File(
      'lib/presentation/dashboard/dashboard_page.dart',
    ).readAsStringSync();
    expect(dashboard.contains('invalidate(historySnapshotProvider)'), isTrue);
    final detail = File(
      'lib/presentation/clients/client_detail_pane.dart',
    ).readAsStringSync();
    expect(detail.contains('invalidate(historySnapshotProvider)'), isTrue);
    final clients = File(
      'lib/presentation/clients/clients_page.dart',
    ).readAsStringSync();
    expect(clients.contains('invalidate(historySnapshotProvider)'), isTrue);
  });
}

final class _RecordingHistoryQuery implements HistoryQuery {
  _RecordingHistoryQuery(this._inner);

  final HistoryQuery _inner;
  final filters = <HistoryKindFilter>[];
  final limits = <int>[];

  @override
  Future<List<HistoryEntry>> findRecent({
    required int limit,
    required HistoryKindFilter filter,
  }) {
    filters.add(filter);
    limits.add(limit);
    return _inner.findRecent(limit: limit, filter: filter);
  }
}
