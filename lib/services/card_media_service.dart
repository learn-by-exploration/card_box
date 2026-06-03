import 'package:image_picker/image_picker.dart';

import 'package:card_box/services/card_media_store.dart' as media_store;

class CardMediaService {
  CardMediaService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<String?> capturePhoto({
    required String cardId,
    required String side,
  }) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    if (picked == null) {
      return null;
    }
    return media_store.storePickedImage(picked, cardId: cardId, side: side);
  }

  Future<String?> selectPhoto({
    required String cardId,
    required String side,
  }) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) {
      return null;
    }
    return media_store.storePickedImage(picked, cardId: cardId, side: side);
  }
}
