import '../../domain/activity/activity.dart';
import '../../domain/activity/activity_repository.dart';
import '../../domain/clock.dart';
import '../../domain/customer/civility.dart';
import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_repository.dart';
import '../../domain/piano/piano.dart';
import '../../domain/piano/piano_repository.dart';
import '../../domain/piano/piano_type.dart';
import '../../domain/reminder/reminder.dart';
import '../../domain/reminder/reminder_repository.dart';
import '../../domain/shared/calendar_date.dart';
import '../../domain/tuning/tuning.dart';
import '../../domain/tuning/tuning_repository.dart';
import '../ports/id_generator.dart';
import '../ports/transaction_runner.dart';

/// Jeu de données DEV uniquement. N'introduit aucun invariant métier.
final class SeedDemoDashboard {
  SeedDemoDashboard({
    required this._clock,
    required this._idGenerator,
    required this._transactions,
    required this._customers,
    required this._pianos,
    required this._tunings,
    required this._reminders,
    required this._activities,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactions;
  final CustomerRepository _customers;
  final PianoRepository _pianos;
  final TuningRepository _tunings;
  final ReminderRepository _reminders;
  final ActivityRepository _activities;

  /// `true` si le jeu a été inséré, `false` si la base démo était déjà peuplée.
  Future<bool> run() async {
    final alreadyThere = await _customers.search(
      filter: CustomerStatusFilter.active,
      query: '',
    );
    if (alreadyThere.isNotEmpty) {
      return false;
    }

    await _transactions.run(_insertAll);
    return true;
  }

  Future<void> _insertAll() async {
    final now = _clock.now();
    final today = CalendarDate.fromLocalInstant(now);

    final fabre = await _insertCustomer(
      lastName: 'Fabre',
      firstName: 'Marguerite',
      city: 'Toulouse',
      civility: Civility.madame,
      now: now,
    );
    final dupont = await _insertCustomer(
      lastName: 'Dupont',
      firstName: 'Jean',
      city: 'Albi',
      civility: Civility.monsieur,
      now: now,
    );
    final ecole = await _insertCustomer(
      lastName: 'École Sainte-Cécile',
      city: 'Montpellier',
      now: now,
    );
    final cazeneuve = await _insertCustomer(
      lastName: 'Cazeneuve',
      firstName: 'Hélène',
      city: 'Auch',
      civility: Civility.madame,
      now: now,
    );
    final atelier = await _insertCustomer(
      lastName: 'Harmonie Pianos',
      city: 'Nîmes',
      now: now,
    );

    final pleyel = await _insertPiano(
      customerId: fabre.id,
      brand: 'Pleyel',
      model: '1920',
      type: PianoType.queue,
      now: now,
    );
    final yamahaU1 = await _insertPiano(
      customerId: dupont.id,
      brand: 'Yamaha',
      model: 'U1',
      type: PianoType.droit,
      now: now,
    );
    final kawai = await _insertPiano(
      customerId: ecole.id,
      brand: 'Kawai',
      model: 'K300',
      type: PianoType.droit,
      now: now,
    );
    final yamahaC3 = await _insertPiano(
      customerId: ecole.id,
      brand: 'Yamaha',
      model: 'C3',
      type: PianoType.queue,
      now: now,
    );
    final steinway = await _insertPiano(
      customerId: cazeneuve.id,
      brand: 'Steinway',
      model: 'M',
      type: PianoType.queue,
      now: now,
    );
    final schimmel = await _insertPiano(
      customerId: atelier.id,
      brand: 'Schimmel',
      model: '120',
      type: PianoType.droit,
      now: now,
    );

    final oldFabreTuning = await _insertTuning(
      pianoId: pleyel.id,
      tuningDate: today.addDays(-400),
      today: today,
      notes: 'Premier passage',
      now: now,
    );
    final fabreTuning = await _insertTuning(
      pianoId: pleyel.id,
      tuningDate: today.addDays(-200),
      today: today,
      now: now,
    );
    final dupontTuning = await _insertTuning(
      pianoId: yamahaU1.id,
      tuningDate: today.addDays(-180),
      today: today,
      notes: 'Diapason 440',
      now: now,
    );
    final kawaiTuning = await _insertTuning(
      pianoId: kawai.id,
      tuningDate: today.addDays(-160),
      today: today,
      now: now,
    );
    final oldEcoleTuning = await _insertTuning(
      pianoId: yamahaC3.id,
      tuningDate: today.addDays(-380),
      today: today,
      now: now,
    );
    final ecoleQueueTuning = await _insertTuning(
      pianoId: yamahaC3.id,
      tuningDate: today.addDays(-90),
      today: today,
      now: now,
    );
    final cazeneuveTuning = await _insertTuning(
      pianoId: steinway.id,
      tuningDate: today.addDays(-150),
      today: today,
      now: now,
    );
    final atelierTuning = await _insertTuning(
      pianoId: schimmel.id,
      tuningDate: today.addDays(-120),
      today: today,
      now: now,
    );

    await _insertTuningCreated(
      oldFabreTuning,
      occurredAt: _atNoonUtc(oldFabreTuning.tuningDate),
    );
    await _insertTuningCreated(
      fabreTuning,
      occurredAt: _atNoonUtc(fabreTuning.tuningDate),
    );
    await _insertTuningCreated(
      dupontTuning,
      occurredAt: _atNoonUtc(dupontTuning.tuningDate),
    );
    await _insertTuningCreated(
      kawaiTuning,
      occurredAt: _atNoonUtc(kawaiTuning.tuningDate),
    );
    await _insertTuningCreated(
      oldEcoleTuning,
      occurredAt: _atNoonUtc(oldEcoleTuning.tuningDate),
    );
    await _insertTuningCreated(
      ecoleQueueTuning,
      occurredAt: _atNoonUtc(ecoleQueueTuning.tuningDate),
    );
    await _insertTuningCreated(
      cazeneuveTuning,
      occurredAt: _atNoonUtc(cazeneuveTuning.tuningDate),
    );
    await _insertTuningCreated(
      atelierTuning,
      occurredAt: _atNoonUtc(atelierTuning.tuningDate),
    );

    await _activities.insert(
      Activity.tuningUpdated(
        id: ActivityId(_idGenerator.next()),
        pianoId: dupontTuning.pianoId,
        tuningId: dupontTuning.id,
        now: _atNoonUtc(dupontTuning.tuningDate).add(const Duration(hours: 3)),
      ),
    );

    await _insertScheduled(
      pianoId: pleyel.id,
      originTuningId: fabreTuning.id,
      dueDate: today.addDays(-14),
      now: now,
    );
    await _insertScheduled(
      pianoId: yamahaU1.id,
      originTuningId: dupontTuning.id,
      dueDate: today.addDays(-3),
      now: now,
    );
    final dueToday = await _insertScheduled(
      pianoId: kawai.id,
      originTuningId: kawaiTuning.id,
      dueDate: today,
      now: now,
    );
    await _insertScheduled(
      pianoId: yamahaC3.id,
      originTuningId: ecoleQueueTuning.id,
      dueDate: today.addDays(6),
      now: now,
    );
    await _insertScheduled(
      pianoId: steinway.id,
      originTuningId: cazeneuveTuning.id,
      dueDate: today.addDays(12),
      now: now,
    );
    final upcomingLater = await _insertScheduled(
      pianoId: schimmel.id,
      originTuningId: atelierTuning.id,
      dueDate: today.addDays(25),
      now: now,
    );

    await _activities.insert(
      Activity.reminderRescheduled(
        id: ActivityId(_idGenerator.next()),
        pianoId: dueToday.pianoId,
        reminderId: dueToday.id,
        previousDate: today.addDays(2),
        newDate: dueToday.dueDate,
        now: now.toUtc().subtract(const Duration(days: 4)),
      ),
    );
    await _activities.insert(
      Activity.reminderRescheduled(
        id: ActivityId(_idGenerator.next()),
        pianoId: upcomingLater.pianoId,
        reminderId: upcomingLater.id,
        previousDate: today.addDays(18),
        newDate: upcomingLater.dueDate,
        now: now.toUtc().subtract(const Duration(days: 2)),
      ),
    );
  }

  Future<Customer> _insertCustomer({
    required String lastName,
    String? firstName,
    String? city,
    Civility? civility,
    required DateTime now,
  }) async {
    final customer = Customer.create(
      id: CustomerId(_idGenerator.next()),
      civility: civility,
      lastName: lastName,
      firstName: firstName,
      city: city,
      now: now,
    );
    await _customers.insert(customer);
    return customer;
  }

  Future<Piano> _insertPiano({
    required CustomerId customerId,
    String? brand,
    String? model,
    PianoType? type,
    required DateTime now,
  }) async {
    final piano = Piano.create(
      id: PianoId(_idGenerator.next()),
      customerId: customerId,
      brand: brand,
      model: model,
      type: type,
      now: now,
    );
    await _pianos.insert(piano);
    return piano;
  }

  Future<Tuning> _insertTuning({
    required PianoId pianoId,
    required CalendarDate tuningDate,
    required CalendarDate today,
    String? notes,
    required DateTime now,
  }) async {
    final tuning = Tuning.create(
      id: TuningId(_idGenerator.next()),
      pianoId: pianoId,
      tuningDate: tuningDate,
      today: today,
      notes: notes,
      now: now,
    );
    await _tunings.insert(tuning);
    return tuning;
  }

  Future<void> _insertTuningCreated(
    Tuning tuning, {
    required DateTime occurredAt,
  }) {
    return _activities.insert(
      Activity.tuningCreated(
        id: ActivityId(_idGenerator.next()),
        pianoId: tuning.pianoId,
        tuningId: tuning.id,
        now: occurredAt,
      ),
    );
  }

  Future<Reminder> _insertScheduled({
    required PianoId pianoId,
    required TuningId originTuningId,
    required CalendarDate dueDate,
    required DateTime now,
  }) async {
    final reminder = Reminder.schedule(
      id: ReminderId(_idGenerator.next()),
      pianoId: pianoId,
      originTuningId: originTuningId,
      dueDate: dueDate,
      now: now,
    );
    await _reminders.insert(reminder);
    return reminder;
  }
}

DateTime _atNoonUtc(CalendarDate date) {
  return DateTime.utc(date.year, date.month, date.day, 12);
}
