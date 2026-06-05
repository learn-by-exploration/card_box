import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:card_box/services/card_media_exception.dart';
import 'package:card_box/services/card_media_store.dart' as media_store;
import 'package:card_box/services/ios_document_scanner.dart';

class CardMediaService {
  CardMediaService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;
  final IosDocumentScanner _iosDocumentScanner = IosDocumentScanner();

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
    try {
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
      final storedPath = await media_store.storeImageBytes(
        bytes,
        sourcePath: cropped.path,
        cardId: cardId,
        side: side,
      );
      if (cropped.path != existingPath) {
        await _deleteTemporaryFiles(<String>[cropped.path]);
      }
      return storedPath;
    } on PlatformException catch (error) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        throw CardMediaException(message);
      }
      throw const CardMediaException(
        'The photo editor could not be opened on this device.',
      );
    } catch (_) {
      throw const CardMediaException(
        'The photo editor could not be opened on this device.',
      );
    }
  }

  Future<SmartScanPhotoResult?> scanCardPhoto({
    required String cardId,
    required String side,
  }) async {
    final capture = await _scanSinglePage();
    if (capture == null) {
      return null;
    }
    try {
      final bytes = await File(capture.file.path).readAsBytes();
      return await media_store
          .storeImageBytes(
            bytes,
            sourcePath: capture.file.path,
            cardId: cardId,
            side: side,
          )
          .then(
            (path) => SmartScanPhotoResult(
              path: path,
              noticeMessage: capture.noticeMessage,
            ),
          );
    } finally {
      await _deleteTemporaryFiles(capture.cleanupPaths);
    }
  }

  Future<_SmartScanCapture?> _scanSinglePage() async {
    if (Platform.isAndroid) {
      final scanned = await _tryAndroidDocumentScanner();
      switch (scanned.status) {
        case _SmartScanStatus.success:
          return scanned.capture;
        case _SmartScanStatus.cancelled:
          return null;
        case _SmartScanStatus.failedToLaunch:
          final fallbackNotice = _buildFallbackNotice(scanned.message);
          return _captureAndCropSinglePage(noticeMessage: fallbackNotice);
      }
    }

    if (Platform.isIOS) {
      final path = await _iosDocumentScanner.scanSinglePage();
      if (path == null) {
        return null;
      }
      return _SmartScanCapture(file: File(path), cleanupPaths: <String>[path]);
    }

    throw UnsupportedError('Card scanning is not supported on this platform.');
  }

  Future<_DocumentScannerResult> _tryAndroidDocumentScanner() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        pageLimit: 1,
        documentFormats: const <DocumentFormat>{DocumentFormat.jpeg},
        mode: ScannerMode.full,
        isGalleryImport: false,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) {
        return const _DocumentScannerResult.cancelled();
      }
      return _DocumentScannerResult.success(
        _SmartScanCapture(
          file: File(images.first),
          cleanupPaths: <String>[images.first],
        ),
      );
    } on PlatformException catch (error) {
      final message = error.message?.toLowerCase() ?? '';
      if (message.contains('cancel')) {
        return const _DocumentScannerResult.cancelled();
      }
      return _DocumentScannerResult.failedToLaunch(error.message?.trim());
    } catch (error) {
      return _DocumentScannerResult.failedToLaunch(error.toString());
    } finally {
      await scanner.close();
    }
  }

  Future<_SmartScanCapture?> _captureAndCropSinglePage({
    String? noticeMessage,
  }) async {
    if (Platform.isAndroid) {
      try {
        final picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
        );
        if (picked == null) {
          return null;
        }

        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 92,
          uiSettings: <PlatformUiSettings>[
            AndroidUiSettings(
              toolbarTitle: 'Smart scan card',
              lockAspectRatio: false,
              hideBottomControls: false,
            ),
          ],
        );

        if (cropped == null) {
          await _deleteTemporaryFiles(<String>[picked.path]);
          return null;
        }

        final cleanupPaths = <String>[picked.path];
        if (cropped.path != picked.path) {
          cleanupPaths.add(cropped.path);
        }

        return _SmartScanCapture(
          file: File(cropped.path),
          cleanupPaths: cleanupPaths,
          noticeMessage: noticeMessage,
        );
      } on PlatformException catch (error) {
        final message = error.message?.toLowerCase() ?? '';
        if (message.contains('cancel')) {
          return null;
        }
        final readable = error.message?.trim();
        throw CardMediaException(
          readable?.isNotEmpty == true
              ? readable!
              : 'The card scanner could not be opened on this device.',
        );
      } catch (_) {
        throw const CardMediaException(
          'The card scanner could not be opened on this device.',
        );
      }
    }
    return null;
  }

  String _buildFallbackNotice(String? launchFailureMessage) {
    const baseMessage =
        'Guided Smart scan was unavailable on this device, so Card Box switched to camera capture and crop.';
    final detail = launchFailureMessage?.trim();
    if (detail == null || detail.isEmpty) {
      return baseMessage;
    }
    return '$baseMessage Reason: $detail';
  }

  Future<void> _deleteTemporaryFiles(List<String> paths) async {
    for (final path in paths.toSet()) {
      final trimmed = path.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final file = File(trimmed);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

class _SmartScanCapture {
  const _SmartScanCapture({
    required this.file,
    required this.cleanupPaths,
    this.noticeMessage,
  });

  final File file;
  final List<String> cleanupPaths;
  final String? noticeMessage;
}

enum _SmartScanStatus { success, cancelled, failedToLaunch }

class _DocumentScannerResult {
  const _DocumentScannerResult._({
    required this.status,
    this.capture,
    this.message,
  });

  const _DocumentScannerResult.success(_SmartScanCapture capture)
    : this._(status: _SmartScanStatus.success, capture: capture);

  const _DocumentScannerResult.cancelled()
    : this._(status: _SmartScanStatus.cancelled);

  const _DocumentScannerResult.failedToLaunch([String? message])
    : this._(status: _SmartScanStatus.failedToLaunch, message: message);

  final _SmartScanStatus status;
  final _SmartScanCapture? capture;
  final String? message;
}

class SmartScanPhotoResult {
  const SmartScanPhotoResult({required this.path, this.noticeMessage});

  final String path;
  final String? noticeMessage;
}
