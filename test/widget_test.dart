import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/main.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_crypto_service.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/card_storage_codec.dart';
import 'package:card_box/services/device_auth_service.dart';
import 'package:card_box/services/secure_store.dart';

void main() {
  test('WalletCard round-trips through JSON', () {
    final now = DateTime(2026, 6, 3);
    final card = WalletCard(
      id: 'card-1',
      name: 'Library card',
      issuer: 'Public library',
      category: CardCategory.library,
      barcodePayload: 'LIB-001',
      barcodeFormat: 'Code 39',
      compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
      createdAt: now,
      updatedAt: now,
    );

    final restored = WalletCard.fromJson(card.toJson());

    expect(restored.id, 'card-1');
    expect(restored.category, CardCategory.library);
    expect(
      restored.compatibilityStatus,
      CompatibilityStatus.barcodeDisplayable,
    );
    expect(restored.barcodePayload, 'LIB-001');
  });

  test('CardRepository exports and imports plain JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CardRepository(seedDemoCards: true);
    await repository.init();

    final exported = await repository.exportPlainJson();

    SharedPreferences.setMockInitialValues({});
    final secondRepository = CardRepository();
    await secondRepository.init();
    final count = await secondRepository.importPlainJson(exported);

    expect(count, repository.cards.length);
    expect(
      secondRepository.cards.any((card) => card.name == 'Office access card'),
      isTrue,
    );
  });

  test('CardRepository starts empty by default on a fresh install', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CardRepository();

    await repository.init();

    expect(repository.cards, isEmpty);
  });

  test('CardRepository backup preserves photo attachments', () async {
    SharedPreferences.setMockInitialValues({});
    final mediaManager = _FakeCardMediaManager();
    mediaManager.seedImage(
      '/images/front.jpg',
      StoredImageBackupData(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        extension: '.jpg',
      ),
    );
    final repository = CardRepository(mediaManager: mediaManager);
    await repository.init();
    await repository.upsert(
      WalletCard(
        id: 'photo-card',
        name: 'Photo card',
        category: CardCategory.id,
        frontImagePath: '/images/front.jpg',
        createdAt: DateTime(2026, 6, 3),
        updatedAt: DateTime(2026, 6, 3),
      ),
    );

    final exported = await repository.exportPlainJson();

    SharedPreferences.setMockInitialValues({});
    final secondMediaManager = _FakeCardMediaManager();
    final secondRepository = CardRepository(mediaManager: secondMediaManager);
    await secondRepository.init();
    await secondRepository.importPlainJson(exported);

    final restored = secondRepository.findById('photo-card');
    expect(restored, isNotNull);
    expect(restored!.frontImagePath, startsWith('/imported/photo-card_front'));
    expect(secondMediaManager.importedPaths, hasLength(1));
  });

  test('CardRepository migrates legacy on-device storage on init', () async {
    final now = DateTime(2026, 6, 3).toIso8601String();
    final legacyCardsJson = jsonEncode([
      {
        'id': 'legacy-1',
        'name': 'Legacy library card',
        'issuer': 'Old public library',
        'category': 'library',
        'createdAt': now,
        'updatedAt': now,
      },
    ]);
    SharedPreferences.setMockInitialValues({
      'card_box.cards.v1': legacyCardsJson,
    });
    final repository = CardRepository();

    await repository.init();

    expect(repository.cards.length, 1);
    expect(repository.cards.first.name, 'Legacy library card');

    final preferences = await SharedPreferences.getInstance();
    final rewritten = preferences.getString('card_box.cards.v1');
    expect(rewritten, isNotNull);
    final migrated = CardStorageCodec().decodeStored(rewritten!);
    expect(migrated.schemaVersion, CardStorageCodec.currentSchemaVersion);
    expect(migrated.cards.first.frontImagePath, '');
  });

  test('CardStorageCodec migrates legacy storage fixture photo paths', () {
    final rawJson = _readFixture('legacy_storage_v1_file_uri_paths.json');

    final migrated = CardStorageCodec().decodeStored(rawJson);

    expect(migrated.schemaVersion, CardStorageCodec.currentSchemaVersion);
    expect(
      migrated.cards.first.frontImagePath,
      '/data/user/0/com.cardbox.card_box/app_flutter/card_images/front_fixture.jpg',
    );
    expect(
      migrated.cards.first.backImagePath,
      '/data/user/0/com.cardbox.card_box/app_flutter/card_images/back_fixture.jpg',
    );
  });

  test('CardRepository imports legacy backup version', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CardRepository();
    await repository.init();

    final legacyBackup = jsonEncode({
      'format': 'card_box_plain_json',
      'version': 1,
      'cards': [
        {
          'id': 'legacy-backup-1',
          'name': 'Gym pass',
          'issuer': 'Fitness center',
          'category': 'membership',
          'createdAt': '2026-06-03T00:00:00.000',
          'updatedAt': '2026-06-03T00:00:00.000',
        },
      ],
    });

    final count = await repository.importPlainJson(legacyBackup);

    expect(count, 1);
    expect(
      repository.cards.any((card) => card.id == 'legacy-backup-1'),
      isTrue,
    );
  });

  test('CardStorageCodec migrates legacy backup fixture photo key aliases', () {
    final rawJson = _readFixture('legacy_backup_v1_photo_key_aliases.json');

    final migrated = CardStorageCodec().decodeBackup(rawJson);
    final card = migrated.cards.single;

    expect(card.id, 'legacy-photo-backup-1');
    expect(
      card.frontImagePath,
      '/storage/emulated/0/Android/data/com.cardbox.card_box/files/card_images/legacy_front.jpg',
    );
    expect(
      card.backImagePath,
      '/storage/emulated/0/Android/data/com.cardbox.card_box/files/card_images/legacy_back.jpg',
    );
  });

  test('CardRepository can archive and restore cards', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CardRepository(seedDemoCards: true);
    await repository.init();

    await repository.archive('demo-library');
    expect(repository.cards.any((card) => card.id == 'demo-library'), isFalse);
    expect(
      repository.archivedCards.any((card) => card.id == 'demo-library'),
      isTrue,
    );

    await repository.unarchive('demo-library');
    expect(repository.cards.any((card) => card.id == 'demo-library'), isTrue);
  });

  test('BackupCryptoService encrypts and decrypts backup JSON', () async {
    const rawJson = '{"format":"card_box_plain_json","cards":[]}';
    final crypto = BackupCryptoService();

    final encrypted = await crypto.encryptJson(
      rawJson: rawJson,
      password: 'correct horse battery staple',
    );
    final decrypted = await crypto.decryptJson(
      encryptedJson: encrypted,
      password: 'correct horse battery staple',
    );

    expect(crypto.looksEncrypted(encrypted), isTrue);
    expect(decrypted, rawJson);
  });

  test('BackupCryptoService rejects a wrong password', () async {
    const rawJson = '{"format":"card_box_plain_json","cards":[]}';
    final crypto = BackupCryptoService();
    final encrypted = await crypto.encryptJson(
      rawJson: rawJson,
      password: 'correct horse battery staple',
    );

    expect(
      () => crypto.decryptJson(
        encryptedJson: encrypted,
        password: 'wrong password',
      ),
      throwsFormatException,
    );
  });

  test('AppLockService defers locking during trusted external flows', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final appLockService = AppLockService(
      preferences: preferences,
      secureStore: _MemorySecureStore(),
      deviceAuthService: _FakeDeviceAuthService(),
    );
    await appLockService.init();
    await appLockService.enableLock(
      pin: '1234',
      useBiometrics: false,
      lockOnResume: true,
    );

    appLockService.beginTrustedExternalFlow();
    appLockService.lockForResume();
    expect(appLockService.unlocked, isTrue);

    appLockService.endTrustedExternalFlow();
    appLockService.lockForResume();
    expect(appLockService.shouldShowLockScreen, isTrue);
  });

  testWidgets('Card Box starts with demo acceptance cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = CardRepository(seedDemoCards: true);
    await repository.init();
    final appLockService = AppLockService(
      preferences: preferences,
      secureStore: _MemorySecureStore(),
      deviceAuthService: _FakeDeviceAuthService(),
    );
    await appLockService.init();

    await tester.pumpWidget(
      CardBoxApp(repository: repository, appLockService: appLockService),
    );

    expect(find.text('Card Box'), findsOneWidget);
    expect(find.text('Office access card'), findsOneWidget);
    expect(find.text('Supermarket loyalty'), findsOneWidget);
  });
}

class _MemorySecureStore implements SecureStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

String _readFixture(String name) {
  return File('test/fixtures/$name').readAsStringSync();
}

class _FakeDeviceAuthService implements DeviceAuthService {
  @override
  Future<bool> authenticateWithBiometrics() async => false;

  @override
  Future<bool> hasBiometricsEnrolled() async => false;

  @override
  Future<bool> isSupported() async => false;
}

class _FakeCardMediaManager implements CardMediaManager {
  final Map<String, StoredImageBackupData> _images =
      <String, StoredImageBackupData>{};
  final List<String> importedPaths = <String>[];

  @override
  Future<void> deleteImage(String path) async {
    _images.remove(path);
  }

  @override
  Future<bool> exists(String path) async => _images.containsKey(path);

  @override
  Future<StoredImageBackupData?> readImageForBackup(String path) async {
    return _images[path];
  }

  void seedImage(String path, StoredImageBackupData data) {
    _images[path] = data;
  }

  @override
  Future<String> storeImportedImage({
    required String cardId,
    required String side,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path = '/imported/${cardId}_$side$extension';
    importedPaths.add(path);
    _images[path] = StoredImageBackupData(bytes: bytes, extension: extension);
    return path;
  }
}
