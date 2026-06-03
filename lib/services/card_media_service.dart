import 'dart:io';

import 'package:edge_detection_scan/android_doc_scanner.dart';
import 'package:edge_detection_scan/edge_detection_scan.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:card_box/services/card_media_store.dart' as media_store;

class CardMediaService {
  CardMediaService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _edgeDetectionScan = EdgeDetectionScan();

  final ImagePicker _imagePicker;
  final EdgeDetectionScan _edgeDetectionScan;

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

  Future<String?> editPhoto({
    required String existingPath,
    required String cardId,
    required String side,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: existingPath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: <PlatformUiSettings>[
        AndroidUiSettings(
          toolbarTitle: 'Edit card photo',
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Edit card photo',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: false,
        ),
      ],
    );
    if (cropped == null) {
      return null;
    }
    final bytes = await File(cropped.path).readAsBytes();
    return media_store.storeImageBytes(
      bytes,
      sourcePath: cropped.path,
      cardId: cardId,
      side: side,
    );
  }

  Future<String?> scanCardPhoto({
    required String cardId,
    required String side,
  }) async {
    try {
      final imagePath = await _scanSinglePage();
      if (imagePath == null) {
        return null;
      }
      final bytes = await File(imagePath).readAsBytes();
      return media_store.storeImageBytes(
        bytes,
        sourcePath: imagePath,
        cardId: cardId,
        side: side,
      );
    } on PlatformException catch (error) {
      final message = error.message?.toLowerCase() ?? '';
      if (message.contains('cancel')) {
        return null;
      }
      rethrow;
    }
  }

  Future<String?> _scanSinglePage() async {
    if (Platform.isAndroid) {
      final result = await DocumentScanner(
        options: DocumentScannerOptions(
          pageLimit: 1,
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          isGalleryImport: false,
        ),
      ).scanDocument();
      if (result.images.isEmpty) {
        return null;
      }
      return result.images.first;
    }

    if (Platform.isIOS) {
      final result = await _edgeDetectionScan.scanDocument();
      if (result.isEmpty) {
        return null;
      }
      return result.first;
    }

    throw UnsupportedError('Card scanning is not supported on this platform.');
  }
}
