import 'package:flutter/services.dart';

import '../../application/backup/backup_file_access.dart';

final class AndroidBackupFileAccess implements BackupFileAccess {
  const AndroidBackupFileAccess({
    this._channel = const MethodChannel('accordmemo/backup_documents'),
  });

  final MethodChannel _channel;

  @override
  Future<BackupFileSelection?> selectSave({required String suggestedFileName}) =>
      _select('create', {'name': suggestedFileName});

  @override
  Future<BackupFileSelection?> selectOpen() => _select('open', null);

  Future<BackupFileSelection?> _select(String method, Object? arguments) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      method,
      arguments,
    );
    if (result == null) {
      return null;
    }
    return _DocumentSelection(
      channel: _channel,
      id: result['id'] as String,
      localPath: result['path'] as String,
    );
  }
}

final class _DocumentSelection implements BackupFileSelection {
  _DocumentSelection({
    required this._channel,
    required this._id,
    required this.localPath,
  });

  final MethodChannel _channel;
  final String _id;
  @override
  final String localPath;

  @override
  Future<void> commit() => _channel.invokeMethod<void>('commit', {'id': _id});

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('dispose', {'id': _id});
}
