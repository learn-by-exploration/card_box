import 'dart:typed_data';

import 'package:card_box/services/card_media_store.dart' as media_store;

class StoredImageBackupData {
  const StoredImageBackupData({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

abstract class CardMediaManager {
  Future<StoredImageBackupData?> readImageForBackup(String path);

  Future<String> storeImportedImage({
    required String cardId,
    required String side,
    required Uint8List bytes,
    required String extension,
  });

  Future<void> deleteImage(String path);

  Future<bool> exists(String path);
}

class DefaultCardMediaManager implements CardMediaManager {
  const DefaultCardMediaManager();

  @override
  Future<void> deleteImage(String path) => media_store.deleteStoredImage(path);

  @override
  Future<bool> exists(String path) => media_store.storedImageExists(path);

  @override
  Future<StoredImageBackupData?> readImageForBackup(String path) {
    return media_store.readStoredImageForBackup(path);
  }

  @override
  Future<String> storeImportedImage({
    required String cardId,
    required String side,
    required Uint8List bytes,
    required String extension,
  }) {
    return media_store.storeImportedImageBytes(
      cardId: cardId,
      side: side,
      bytes: bytes,
      extension: extension,
    );
  }
}
