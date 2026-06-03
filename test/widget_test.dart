import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/main.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_crypto_service.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/card_storage_codec.dart';
import 'package:card_box/services/device_auth_service.dart';
import 'package:card_box/services/secure_store.dart';
import 'package:card_box/services/vcard_export_service.dart';

void main() {
  test('WalletCard round-trips through JSON', () {
    final now = DateTime(2026, 6, 3);
    final card = WalletCard(
      id: 'card-1',
      name: 'Aiko Tanaka',
      issuer: 'CourtSide Japan',
      category: CardCategory.contact,
      cardType: CardType.visitingCard,
      rawOcrText: 'Aiko Tanaka\nCourtSide Japan\naiko@example.com',
      contactTitle: 'Community Manager',
      contactPhones: const ['+81 90 1111 2222'],
      contactEmails: const ['aiko@example.com'],
      contactWebsites: const ['courtside.jp'],
      contactAddress: 'Tokyo, Japan',
      createdAt: now,
      updatedAt: now,
    );

    final restored = WalletCard.fromJson(card.toJson());

    expect(restored.id, 'card-1');
    expect(restored.category, CardCategory.contact);
    expect(restored.cardType, CardType.visitingCard);
    expect(restored.contactTitle, 'Community Manager');
    expect(restored.contactPhones, ['+81 90 1111 2222']);
    expect(restored.contactEmails, ['aiko@example.com']);
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

  test('Visiting card keeps images through save and backup import', () async {
    SharedPreferences.setMockInitialValues({});
    final mediaManager = _FakeCardMediaManager();
    mediaManager.seedImage(
      '/images/visit_front.jpg',
      StoredImageBackupData(
        bytes: Uint8List.fromList([10, 20, 30]),
        extension: '.jpg',
      ),
    );
    mediaManager.seedImage(
      '/images/visit_back.jpg',
      StoredImageBackupData(
        bytes: Uint8List.fromList([40, 50, 60]),
        extension: '.jpg',
      ),
    );
    final repository = CardRepository(mediaManager: mediaManager);
    await repository.init();
    await repository.upsert(
      WalletCard(
        id: 'visiting-1',
        name: 'Aiko Tanaka',
        issuer: 'CourtSide Japan',
        category: CardCategory.contact,
        cardType: CardType.visitingCard,
        frontImagePath: '/images/visit_front.jpg',
        backImagePath: '/images/visit_back.jpg',
        rawOcrText: 'Aiko Tanaka\nCourtSide Japan',
        contactTitle: 'Community Manager',
        createdAt: DateTime(2026, 6, 3),
        updatedAt: DateTime(2026, 6, 3),
      ),
    );

    final saved = repository.findById('visiting-1');
    expect(saved, isNotNull);
    expect(saved!.frontImagePath, '/images/visit_front.jpg');
    expect(saved.backImagePath, '/images/visit_back.jpg');

    final exported = await repository.exportPlainJson();

    SharedPreferences.setMockInitialValues({});
    final secondMediaManager = _FakeCardMediaManager();
    final secondRepository = CardRepository(mediaManager: secondMediaManager);
    await secondRepository.init();
    await secondRepository.importPlainJson(exported);

    final restored = secondRepository.findById('visiting-1');
    expect(restored, isNotNull);
    expect(restored!.cardType, CardType.visitingCard);
    expect(restored.frontImagePath, startsWith('/imported/visiting-1_front'));
    expect(restored.backImagePath, startsWith('/imported/visiting-1_back'));
    expect(secondMediaManager.importedPaths, hasLength(2));
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

  test('CardStorageCodec migrates v2 cards to visiting-card aware schema', () {
    final rawJson = jsonEncode({
      'format': 'card_box_storage',
      'schemaVersion': 2,
      'cards': [
        {
          'id': 'legacy-v2-card',
          'name': 'Contact card',
          'issuer': 'Legacy Co',
          'category': 'contact',
          'contactPhone': '+1 555 123 4567',
          'contactEmail': 'hello@legacy.example',
          'contactWebsite': 'legacy.example',
          'createdAt': '2026-06-03T00:00:00.000',
          'updatedAt': '2026-06-03T00:00:00.000',
        },
      ],
    });

    final migrated = CardStorageCodec().decodeStored(rawJson);
    final card = migrated.cards.single;

    expect(migrated.schemaVersion, CardStorageCodec.currentSchemaVersion);
    expect(card.cardType, CardType.standard);
    expect(card.contactPhones, ['+1 555 123 4567']);
    expect(card.contactEmails, ['hello@legacy.example']);
    expect(card.contactWebsites, ['legacy.example']);
  });

  test('VCardExportService builds a useful visiting-card export', () {
    const service = VCardExportService();
    final card = WalletCard(
      id: 'visit-1',
      name: 'Aiko Tanaka',
      issuer: 'CourtSide Japan',
      category: CardCategory.contact,
      cardType: CardType.visitingCard,
      contactTitle: 'Community Manager',
      contactPhones: const ['+81 90 1111 2222'],
      contactEmails: const ['aiko@example.com'],
      contactWebsites: const ['https://courtside.jp'],
      contactAddress: 'Tokyo, Japan',
      notes: 'Met at practice',
      rawOcrText: 'Aiko Tanaka\nCourtSide Japan',
      createdAt: DateTime(2026, 6, 3),
      updatedAt: DateTime(2026, 6, 3),
    );

    final vcard = service.buildVCard(card);

    expect(vcard, contains('BEGIN:VCARD'));
    expect(vcard, contains('FN:Aiko Tanaka'));
    expect(vcard, contains('ORG:CourtSide Japan'));
    expect(vcard, contains('EMAIL;TYPE=INTERNET:aiko@example.com'));
    expect(vcard, contains('URL:https://courtside.jp'));
    expect(vcard, contains('END:VCARD'));
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
    await tester.scrollUntilVisible(
      find.text('Office access card'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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
