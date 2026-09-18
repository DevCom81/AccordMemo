import 'package:accord_memo/application/backup/backup_file_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('propose un nom local AccordMemo_backup_YYYY-MM-DD_HH-mm.db', () {
    expect(
      suggestedBackupFileName(DateTime(2026, 9, 18, 8, 5)),
      'AccordMemo_backup_2026-09-18_08-05.db',
    );
  });
}
