import 'package:path/path.dart' as p;

import '../../domain/clock.dart';
import '../ports/id_generator.dart';
import 'app_data_locator.dart';
import 'app_database_session.dart';
import 'backup_exceptions.dart';
import 'backup_file_access.dart';
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
    this._fileAccess,
  });

  final Clock _clock;
  final IdGenerator _idGenerator;
  final AppDataLocator _locator;
  final FileLocationPicker _picker;
  final BackupValidator _validator;
  final BackupStore _store;
  final AppDatabaseSession _session;
  final BackupFileAccess? _fileAccess;
  var _busy = false;

  String get displayLocation => _locator.displayLocation;

  Future<BackupOutcome> backup({String? destinationPath}) async {
    if (_busy) {
      throw const BackupBusy();
    }
    _busy = true;
    BackupFileSelection? selection;
    try {
      final name = suggestedBackupFileName(_clock.now());
      if (destinationPath == null && _fileAccess != null) {
        selection = await _fileAccess.selectSave(suggestedFileName: name);
        if (selection == null) {
          return BackupOutcome.cancelled;
        }
      }
      final destination = destinationPath ??
          selection?.localPath ??
          await _picker.pickSaveLocation(suggestedFileName: name);
      if (destination == null) {
        return BackupOutcome.cancelled;
      }
      await _exportAtomically(destination);
      await selection?.commit();
      return BackupOutcome.completed;
    } finally {
      try {
        await selection?.dispose();
      } finally {
        _busy = false;
      }
    }
  }

  Future<RestoreOutcome> restore({
    String? sourcePath,
    Future<bool> Function()? confirm,
  }) async {
    if (_busy) {
      throw const BackupBusy();
    }
    _busy = true;
    BackupFileSelection? selection;
    try {
      if (sourcePath == null && _fileAccess != null) {
        selection = await _fileAccess.selectOpen();
        if (selection == null) {
          return RestoreOutcome.cancelled;
        }
      }
      final source = sourcePath ??
          selection?.localPath ??
          await _picker.pickOpenLocation();
      if (source == null) {
        return RestoreOutcome.cancelled;
      }
      _validator.validate(source);
      if (confirm != null && !await confirm()) {
        return RestoreOutcome.cancelled;
      }
      return await _restoreValidated(source);
    } finally {
      try {
        await selection?.dispose();
      } finally {
        _busy = false;
      }
    }
  }

  Future<RestoreOutcome> _restoreValidated(String source) async {
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
