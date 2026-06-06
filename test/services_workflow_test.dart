import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/services/media_recovery_service.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CardRepository', () {
    test(
      'CardDatabase stores normalized columns alongside payload JSON',
      () async {
        final database = createInMemoryDatabase();
        final card = WalletCard(
          id: 'db-card',
          name: 'Aiko Tanaka',
          issuer: 'CourtSide Japan',
          category: CardCategory.contact,
          notes: 'Met after practice',
          barcodePayload: 'AIKO-42',
          nfcTagSummary: 'ISO-DEP candidate',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        );

        await database.upsertCard(card);
        final row = await database.select(database.cardRecords).getSingle();

        expect(row.nameText, 'Aiko Tanaka');
        expect(row.issuerText, 'CourtSide Japan');
        expect(row.categoryName, CardCategory.contact.name);
        expect(row.compatibilityStatusName, card.compatibilityStatus.name);
        expect(row.searchText, contains('aiko tanaka'));
        expect(row.searchText, contains('courtside japan'));
        await database.close();
      },
    );

    test('cleans up replaced images when a card is updated', () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      mediaManager.seedImage(
        '/images/front_old.jpg',
        StoredImageBackupData(
          bytes: Uint8List.fromList([1, 2, 3]),
          extension: '.jpg',
        ),
      );
      mediaManager.seedImage(
        '/images/back_same.jpg',
        StoredImageBackupData(
          bytes: Uint8List.fromList([4, 5, 6]),
          extension: '.jpg',
        ),
      );
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'card-1',
          name: 'Badge',
          category: CardCategory.access,
          frontImagePath: '/images/front_old.jpg',
          backImagePath: '/images/back_same.jpg',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      await repository.upsert(
        repository
            .findById('card-1')!
            .copyWith(
              frontImagePath: '/images/front_new.jpg',
              backImagePath: '/images/back_same.jpg',
            ),
      );

      expect(mediaManager.deletedPaths, contains('/images/front_old.jpg'));
      expect(
        mediaManager.deletedPaths,
        isNot(contains('/images/back_same.jpg')),
      );
    });

    test('deletes stored images when a card is permanently removed', () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'card-2',
          name: 'Photo card',
          category: CardCategory.id,
          frontImagePath: '/images/front.jpg',
          backImagePath: '/images/back.jpg',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      await repository.deleteCard('card-2');

      expect(mediaManager.deletedPaths, contains('/images/front.jpg'));
      expect(mediaManager.deletedPaths, contains('/images/back.jpg'));
      expect(repository.findById('card-2'), isNull);
    });

    test(
      'importing an existing card replaces old images and keeps new ones',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = FakeCardMediaManager();
        mediaManager.seedImage(
          '/images/old_front.jpg',
          StoredImageBackupData(
            bytes: Uint8List.fromList([1, 1, 1]),
            extension: '.jpg',
          ),
        );
        final repository = CardRepository(
          database: createInMemoryDatabase(),
          mediaManager: mediaManager,
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'same-card',
            name: 'Old card',
            category: CardCategory.membership,
            frontImagePath: '/images/old_front.jpg',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        final importedCount = await repository.importPlainJson('''
        {
          "format": "card_box_plain_json",
          "version": 3,
          "cards": [
            {
              "id": "same-card",
              "name": "Updated card",
              "category": "membership",
              "frontImagePath": "",
              "createdAt": "2026-06-04T00:00:00.000",
              "updatedAt": "2030-06-04T00:00:00.000"
            }
          ],
          "images": [
            {
              "cardId": "same-card",
              "side": "front",
              "extension": ".jpg",
              "bytesBase64": "AQIDBA=="
            }
          ]
        }
        ''');

        expect(importedCount, 1);
        expect(mediaManager.deletedPaths, contains('/images/old_front.jpg'));
        expect(repository.findById('same-card')!.name, 'Updated card');
        expect(
          repository.findById('same-card')!.frontImagePath,
          '/imported/same-card_front.jpg',
        );
      },
    );

    test(
      'import keeps newer local cards instead of overwriting them',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = CardRepository(database: createInMemoryDatabase());
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'same-card',
            name: 'Local newer card',
            category: CardCategory.membership,
            notes: 'keep me',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        final result = await repository.importPlainJsonProtected('''
      {
        "format": "card_box_plain_json",
        "version": 3,
        "cards": [
          {
            "id": "same-card",
            "name": "Older backup card",
            "category": "membership",
            "notes": "stale backup",
            "createdAt": "2026-06-03T00:00:00.000",
            "updatedAt": "2026-06-03T00:00:00.000"
          }
        ]
      }
      ''');

        expect(result.importedCount, 0);
        expect(result.skippedOlderCount, 1);
        expect(repository.findById('same-card')!.name, 'Local newer card');
        expect(repository.findById('same-card')!.notes, 'keep me');
      },
    );

    test('backup preserves scanned barcode image attachments', () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      mediaManager.seedImage(
        '/images/code.jpg',
        StoredImageBackupData(
          bytes: Uint8List.fromList([7, 8, 9, 10]),
          extension: '.jpg',
        ),
      );
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'code-card',
          name: 'Store card',
          category: CardCategory.loyalty,
          barcodePayload: 'STORE-123',
          barcodeFormat: 'QRCode',
          barcodeImagePath: '/images/code.jpg',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      final exported = await repository.exportPlainJson();

      final importedMediaManager = FakeCardMediaManager();
      final importedRepository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: importedMediaManager,
      );
      await importedRepository.init();
      final result = await importedRepository.importPlainJsonProtected(
        exported,
      );

      expect(result.importedCount, 1);
      expect(
        importedRepository.findById('code-card')!.barcodeImagePath,
        '/imported/code-card_barcode.jpg',
      );
      expect(
        importedMediaManager.importedPaths,
        contains('/imported/code-card_barcode.jpg'),
      );
    });

    test('migrates custom-category cards into a built-in category', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'club-1',
          name: 'Court pass',
          category: CardCategory.other,
          customCategory: 'Sports Club',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      await repository.upsert(
        WalletCard(
          id: 'club-2',
          name: 'Archived club card',
          category: CardCategory.other,
          customCategory: 'Sports Club',
          archived: true,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      final movedCount = await repository.migrateCustomCategory(
        fromLabel: 'Sports Club',
        toCategory: CardCategory.membership,
      );

      expect(movedCount, 2);
      expect(repository.findById('club-1')!.category, CardCategory.membership);
      expect(repository.findById('club-1')!.customCategory, isNull);
      expect(repository.findById('club-2')!.category, CardCategory.membership);
      expect(repository.findById('club-2')!.archived, isTrue);
    });
  });

  group('CategoryService', () {
    test('adds, sorts, persists, and removes custom categories', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = CategoryService(preferences: prefs);
      await service.init();

      expect(await service.addCategory('Sports Club'), isTrue);
      expect(await service.addCategory('  sports   club  '), isFalse);
      expect(await service.addCategory('Basketball'), isTrue);
      expect(service.customCategories, ['Basketball', 'Sports Club']);
      expect(service.containsCategory('Sports Club'), isTrue);

      final reloaded = CategoryService(preferences: prefs);
      await reloaded.init();
      expect(reloaded.customCategories, ['Basketball', 'Sports Club']);

      expect(await reloaded.removeCategory('Sports Club'), isTrue);
      expect(reloaded.customCategories, ['Basketball']);
      expect(await reloaded.removeCategory('Missing'), isFalse);
    });

    test('renames a custom category and rejects collisions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = CategoryService(preferences: prefs);
      await service.init();
      await service.addCategory('Sports Club');
      await service.addCategory('Team');

      expect(
        await service.renameCategory(
          fromLabel: 'Sports Club',
          toLabel: 'Basketball Club',
        ),
        isTrue,
      );
      expect(service.customCategories, ['Basketball Club', 'Team']);
      expect(
        await service.renameCategory(
          fromLabel: 'Basketball Club',
          toLabel: 'Team',
        ),
        isFalse,
      );
    });
  });

  group('BackupFileService', () {
    late PathProviderPlatform originalPathProvider;
    late FileSelectorPlatform originalFileSelector;

    setUp(() {
      originalPathProvider = PathProviderPlatform.instance;
      originalFileSelector = FileSelectorPlatform.instance;
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      FileSelectorPlatform.instance = originalFileSelector;
    });

    test('creates backup files in downloads when available', () async {
      final tempDir = await createTempDir('downloads_backup');
      addTearDown(() => tempDir.delete(recursive: true));
      PathProviderPlatform.instance = FakePathProviderPlatform(
        downloadsPath: tempDir.path,
        applicationDocumentsPath: tempDir.path,
      );

      final service = const BackupFileService();
      final backup = await service.createBackupFile(
        rawJson: '{"cards":[]}',
        cardCount: 0,
      );

      expect(backup, isNotNull);
      expect(backup!.path, contains('${tempDir.path}/Card Box/'));
      expect(File(backup.path).existsSync(), isTrue);
    });

    test(
      'falls back to application documents when downloads are unavailable',
      () async {
        final tempDir = await createTempDir('docs_backup');
        addTearDown(() => tempDir.delete(recursive: true));
        PathProviderPlatform.instance = FakePathProviderPlatform(
          downloadsPath: null,
          applicationDocumentsPath: tempDir.path,
        );

        final service = const BackupFileService();
        final file = await service.createTextFile(
          content: 'hello',
          fileNamePrefix: 'card_box_test',
          extension: 'txt',
        );

        expect(file, isNotNull);
        expect(file!.path, contains('${tempDir.path}/backups/'));
        expect(File(file.path).readAsStringSync(), 'hello');
      },
    );

    test('imports a selected backup file through the file selector', () async {
      final tempDir = await createTempDir('pick_backup');
      addTearDown(() => tempDir.delete(recursive: true));
      final backupFile = File('${tempDir.path}/backup.json')
        ..writeAsStringSync('{"format":"card_box_plain_json","cards":[]}');
      final selector = FakeFileSelectorPlatform()
        ..nextOpenFile = XFile(backupFile.path, name: 'backup.json');
      FileSelectorPlatform.instance = selector;

      final imported = await const BackupFileService().pickBackupFile();

      expect(imported, isNotNull);
      expect(imported!.fileName, 'backup.json');
      expect(imported.rawJson, contains('card_box_plain_json'));
    });
  });

  group('MediaRecoveryService', () {
    late PathProviderPlatform originalPathProvider;
    late ImagePickerPlatform originalImagePicker;

    setUp(() {
      originalPathProvider = PathProviderPlatform.instance;
      originalImagePicker = ImagePickerPlatform.instance;
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      ImagePickerPlatform.instance = originalImagePicker;
    });

    test('recovers a lost front photo draft with pending metadata', () async {
      final tempDir = await createTempDir('media_recovery');
      addTearDown(() => tempDir.delete(recursive: true));
      PathProviderPlatform.instance = FakePathProviderPlatform(
        applicationDocumentsPath: tempDir.path,
        downloadsPath: tempDir.path,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final lostFile = File('${tempDir.path}/captured.jpg')
        ..writeAsBytesSync(<int>[10, 20, 30, 40]);
      final imagePicker = FakeImagePickerPlatform()
        ..lostDataResponse = LostDataResponse(
          files: <XFile>[XFile(lostFile.path)],
          type: RetrieveType.image,
        );
      ImagePickerPlatform.instance = imagePicker;
      final service = MediaRecoveryService(preferences: prefs);
      await service.markPendingPhotoRequest(
        draftCardId: 'draft-1',
        preset: AddCardPreset.visiting,
        side: 'front',
        existingCardId: 'existing-1',
      );

      final recovered = await service.recoverLostPhotoDraft();

      expect(recovered, isNotNull);
      expect(recovered!.draftCardId, 'draft-1');
      expect(recovered.preset, AddCardPreset.visiting);
      expect(recovered.existingCardId, 'existing-1');
      expect(recovered.frontImagePath, contains('/card_images/draft-1_front_'));
      expect(File(recovered.frontImagePath).existsSync(), isTrue);
      expect(prefs.getString('card_box.pending_media_request.v1'), isNull);
    });

    test('discardRecoveredDraft removes recovered files', () async {
      final tempDir = await createTempDir('media_discard');
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}/front.jpg')
        ..writeAsBytesSync(<int>[1]);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);

      await service.discardRecoveredDraft(
        RecoveredMediaDraft(
          draftCardId: 'draft',
          preset: AddCardPreset.general,
          existingCardId: null,
          frontImagePath: file.path,
          backImagePath: '',
        ),
      );

      expect(file.existsSync(), isFalse);
    });
  });

  group('AppLockService', () {
    test('supports full enable, unlock, update, and disable flow', () async {
      final secureStore = MemorySecureStore();
      final auth = FakeDeviceAuthService(
        biometricsEnrolled: true,
        authenticateResult: true,
      );
      final service = await createReadyAppLockService(
        secureStore: secureStore,
        deviceAuthService: auth,
      );

      await service.enableLock(
        pin: '2468',
        useBiometrics: true,
        lockOnResume: false,
      );
      expect(service.lockEnabled, isTrue);
      expect(service.biometricEnabled, isTrue);
      expect(service.lockOnResume, isFalse);

      service.lockForResume();
      expect(service.unlocked, isTrue);

      await service.updateSettings(useBiometrics: false, lockOnResume: true);
      expect(service.biometricEnabled, isFalse);
      expect(service.lockOnResume, isTrue);

      service.lockForResume();
      expect(service.shouldShowLockScreen, isTrue);

      expect(await service.unlockWithPin('1111'), isFalse);
      expect(await service.unlockWithPin('2468'), isTrue);

      await service.updateSettings(useBiometrics: true, lockOnResume: true);
      service.lockForResume();
      expect(await service.unlockWithBiometrics(), isTrue);
      expect(auth.authenticateCalls, 1);

      await service.disableLock();
      expect(service.lockEnabled, isFalse);
      expect(await secureStore.containsKey(AppLockService.pinKey), isFalse);
    });
  });
}
