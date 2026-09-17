import 'package:accord_memo/application/dashboard/dashboard_display_names.dart';
import 'package:accord_memo/domain/piano/piano_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('affiche prénom + nom, ou le nom seul', () {
    expect(
      formatDashboardCustomerName(lastName: 'Dupont', firstName: 'Jean'),
      'Jean Dupont',
    );
    expect(
      formatDashboardCustomerName(lastName: 'Fabre', firstName: 'Marguerite'),
      'Marguerite Fabre',
    );
    expect(formatDashboardCustomerName(lastName: 'Dupont'), 'Dupont');
  });

  test('formate le piano sans displayName persisté', () {
    expect(
      formatDashboardPianoName(brand: 'Yamaha', model: 'U1'),
      'Yamaha U1',
    );
    expect(formatDashboardPianoName(brand: 'Yamaha'), 'Yamaha');
    expect(formatDashboardPianoName(model: 'U1'), 'U1');
    expect(formatDashboardPianoName(type: PianoType.droit), 'Piano droit');
    expect(formatDashboardPianoName(type: PianoType.queue), 'Piano à queue');
    expect(formatDashboardPianoName(), '');
  });
}
