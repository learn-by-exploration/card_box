import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:card_box/services/card_media_manager.dart';

Future<String> storePickedImage(
  XFile file, {
  required String cardId,
  required String side,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final imageDirectory = Directory('${directory.path}/card_images');
  if (!await imageDirectory.exists()) {
    await imageDirectory.create(recursive: true);
  }
  final extension = _extensionFor(file.path);
  final safeCardId = cardId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final target = File(
    '${imageDirectory.path}/${safeCardId}_${side}_${DateTime.now().microsecondsSinceEpoch}$extension',
  );
  final bytes = await file.readAsBytes();
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<void> deleteStoredImage(String path) async {
  if (path.trim().isEmpty) {
    return;
  }
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<bool> storedImageExists(String path) async {
  if (path.trim().isEmpty) {
    return false;
  }
  return File(path).exists();
}

Future<StoredImageBackupData?> readStoredImageForBackup(String path) async {
  if (path.trim().isEmpty) {
    return null;
  }
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  return StoredImageBackupData(
    bytes: await file.readAsBytes(),
    extension: _extensionFor(path),
  );
}

Future<String> storeImportedImageBytes({
  required String cardId,
  required String side,
  required Uint8List bytes,
  required String extension,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final imageDirectory = Directory('${directory.path}/card_images');
  if (!await imageDirectory.exists()) {
    await imageDirectory.create(recursive: true);
  }
  final safeCardId = cardId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final safeExtension = _extensionFor('import$extension');
  final target = File(
    '${imageDirectory.path}/${safeCardId}_${side}_${DateTime.now().microsecondsSinceEpoch}$safeExtension',
  );
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

String _extensionFor(String path) {
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == path.length - 1) {
    return '.jpg';
  }
  final extension = path.substring(dotIndex);
  return extension.length > 8 ? '.jpg' : extension;
}
