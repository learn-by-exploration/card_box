import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
    final exported = await createTextFile(
      content: rawJson,
      fileNamePrefix: fileNamePrefix,
      extension: 'json',
    );
    if (exported == null) {
      return null;
    }
    return BackupFileInfo(
      path: exported.path,
      fileName: exported.fileName,
      createdAt: exported.createdAt,
      cardCount: cardCount,
    );
  }

  Future<ExportedFileInfo?> createTextFile({
    required String content,
    required String fileNamePrefix,
    required String extension,
  }) async {
    final backupDirectory = await _backupDirectory();
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }
    final createdAt = DateTime.now();
    final fileName = _fileNameFor(
      createdAt,
      fileNamePrefix: fileNamePrefix,
      extension: extension,
    );
    final file = File('${backupDirectory.path}/$fileName');
    await file.writeAsString(content, flush: true);
    return ExportedFileInfo(
      path: file.path,
      fileName: fileName,
      createdAt: createdAt,
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

  String _fileNameFor(
    DateTime dateTime, {
    required String fileNamePrefix,
    required String extension,
  }) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$fileNamePrefix'
        '_$year$month${day}_$hour$minute$second.$extension';
  }

  Future<Directory> _backupDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory('${downloads.path}/Card Box');
      }
    } on UnsupportedError {
      // Some platforms (web, desktop) do not implement a downloads
      // directory. Fall through to app documents below.
    } on PlatformException {
      // The iOS Files app or Android scoped storage can return a
      // platform exception if the user has revoked access or the
      // picker is unavailable. Treat the same as unsupported and
      // fall back to the app documents directory.
    } on MissingPluginException {
      // In a test or on a stripped-down Flutter embedder, the
      // downloads channel is missing entirely. Fall back too.
    }
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/backups');
  }
}
