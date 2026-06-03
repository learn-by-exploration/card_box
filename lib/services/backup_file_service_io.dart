import 'dart:io';

import 'package:flutter/foundation.dart';
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
    if (backupDirectory == null) {
      return null;
    }
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

  Future<Directory?> _backupDirectory() async {
    if (_supportsDirectoryPicking()) {
      final path = await getDirectoryPath(
        confirmButtonText: 'Save backup here',
      );
      if (path == null || path.isEmpty) {
        return null;
      }
      return Directory(path);
    }
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/backups');
  }

  bool _supportsDirectoryPicking() {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.linux => true,
      TargetPlatform.macOS => true,
      TargetPlatform.windows => true,
      TargetPlatform.iOS => false,
      TargetPlatform.fuchsia => false,
    };
  }
}
