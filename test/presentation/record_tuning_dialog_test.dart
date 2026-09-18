import 'package:accord_memo/domain/shared/calendar_date.dart';
import 'package:accord_memo/domain/tuning/tuning.dart';
import 'package:accord_memo/presentation/clients/clients_strings.dart';
import 'package:accord_memo/presentation/clients/record_tuning_dialog.dart';
import 'package:accord_memo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche TuningDateInFuture sans détail technique', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RecordTuningDialog(
          today: CalendarDate(2026, 9, 17),
          onSubmit: ({required CalendarDate tuningDate, String? notes}) async {
            throw TuningDateInFuture(
              tuningDate: CalendarDate(2026, 9, 18),
              today: CalendarDate(2026, 9, 17),
            );
          },
        ),
      ),
    );

    await tester.tap(
      find.widgetWithText(FilledButton, clientsRecordTuningSave),
    );
    await tester.pumpAndSettle();

    expect(find.text(clientsTuningDateInFuture), findsOneWidget);
    expect(find.textContaining('TuningDateInFuture'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
