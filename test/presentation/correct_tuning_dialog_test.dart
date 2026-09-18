import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/correct_tuning_dialog.dart';
import 'package:accord_memo/presentation/formatters/french_date_label.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required Future<Tuning> Function({
    required CalendarDate tuningDate,
    String? notes,
  })
  onSubmit,
  CalendarDate? initialDate,
  String? initialNotes = 'diapason 440',
}) {
  final resolvedInitialDate = initialDate ?? CalendarDate(2026, 1, 5);
  return MaterialApp(
    theme: buildAppTheme(),
    home: CorrectTuningDialog(
      today: CalendarDate(2026, 9, 17),
      initialDate: resolvedInitialDate,
      initialNotes: initialNotes,
      onSubmit: onSubmit,
    ),
  );
}

void main() {
  testWidgets('préremplit la date et les notes', (tester) async {
    await tester.pumpWidget(
      _app(
        onSubmit: ({required tuningDate, notes}) async {
          throw StateError('ne doit pas enregistrer');
        },
      ),
    );
    await tester.pump();

    expect(find.text(clientsCorrectTuningTitle), findsOneWidget);
    expect(find.text(formatFrenchNumericDate(CalendarDate(2026, 1, 5))), findsOneWidget);
    expect(find.text('diapason 440'), findsOneWidget);
  });

  testWidgets('limite le DatePicker à aujourd’hui du Clock', (tester) async {
    await tester.pumpWidget(
      _app(
        onSubmit: ({required tuningDate, notes}) async {
          throw StateError('ne doit pas enregistrer');
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.text(formatFrenchNumericDate(CalendarDate(2026, 1, 5))));
    await tester.pump();
    await tester.pump();

    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.lastDate, DateTime(2026, 9, 17));
  });

  testWidgets('annuler ne soumet pas', (tester) async {
    var submitted = false;
    await tester.pumpWidget(
      _app(
        onSubmit: ({required tuningDate, notes}) async {
          submitted = true;
          throw StateError('ne doit pas enregistrer');
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.text(clientsCancel));
    await tester.pump();

    expect(submitted, isFalse);
  });

  testWidgets('affiche TuningDateInFuture sans détail technique', (tester) async {
    await tester.pumpWidget(
      _app(
        onSubmit: ({required tuningDate, notes}) async {
          throw TuningDateInFuture(
            tuningDate: CalendarDate(2026, 9, 18),
            today: CalendarDate(2026, 9, 17),
          );
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, clientsCorrectTuningSave));
    await tester.pump();

    expect(find.text(clientsTuningDateInFuture), findsOneWidget);
    expect(find.textContaining('TuningDateInFuture'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('affiche TuningNotFound sans détail technique', (tester) async {
    await tester.pumpWidget(
      _app(
        onSubmit: ({required tuningDate, notes}) async {
          throw TuningNotFound(TuningId('missing'));
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, clientsCorrectTuningSave));
    await tester.pump();

    expect(find.text(clientsTuningNotFound), findsOneWidget);
    expect(find.textContaining('TuningNotFound'), findsNothing);
  });

  testWidgets('affiche PianoNotFound sans détail technique', (tester) async {
    await tester.pumpWidget(
      _app(
        onSubmit: ({required tuningDate, notes}) async {
          throw PianoNotFound(PianoId('missing'));
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, clientsCorrectTuningSave));
    await tester.pump();

    expect(find.text(clientsPianoNotFound), findsOneWidget);
    expect(find.textContaining('PianoNotFound'), findsNothing);
  });
}
