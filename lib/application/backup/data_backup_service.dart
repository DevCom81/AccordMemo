import 'package:path/path.dart' as p;

import '../../domain/clock.dart';
import '../ports/id_generator.dart';
import 'app_data_locator.dart';
import 'app_database_session.dart';
import 'backup_exceptions.dart';
import 'backup_file_name.dart';
import 'backup_outcome.dart';
import 'backup_store.dart';
import 'backup_validator.dart';
import 'file_location_picker.dart';

final class DataBackupService {
  DataBackupService({
    required this._clock,
    required this._idGenerator,
    required this._locator,
    required this._picker,
    required this._validator,
    required this._store,
    required this._session,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final AppDataLocator _locator;
  final FileLocationPicker _picker;
  final BackupValidator _validator;
  final BackupStore _store;
  final AppDatabaseSession _session;
  var _busy = false;

  String get displayLocation => _locator.displayLocation;

  Future<BackupOutcome> backup({String? destinationPath}) async {
    if (_busy) {
      throw const BackupBusy();
    }
    final destination =
        destinationPath ??
        await _picker.pickSaveLocation(
          suggestedFileName: suggestedBackupFileName(_clock.now()),
        );
    if (destination == null) {
      return BackupOutcome.cancelled;
    }
    _busy = true;
    try {
      await _exportAtomically(destination);
      return BackupOutcome.completed;
    } finally {
      _busy = false;
    }
  }

  Future<RestoreOutcome> restore({String? sourcePath}) async {
    if (_busy) {
      throw const BackupBusy();
    }
    final source = sourcePath ?? await _picker.pickOpenLocation();
    if (source == null) {
      return RestoreOutcome.cancelled;
    }
    _validator.validate(source);
    _busy = true;
    final safetyPath = p.join(
      _locator.liveDirectoryPath,
      'accord_memo.safety-${_idGenerator.next()}.db',
    );
    var keepSafety = false;
    try {
      await _session.exportSnapshot(safetyPath);
      _validator.validate(safetyPath);
      await _session.closeForReplacement();
      try {
        await _store.deleteDatabaseFiles(_locator.liveDatabasePath);
        await _store.materializeBackup(
          sourcePath: source,
          liveDatabasePath: _locator.liveDatabasePath,
        );
        await _session.openAfterReplacement();
        return RestoreOutcome.completed;
      } catch (_) {
        try {
          await _rollback(safetyPath);
        } on RestoreFailed {
          keepSafety = true;
          rethrow;
        }
        throw const RestoreRolledBack();
      }
    } finally {
      if (!keepSafety) {
        await _store.deleteFileIfExists(safetyPath);
      }
      _busy = false;
    }
  }

  Future<void> _exportAtomically(String destination) async {
    final tempPath = p.join(
      p.dirname(destination),
      'accord_memo.export-${_idGenerator.next()}.db',
    );
    try {
      await _session.exportSnapshot(tempPath);
      _validator.validate(tempPath);
      await _store.replaceAtomically(
        fromTemp: tempPath,
        destination: destination,
      );
    } catch (error) {
      await _store.deleteFileIfExists(tempPath);
      rethrow;
    }
  }

  Future<void> _rollback(String safetyPath) async {
    try {
      await _store.deleteDatabaseFiles(_locator.liveDatabasePath);
      await _store.materializeBackup(
        sourcePath: safetyPath,
        liveDatabasePath: _locator.liveDatabasePath,
      );
      await _session.openAfterReplacement();
    } catch (_) {
      throw const RestoreFailed();
    }
  }
}
