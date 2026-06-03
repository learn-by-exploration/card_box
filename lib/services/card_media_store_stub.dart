import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'package:card_box/services/card_media_manager.dart';

Future<String> storePickedImage(
  XFile file, {
  required String cardId,
  required String side,
}) async {
  return file.path;
}

Future<void> deleteStoredImage(String path) async {}

Future<bool> storedImageExists(String path) async {
  return path.isNotEmpty;
}

Future<StoredImageBackupData?> readStoredImageForBackup(String path) async {
  return null;
}

Future<String> storeImportedImageBytes({
  required String cardId,
  required String side,
  required Uint8List bytes,
  required String extension,
}) async {
  return '$cardId-$side$extension';
}
