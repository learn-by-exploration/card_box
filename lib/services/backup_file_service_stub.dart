import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/models/imported_backup.dart';

class BackupFileService {
  Future<BackupFileInfo?> createBackupFile({
    required String rawJson,
    required int cardCount,
    String fileNamePrefix = 'card_box_backup',
  }) async {
    throw UnsupportedError('Backup file creation is not supported here.');
  }

  Future<ImportedBackup?> pickBackupFile() async {
    throw UnsupportedError('Backup import is not supported here.');
  }
}
