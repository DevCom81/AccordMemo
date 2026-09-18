import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/piano_tunings_dialog.dart';
import 'package:accord_memo/presentation/formatters/french_date_label.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Tuning _tuning({
  required String id,
  required CalendarDate date,
  String? notes,
}) {
  return Tuning.create(
    id: TuningId(id),
    pianoId: PianoId('piano-1'),
    tuningDate: date,
    today: CalendarDate(2026, 9, 17),
    notes: notes,
    now: DateTime.utc(2026, 9, 17, 10),
  );
}

void main() {
  final newer = _tuning(
    id: 'tuning-new',
    date: CalendarDate(2026, 3, 1),
    notes: 'après restauration',
  );
  final older = _tuning(
    id: 'tuning-old',
    date: CalendarDate(2025, 1, 1),
  );

  testWidgets('liste les accords du plus récent au plus ancien', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PianoTuningsDialog(
          initialTunings: [newer, older],
          loadTunings: () async => [newer, older],
          onSelect: (tuning) async => false,
          onCorrected: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(clientsPianoTuningsTitle), findsOneWidget);
    final dates = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .whereType<String>()
        .where(
          (value) =>
              value == formatFrenchNumericDate(newer.tuningDate) ||
              value == formatFrenchNumericDate(older.tuningDate),
        )
        .toList();
    expect(dates, [
      formatFrenchNumericDate(newer.tuningDate),
      formatFrenchNumericDate(older.tuningDate),
    ]);
    expect(find.text('après restauration'), findsOneWidget);
    expect(find.text('Non renseigné'), findsNothing);
  });

  testWidgets('annuler la liste ne déclenche aucune correction', (tester) async {
    var selected = false;
    var corrected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PianoTuningsDialog(
          initialTunings: [newer],
          loadTunings: () async => [newer],
          onSelect: (tuning) async {
            selected = true;
            return false;
          },
          onCorrected: () => corrected = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(clientsCancel));
    await tester.pump();

    expect(selected, isFalse);
    expect(corrected, isFalse);
  });

  testWidgets('après succès garde la liste ouverte et recharge', (tester) async {
    var corrected = false;
    var loads = 0;
    final updated = _tuning(
      id: 'tuning-new',
      date: CalendarDate(2026, 2, 1),
      notes: 'date corrigée',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PianoTuningsDialog(
          initialTunings: [newer, older],
          loadTunings: () async {
            loads += 1;
            return [updated, older];
          },
          onSelect: (tuning) async => identical(tuning, newer),
          onCorrected: () => corrected = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(formatFrenchNumericDate(newer.tuningDate)));
    await tester.pump();
    await tester.pump();

    expect(corrected, isTrue);
    expect(loads, 1);
    expect(find.text(clientsPianoTuningsTitle), findsOneWidget);
    expect(find.text(formatFrenchNumericDate(updated.tuningDate)), findsOneWidget);
    expect(find.text('date corrigée'), findsOneWidget);
  });

  testWidgets('n’overflow pas en largeur étroite', (tester) async {
    final longNotes = _tuning(
      id: 'tuning-long',
      date: CalendarDate(2026, 3, 1),
      notes: 'Notes très longues pour vérifier le retour à la ligne sans overflow '
          'dans le dialogue compact des accords enregistrés.',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            child: PianoTuningsDialog(
              initialTunings: [longNotes],
              loadTunings: () async => [longNotes],
              onSelect: (tuning) async => false,
              onCorrected: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
