import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/models/imported_backup.dart';

class BackupFileService {
  Future<BackupFileInfo?> createBackupFile({
    required String rawJson,
    required int cardCount,
    String fileNamePrefix = 'card_box_backup',
  }) async {
    final backupDirectory = await _backupDirectory();
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }
    final createdAt = DateTime.now();
    final fileName = _fileNameFor(createdAt, fileNamePrefix: fileNamePrefix);
    final file = File('${backupDirectory.path}/$fileName');
    await file.writeAsString(rawJson, flush: true);
    return BackupFileInfo(
      path: file.path,
      fileName: fileName,
      createdAt: createdAt,
      cardCount: cardCount,
    );
  }

  Future<ImportedBackup?> pickBackupFile() async {
    const typeGroup = XTypeGroup(
      label: 'Card Box backup',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json', 'text/plain'],
      uniformTypeIdentifiers: <String>['public.json', 'public.plain-text'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) {
      return null;
    }
    final rawJson = await file.readAsString();
    return ImportedBackup(fileName: file.name, rawJson: rawJson);
  }

  String _fileNameFor(DateTime dateTime, {required String fileNamePrefix}) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '${fileNamePrefix}_$year$month${day}_$hour$minute$second.json';
  }

  Future<Directory> _backupDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory('${downloads.path}/Card Box');
      }
    } on UnsupportedError {
      // Fall through to app documents below.
    }
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/backups');
  }
}
