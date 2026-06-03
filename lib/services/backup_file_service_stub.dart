import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/models/exported_file_info.dart';
import 'package:card_box/models/imported_backup.dart';

class BackupFileService {
  const BackupFileService();

  Future<BackupFileInfo?> createBackupFile({
    required String rawJson,
    required int cardCount,
    String fileNamePrefix = 'card_box_backup',
  }) async {
    throw UnsupportedError('Backup file creation is not supported here.');
  }

  Future<ExportedFileInfo?> createTextFile({
    required String content,
    required String fileNamePrefix,
    required String extension,
  }) async {
    throw UnsupportedError('File export is not supported here.');
  }

  Future<ImportedBackup?> pickBackupFile() async {
    throw UnsupportedError('Backup import is not supported here.');
  }
}
