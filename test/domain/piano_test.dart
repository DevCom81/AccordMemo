import 'package:accord_memo/domain/customer/customer.dart';
import 'package:accord_memo/domain/piano/piano.dart';
import 'package:accord_memo/domain/piano/piano_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);
  final customerId = CustomerId('customer-1');

  Piano yamaha({int interval = Piano.defaultReminderIntervalMonths}) {
    return Piano.create(
      id: PianoId('piano-1'),
      customerId: customerId,
      brand: 'Yamaha',
      now: now,
      reminderIntervalMonths: interval,
    );
  }

  test('refuse un piano sans brand ni model ni type', () {
    expect(
      () => Piano.create(
        id: PianoId('piano-1'),
        customerId: customerId,
        now: now,
      ),
      throwsA(isA<PianoIdentificationRequired>()),
    );
  });

  test('accepte brand seul, model seul ou type seul', () {
    expect(
      Piano.create(
        id: PianoId('piano-1'),
        customerId: customerId,
        brand: 'Yamaha',
        now: now,
      ).brand,
      'Yamaha',
    );
    expect(
      Piano.create(
        id: PianoId('piano-2'),
        customerId: customerId,
        model: 'U1',
        now: now,
      ).model,
      'U1',
    );
    expect(
      Piano.create(
        id: PianoId('piano-3'),
        customerId: customerId,
        type: PianoType.droit,
        now: now,
      ).type,
      PianoType.droit,
    );
  });

  test('normalise les champs optionnels et applique les défauts', () {
    final piano = Piano.create(
      id: PianoId('piano-1'),
      customerId: customerId,
      brand: '  Yamaha  ',
      model: '  ',
      serialNumber: '  123  ',
      location: '  Salon  ',
      notes: '',
      now: now,
    );

    expect(piano.brand, 'Yamaha');
    expect(piano.model, isNull);
    expect(piano.serialNumber, '123');
    expect(piano.location, 'Salon');
    expect(piano.notes, isNull);
    expect(piano.reminderIntervalMonths, 12);
    expect(piano.remindersEnabled, isTrue);
    expect(piano.createdAt, now);
    expect(piano.customerId, customerId);
  });

  test('refuse un intervalle hors plage 1-60', () {
    expect(
      () => yamaha(interval: 0),
      throwsA(isA<PianoReminderIntervalOutOfRange>()),
    );
    expect(yamaha(interval: 1).reminderIntervalMonths, 1);
    expect(yamaha(interval: 60).reminderIntervalMonths, 60);
    expect(
      () => yamaha(interval: 61),
      throwsA(isA<PianoReminderIntervalOutOfRange>()),
    );
  });

  test('changeDetails refuse un piano archivé et conserve customerId', () {
    final archived = yamaha().archive(now);

    expect(
      () => archived.changeDetails(
        brand: 'Kawai',
        reminderIntervalMonths: 12,
        remindersEnabled: true,
        now: now,
      ),
      throwsA(isA<PianoArchivedNotModifiable>()),
    );
    expect(archived.customerId, customerId);
  });

  test('archive et restore sont les seules transitions de archivedAt', () {
    final created = yamaha();
    final archived = created.archive(now.add(const Duration(hours: 1)));
    expect(archived.isArchived, isTrue);
    expect(archived.customerId, created.customerId);

    expect(
      () => archived.archive(now),
      throwsA(isA<PianoAlreadyArchived>()),
    );
    expect(
      () => created.restore(now),
      throwsA(isA<PianoNotArchived>()),
    );

    final restored = archived.restore(now.add(const Duration(hours: 2)));
    expect(restored.isArchived, isFalse);
    expect(restored.customerId, customerId);
  });

  test('disableReminders fonctionne même sur un piano archivé', () {
    final archived = yamaha().archive(now);
    final disabled = archived.disableReminders(now.add(const Duration(hours: 1)));

    expect(disabled.isArchived, isTrue);
    expect(disabled.remindersEnabled, isFalse);
    expect(disabled.customerId, customerId);
    expect(identical(disabled.disableReminders(now), disabled), isTrue);
  });
}
