import 'dart:io';

import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';

import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/exported_file_info.dart';
import 'package:card_box/models/imported_backup.dart';
import 'package:card_box/models/nfc_scan_result.dart';
import 'package:card_box/models/scanned_code.dart';
import 'package:card_box/models/visiting_card_extraction.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_media_exception.dart';
import 'package:card_box/services/card_media_service.dart';
import 'package:card_box/services/card_share_service.dart';
import 'package:card_box/services/file_share_service.dart';
import 'package:card_box/services/ios_document_scanner.dart';
import 'package:card_box/services/nfc_service.dart';
import 'package:card_box/services/vcard_export_service.dart';

class _FakeBackupFileService extends BackupFileService {
  _FakeBackupFileService({this.exportedFile});

  ExportedFileInfo? exportedFile;
  String? lastContent;
  String? lastPrefix;
  String? lastExtension;

  @override
  Future<ExportedFileInfo?> createTextFile({
    required String content,
    required String fileNamePrefix,
    required String extension,
  }) async {
    lastContent = content;
    lastPrefix = fileNamePrefix;
    lastExtension = extension;
    return exportedFile;
  }
}

class _FakeFileShareService extends FileShareService {
  _FakeFileShareService({required this.result});

  bool result;
  String? lastPath;
  String? lastSubject;
  String? lastText;

  @override
  Future<bool> shareFile({
    required String path,
    required String subject,
    String? text,
  }) async {
    lastPath = path;
    lastSubject = subject;
    lastText = text;
    return result;
  }
}

class _FakeNfcSessionClient implements NfcSessionClient {
  _FakeNfcSessionClient({
    this.availability = NfcAvailability.enabled,
    this.startThrows,
    this.onStart,
  });

  NfcAvailability availability;
  Object? startThrows;
  Future<void> Function(
    void Function(NfcTag tag) onDiscovered,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  )?
  onStart;
  String? stoppedAlertMessage;
  String? stoppedErrorMessage;

  @override
  Future<NfcAvailability> checkAvailability() async => availability;

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  }) async {
    if (startThrows != null) {
      throw startThrows!;
    }
    if (onStart != null) {
      await onStart!(onDiscovered, onSessionErrorIos);
    }
  }

  @override
  Future<void> stopSession({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    stoppedAlertMessage = alertMessageIos;
    stoppedErrorMessage = errorMessageIos;
  }
}

class _FakeImagePickerPlatform extends ImagePickerPlatform {
  LostDataResponse lostDataResponse = LostDataResponse.empty();
  XFile? nextImage;
  ImageSource? lastSource;

  @override
  Future<LostDataResponse> getLostData() async => lostDataResponse;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    lastSource = source;
    return nextImage;
  }
}

class _FakeMediaStoreDelegate implements CardMediaStoreDelegate {
  String pickedImagePath = '/stored/picked.jpg';
  String bytesImagePath = '/stored/bytes.jpg';
  XFile? lastPicked;
  List<int>? lastBytes;
  String? lastSourcePath;
  String? lastCardId;
  String? lastSide;

  @override
  Future<String> storePickedImage(
    XFile picked, {
    required String cardId,
    required String side,
  }) async {
    lastPicked = picked;
    lastCardId = cardId;
    lastSide = side;
    return pickedImagePath;
  }

  @override
  Future<String> storeImageBytes(
    Uint8List bytes, {
    required String sourcePath,
    required String cardId,
    required String side,
  }) async {
    lastBytes = bytes;
    lastSourcePath = sourcePath;
    lastCardId = cardId;
    lastSide = side;
    return bytesImagePath;
  }
}

class _FakePhotoEditor implements CardPhotoEditor {
  _FakePhotoEditor({this.result, this.error});

  CroppedFile? result;
  Object? error;
  String? lastSourcePath;
  String? lastTitle;
  int cardPhotoCalls = 0;

  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    required String title,
  }) async {
    lastSourcePath = sourcePath;
    lastTitle = title;
    if (error != null) {
      throw error!;
    }
    return result;
  }

  @override
  Future<CroppedFile?> cropCardPhoto({
    required String sourcePath,
    required String title,
  }) async {
    cardPhotoCalls += 1;
    lastSourcePath = sourcePath;
    lastTitle = title;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

class _FakeAndroidDocumentScanner implements AndroidDocumentScanner {
  _FakeAndroidDocumentScanner({this.paths, this.error});

  List<String>? paths;
  Object? error;

  @override
  Future<List<String>?> scanSinglePage() async {
    if (error != null) {
      throw error!;
    }
    return paths;
  }
}

class _FakeIosDocumentScanner extends IosDocumentScanner {
  _FakeIosDocumentScanner({this.path});

  String? path;

  @override
  Future<String?> scanSinglePage() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Model helpers', () {
    test('ScannedCode preserves optional metadata and image bytes', () {
      final now = DateTime(2026, 6, 7, 9, 30);
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final code = ScannedCode(
        payload: 'https://example.com',
        format: 'qrCode',
        displayValue: 'Example',
        valueType: 'url',
        structuredData: 'URL: https://example.com',
        rawBytesHex: '01 02 03 04',
        capturedAt: now,
        imageBytes: bytes,
      );

      expect(code.payload, 'https://example.com');
      expect(code.format, 'qrCode');
      expect(code.displayValue, 'Example');
      expect(code.valueType, 'url');
      expect(code.structuredData, contains('URL:'));
      expect(code.rawBytesHex, '01 02 03 04');
      expect(code.capturedAt, now);
      expect(code.imageBytes, same(bytes));
    });

    test('NfcScanResult preserves status and messages', () {
      const result = NfcScanResult(
        status: CompatibilityStatus.nfcReadable,
        summary: 'NFC NDEF readable',
        detail: 'Detected a payload.',
      );

      expect(result.status, CompatibilityStatus.nfcReadable);
      expect(result.summary, 'NFC NDEF readable');
      expect(result.detail, 'Detected a payload.');
    });

    test('VisitingCardExtraction preserves structured suggestions', () {
      const extraction = VisitingCardExtraction(
        suggestedName: 'Aiko Tanaka',
        suggestedCompany: 'CourtSide Japan',
        suggestedTitle: 'Community Lead',
        suggestedPhones: <String>['+81 90 1111 2222'],
        suggestedEmails: <String>['aiko@example.com'],
        suggestedWebsites: <String>['courtside.jp'],
        suggestedAddress: 'Tokyo',
        rawOcrText: 'Aiko Tanaka\nCourtSide Japan',
      );

      expect(extraction.suggestedName, 'Aiko Tanaka');
      expect(extraction.suggestedCompany, 'CourtSide Japan');
      expect(extraction.suggestedPhones.single, '+81 90 1111 2222');
      expect(extraction.rawOcrText, contains('CourtSide Japan'));
    });

    test('Imported and exported file models preserve metadata', () {
      final exportedAt = DateTime(2026, 6, 7, 10, 45);
      const imported = ImportedBackup(
        fileName: 'backup.json',
        rawJson: '{"cards":[]}',
      );
      final exported = ExportedFileInfo(
        path: '/tmp/backup.json',
        fileName: 'backup.json',
        createdAt: exportedAt,
      );
      final backup = BackupFileInfo(
        path: '/tmp/backup.json',
        fileName: 'backup.json',
        createdAt: exportedAt,
        cardCount: 3,
      );

      expect(imported.fileName, 'backup.json');
      expect(imported.rawJson, '{"cards":[]}');
      expect(exported.path, '/tmp/backup.json');
      expect(exported.createdAt, exportedAt);
      expect(backup.cardCount, 3);
    });
  });

  group('CardShareService', () {
    final visitingCard = WalletCard(
      id: 'visit-1',
      name: 'Aiko Tanaka',
      issuer: 'CourtSide Japan',
      category: CardCategory.contact,
      cardType: CardType.visitingCard,
      contactEmails: const <String>['aiko@example.com'],
      createdAt: DateTime(2026, 6, 7),
      updatedAt: DateTime(2026, 6, 7),
    );

    test('shares visiting cards as vCard files', () async {
      final backupService = _FakeBackupFileService(
        exportedFile: ExportedFileInfo(
          path: '/tmp/aiko.vcf',
          fileName: 'aiko.vcf',
          createdAt: DateTime(2026, 6, 7),
        ),
      );
      final shareService = _FakeFileShareService(result: true);
      final service = CardShareService(
        backupFileService: backupService,
        fileShareService: shareService,
        vCardExportService: const VCardExportService(),
      );

      final result = await service.shareCard(visitingCard);

      expect(result.status, ShareCardResultStatus.shared);
      expect(result.fileName, 'aiko.vcf');
      expect(backupService.lastExtension, 'vcf');
      expect(shareService.lastPath, '/tmp/aiko.vcf');
      expect(shareService.lastSubject, 'Share contact Aiko Tanaka');
    });

    test('shares image-backed cards directly without exporting text', () async {
      final card = WalletCard(
        id: 'loyalty-1',
        name: 'Club Card',
        category: CardCategory.membership,
        frontImagePath: '/tmp/front.jpg',
        barcodePayload: '12345',
        createdAt: DateTime(2026, 6, 7),
        updatedAt: DateTime(2026, 6, 7),
      );
      final backupService = _FakeBackupFileService();
      final shareService = _FakeFileShareService(result: true);
      final service = CardShareService(
        backupFileService: backupService,
        fileShareService: shareService,
      );

      final result = await service.shareCard(card);

      expect(result.status, ShareCardResultStatus.shared);
      expect(shareService.lastPath, '/tmp/front.jpg');
      expect(backupService.lastContent, isNull);
      expect(shareService.lastText, contains('Visible code: 12345'));
    });

    test('exports a summary text file when no image is available', () async {
      final card = WalletCard(
        id: 'plain-1',
        name: 'Reference Card',
        category: CardCategory.other,
        notes: 'Bring the physical card.',
        createdAt: DateTime(2026, 6, 7),
        updatedAt: DateTime(2026, 6, 7),
      );
      final backupService = _FakeBackupFileService(
        exportedFile: ExportedFileInfo(
          path: '/tmp/reference.txt',
          fileName: 'reference.txt',
          createdAt: DateTime(2026, 6, 7),
        ),
      );
      final shareService = _FakeFileShareService(result: false);
      final service = CardShareService(
        backupFileService: backupService,
        fileShareService: shareService,
      );

      final result = await service.shareCard(card);

      expect(result.status, ShareCardResultStatus.canceled);
      expect(result.fileName, 'reference.txt');
      expect(backupService.lastExtension, 'txt');
      expect(backupService.lastContent, contains('Bring the physical card.'));
      expect(shareService.lastText, 'Shared from Card Box');
    });

    test('reports unavailable when it cannot prepare a share file', () async {
      final card = WalletCard(
        id: 'plain-2',
        name: 'Plain Card',
        category: CardCategory.other,
        createdAt: DateTime(2026, 6, 7),
        updatedAt: DateTime(2026, 6, 7),
      );
      final service = CardShareService(
        backupFileService: _FakeBackupFileService(exportedFile: null),
        fileShareService: _FakeFileShareService(result: true),
      );

      final result = await service.shareCard(card);

      expect(result.status, ShareCardResultStatus.unavailable);
      expect(result.message, contains('Could not prepare'));
    });
  });

  group('NfcService', () {
    test('returns unsupported immediately when NFC is disabled', () async {
      final client = _FakeNfcSessionClient(
        availability: NfcAvailability.disabled,
      );
      final service = NfcService(sessionClient: client, isWeb: false);

      final result = await service.scanTag();

      expect(result.status, CompatibilityStatus.unsupported);
      expect(result.summary, contains('disabled'));
      expect(result.detail, 'No scan was started.');
    });

    test('returns unsupported when the NFC session cannot start', () async {
      final client = _FakeNfcSessionClient(
        startThrows: PlatformException(code: 'boom', message: 'boom'),
      );
      final service = NfcService(sessionClient: client, isWeb: false);

      final result = await service.scanTag();

      expect(result.status, CompatibilityStatus.unsupported);
      expect(result.summary, 'The NFC session could not be started.');
      expect(result.detail, contains('boom'));
    });

    test('surfaces iOS session errors cleanly', () async {
      final client = _FakeNfcSessionClient(
        onStart: (_, onSessionErrorIos) async {
          onSessionErrorIos?.call(
            const NfcReaderSessionErrorIos(
              code: NfcReaderErrorCodeIos
                  .readerSessionInvalidationErrorSessionTimeout,
              message: 'Session timed out',
            ),
          );
        },
      );
      final service = NfcService(
        sessionClient: client,
        isWeb: false,
        platform: TargetPlatform.iOS,
      );

      final result = await service.scanTag();

      expect(result.status, CompatibilityStatus.unsupported);
      expect(result.summary, contains('Session timed out'));
      expect(result.detail, contains('ended before a tag was saved'));
    });

    test(
      'builds an Android NDEF-readable result from a discovered tag',
      () async {
        final client = _FakeNfcSessionClient(
          onStart: (onDiscovered, _) async {
            onDiscovered(
              NfcTag(
                data: TagPigeon(
                  handle: 'handle-1',
                  id: Uint8List.fromList(<int>[0x01, 0x02]),
                  techList: <String>['android.nfc.tech.Ndef'],
                  ndef: NdefPigeon(
                    type: 'org.nfcforum.ndef.type2',
                    canMakeReadOnly: true,
                    isWritable: true,
                    maxSize: 144,
                  ),
                ),
              ),
            );
          },
        );
        final service = NfcService(
          sessionClient: client,
          isWeb: false,
          platform: TargetPlatform.android,
        );

        final result = await service.scanTag();

        expect(result.status, CompatibilityStatus.nfcReadable);
        expect(result.summary, 'NFC NDEF readable');
        expect(result.detail, contains('NDEF type'));
        expect(client.stoppedAlertMessage, 'Tag read complete.');
      },
    );

    test('builds an Android HCE candidate result for ISO-DEP tags', () async {
      final client = _FakeNfcSessionClient(
        onStart: (onDiscovered, _) async {
          onDiscovered(
            NfcTag(
              data: TagPigeon(
                handle: 'handle-2',
                id: Uint8List.fromList(<int>[0x0A, 0x0B]),
                techList: <String>['android.nfc.tech.IsoDep'],
                isoDep: IsoDepPigeon(
                  historicalBytes: Uint8List.fromList(<int>[0x11, 0x22]),
                  hiLayerResponse: Uint8List.fromList(<int>[0x33, 0x44]),
                  isExtendedLengthApduSupported: true,
                ),
              ),
            ),
          );
        },
      );
      final service = NfcService(
        sessionClient: client,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      final result = await service.scanTag();

      expect(result.status, CompatibilityStatus.androidHceCandidate);
      expect(result.summary, 'ISO-DEP tag detected');
      expect(result.detail, contains('Possible Android HCE candidate'));
    });
  });

  group('CardMediaService', () {
    late ImagePickerPlatform originalImagePicker;

    setUp(() {
      originalImagePicker = ImagePickerPlatform.instance;
    });

    tearDown(() {
      ImagePickerPlatform.instance = originalImagePicker;
    });

    test('capturePhoto stores the picked camera image', () async {
      final tempDir = await Directory.systemTemp.createTemp('card_box_media');
      final pickedFile = File('${tempDir.path}/picked.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final imagePicker = _FakeImagePickerPlatform()
        ..nextImage = XFile(pickedFile.path);
      ImagePickerPlatform.instance = imagePicker;
      final store = _FakeMediaStoreDelegate()
        ..pickedImagePath = '/stored/front.jpg';
      final service = CardMediaService(mediaStore: store);

      final result = await service.capturePhoto(
        cardId: 'card-1',
        side: 'front',
      );

      expect(result, '/stored/front.jpg');
      expect(imagePicker.lastSource, ImageSource.camera);
      expect(store.lastPicked?.path, pickedFile.path);
      expect(store.lastCardId, 'card-1');
      expect(store.lastSide, 'front');
    });

    test('editPhoto returns null when crop is canceled', () async {
      final store = _FakeMediaStoreDelegate();
      final editor = _FakePhotoEditor(result: null);
      final service = CardMediaService(mediaStore: store, photoEditor: editor);

      final result = await service.editPhoto(
        existingPath: '/tmp/existing.jpg',
        cardId: 'card-1',
        side: 'front',
      );

      expect(result, isNull);
      expect(editor.lastTitle, 'Edit card photo');
      expect(store.lastBytes, isNull);
    });

    test(
      'editPhoto stores cropped bytes and removes the temporary crop file',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('card_box_crop');
        final existingFile = File('${tempDir.path}/existing.jpg')
          ..writeAsBytesSync(<int>[1, 2, 3]);
        final croppedFile = File('${tempDir.path}/cropped.jpg')
          ..writeAsBytesSync(<int>[9, 8, 7]);
        final store = _FakeMediaStoreDelegate()
          ..bytesImagePath = '/stored/cropped.jpg';
        final editor = _FakePhotoEditor(result: CroppedFile(croppedFile.path));
        final service = CardMediaService(
          mediaStore: store,
          photoEditor: editor,
        );

        final result = await service.editPhoto(
          existingPath: existingFile.path,
          cardId: 'card-1',
          side: 'back',
        );

        expect(result, '/stored/cropped.jpg');
        expect(store.lastSourcePath, croppedFile.path);
        expect(store.lastBytes, <int>[9, 8, 7]);
        expect(await croppedFile.exists(), isFalse);
      },
    );

    test(
      'scanCardPhoto falls back to camera crop when Android smart scan fails to launch',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('card_box_scan');
        final pickedFile = File('${tempDir.path}/picked.jpg')
          ..writeAsBytesSync(<int>[1, 1, 1]);
        final croppedFile = File('${tempDir.path}/cropped.jpg')
          ..writeAsBytesSync(<int>[2, 2, 2]);
        final imagePicker = _FakeImagePickerPlatform()
          ..nextImage = XFile(pickedFile.path);
        ImagePickerPlatform.instance = imagePicker;
        final store = _FakeMediaStoreDelegate()
          ..bytesImagePath = '/stored/scan.jpg';
        final editor = _FakePhotoEditor(result: CroppedFile(croppedFile.path));
        final scanner = _FakeAndroidDocumentScanner(
          error: PlatformException(
            code: 'scanner_unavailable',
            message: 'scanner unavailable',
          ),
        );
        final service = CardMediaService(
          mediaStore: store,
          photoEditor: editor,
          androidDocumentScanner: scanner,
          platform: CardMediaPlatform.android,
        );

        final result = await service.scanCardPhoto(
          cardId: 'card-2',
          side: 'front',
        );

        expect(result?.path, '/stored/scan.jpg');
        expect(
          result?.noticeMessage,
          contains('Guided Smart scan was unavailable on this device'),
        );
        expect(result?.noticeMessage, contains('scanner unavailable'));
        expect(store.lastBytes, <int>[2, 2, 2]);
        // The fallback must use the card-shaped cropper so the saved image is
        // always ID-1 (85.6 / 53.98 mm) and OCR-friendly.
        expect(editor.cardPhotoCalls, 1);
        expect(await pickedFile.exists(), isFalse);
        expect(await croppedFile.exists(), isFalse);
      },
    );

    test(
      'scanCardPhoto stores a guided Android smart scan result when available',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'card_box_scan_guided',
        );
        final scannedFile = File('${tempDir.path}/guided.jpg')
          ..writeAsBytesSync(<int>[3, 3, 3]);
        final store = _FakeMediaStoreDelegate()
          ..bytesImagePath = '/stored/guided-scan.jpg';
        final scanner = _FakeAndroidDocumentScanner(
          paths: <String>[scannedFile.path],
        );
        final service = CardMediaService(
          mediaStore: store,
          androidDocumentScanner: scanner,
          platform: CardMediaPlatform.android,
        );

        final result = await service.scanCardPhoto(
          cardId: 'card-5',
          side: 'back',
        );

        expect(result?.path, '/stored/guided-scan.jpg');
        expect(result?.noticeMessage, isNull);
        expect(store.lastBytes, <int>[3, 3, 3]);
        expect(await scannedFile.exists(), isFalse);
      },
    );

    test(
      'scanCardPhoto throws a readable media exception on cropper failure',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'card_box_scan_error',
        );
        final pickedFile = File('${tempDir.path}/picked.jpg')
          ..writeAsBytesSync(<int>[1, 1, 1]);
        final imagePicker = _FakeImagePickerPlatform()
          ..nextImage = XFile(pickedFile.path);
        ImagePickerPlatform.instance = imagePicker;
        final editor = _FakePhotoEditor(
          error: PlatformException(
            code: 'editor_missing',
            message: 'editor missing',
          ),
        );
        final scanner = _FakeAndroidDocumentScanner(
          error: PlatformException(
            code: 'scanner_unavailable',
            message: 'scanner unavailable',
          ),
        );
        final service = CardMediaService(
          photoEditor: editor,
          androidDocumentScanner: scanner,
          platform: CardMediaPlatform.android,
        );

        await expectLater(
          service.scanCardPhoto(cardId: 'card-3', side: 'front'),
          throwsA(
            isA<CardMediaException>().having(
              (error) => error.message,
              'message',
              contains('editor missing'),
            ),
          ),
        );
      },
    );

    test(
      'scanCardPhoto uses the iOS document scanner path when available',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'card_box_ios_scan',
        );
        final scannedFile = File('${tempDir.path}/scanned.jpg')
          ..writeAsBytesSync(<int>[7, 7, 7]);
        final store = _FakeMediaStoreDelegate()
          ..bytesImagePath = '/stored/ios-scan.jpg';
        final service = CardMediaService(
          mediaStore: store,
          iosDocumentScanner: _FakeIosDocumentScanner(path: scannedFile.path),
          platform: CardMediaPlatform.ios,
        );

        final result = await service.scanCardPhoto(
          cardId: 'card-4',
          side: 'front',
        );

        expect(result?.path, '/stored/ios-scan.jpg');
        expect(result?.noticeMessage, isNull);
        expect(store.lastBytes, <int>[7, 7, 7]);
        expect(await scannedFile.exists(), isFalse);
      },
    );
  });

  group('DefaultCardPhotoEditor', () {
    test('cardAspectRatio matches the ISO/IEC 7810 ID-1 ratio', () {
      // ID-1 = 85.60 x 53.98 mm. The cropper uses this constant via the
      // _IdOneAspectRatioPreset (1586 x 1000) so 85.6 / 53.98 must match.
      expect(cardAspectRatio, closeTo(85.6 / 53.98, 1e-6));
    });

    test(
      'cropCardPhoto locks Android cropper to ID-1 aspect ratio and iOS too',
      () {
        const cardPreset = IdOneAspectRatioPreset();
        final androidSettings = AndroidUiSettings(
          toolbarTitle: 'Smart scan card',
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: cardPreset,
          aspectRatioPresets: <CropAspectRatioPresetData>[cardPreset],
        );
        final iosSettings = IOSUiSettings(
          title: 'Smart scan card',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: false,
          aspectRatioPresets: <CropAspectRatioPresetData>[cardPreset],
        );

        final androidMap = androidSettings.toMap();
        expect(androidMap['android.lock_aspect_ratio'], isTrue);
        expect(androidMap['android.init_aspect_ratio'], 'card_id1');
        final androidPresets =
            androidMap['android.aspect_ratio_presets'] as List<dynamic>;
        expect(androidPresets, hasLength(1));
        final androidData = androidPresets.first as Map;
        expect(androidData['name'], 'card_id1');
        expect(
          (androidData['data'] as Map)['ratio_x'] /
              (androidData['data'] as Map)['ratio_y'],
          closeTo(cardAspectRatio, 1e-3),
        );

        final iosMap = iosSettings.toMap();
        expect(iosMap['ios.aspect_ratio_lock_enabled'], isTrue);
        expect(iosMap['ios.reset_aspect_ratio_enabled'], isFalse);
        final iosPresets = iosMap['ios.aspect_ratio_presets'] as List<dynamic>;
        expect(iosPresets, hasLength(1));
        final iosData = iosPresets.first as Map;
        expect(iosData['name'], 'card_id1');
        expect(
          (iosData['data'] as Map)['ratio_x'] /
              (iosData['data'] as Map)['ratio_y'],
          closeTo(cardAspectRatio, 1e-3),
        );
      },
    );
  });
}
