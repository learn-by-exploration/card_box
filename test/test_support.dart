import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_database.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/device_auth_service.dart';
import 'package:card_box/services/secure_store.dart';
import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';

class MemorySecureStore implements SecureStore {
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

class FakeDeviceAuthService implements DeviceAuthService {
  FakeDeviceAuthService({
    this.supported = false,
    this.biometricsEnrolled = false,
    this.authenticateResult = false,
  });

  bool supported;
  bool biometricsEnrolled;
  bool authenticateResult;
  int authenticateCalls = 0;

  @override
  Future<bool> authenticateWithBiometrics() async {
    authenticateCalls += 1;
    return authenticateResult;
  }

  @override
  Future<bool> hasBiometricsEnrolled() async => biometricsEnrolled;

  @override
  Future<bool> isSupported() async => supported;
}

class FakeCardMediaManager implements CardMediaManager {
  final Map<String, StoredImageBackupData> _images =
      <String, StoredImageBackupData>{};
  final List<String> importedPaths = <String>[];
  final List<String> deletedPaths = <String>[];

  @override
  Future<void> deleteImage(String path) async {
    deletedPaths.add(path);
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

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform({
    this.applicationDocumentsPath,
    this.downloadsPath,
    this.downloadsPathError,
    this.applicationDocumentsError,
  });

  String? applicationDocumentsPath;
  String? downloadsPath;

  /// When set, `getDownloadsPath()` throws this exception. Used to
  /// verify the backup service falls back to the app documents
  /// directory when the iOS `getDownloadsDirectory()` channel is
  /// unavailable or the platform returns a `PlatformException`.
  Object? downloadsPathError;

  /// When set, `getApplicationDocumentsPath()` throws this exception.
  Object? applicationDocumentsError;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (applicationDocumentsError != null) {
      throw applicationDocumentsError!;
    }
    return applicationDocumentsPath;
  }

  @override
  Future<String?> getDownloadsPath() async {
    if (downloadsPathError != null) {
      throw downloadsPathError!;
    }
    return downloadsPath;
  }
}

class FakeFileSelectorPlatform extends FileSelectorPlatform {
  XFile? nextOpenFile;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return nextOpenFile;
  }
}

class FakeImagePickerPlatform extends ImagePickerPlatform {
  LostDataResponse lostDataResponse = LostDataResponse.empty();

  @override
  Future<LostDataResponse> getLostData() async => lostDataResponse;
}

Future<AppLockService> createReadyAppLockService({
  bool lockEnabled = false,
  bool biometricsEnabled = false,
  bool lockOnResume = true,
  bool biometricsEnrolled = false,
  String? pin,
  SharedPreferences? preferences,
  MemorySecureStore? secureStore,
  FakeDeviceAuthService? deviceAuthService,
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues({
    AppLockService.lockEnabledKey: lockEnabled,
    AppLockService.biometricEnabledKey: biometricsEnabled,
    AppLockService.lockOnResumeKey: lockOnResume,
  });
  final prefs = preferences ?? await SharedPreferences.getInstance();
  final store = secureStore ?? MemorySecureStore();
  if (pin != null) {
    await store.write(AppLockService.pinKey, pin);
  }
  final auth =
      deviceAuthService ??
      FakeDeviceAuthService(biometricsEnrolled: biometricsEnrolled);
  final service = AppLockService(
    preferences: prefs,
    secureStore: store,
    deviceAuthService: auth,
    clock: clock,
  );
  await service.init();
  return service;
}

Future<CategoryService> createReadyCategoryService({
  SharedPreferences? preferences,
  List<String> customCategories = const <String>[],
}) async {
  if (preferences == null) {
    SharedPreferences.setMockInitialValues({
      'card_box.custom_categories.v1': customCategories,
    });
  }
  final prefs = preferences ?? await SharedPreferences.getInstance();
  if (preferences != null) {
    await prefs.setStringList(
      'card_box.custom_categories.v1',
      customCategories,
    );
  }
  final service = CategoryService(preferences: prefs);
  await service.init();
  return service;
}

Future<ThemeService> createReadyThemeService({
  SharedPreferences? preferences,
  ThemeMode initialMode = ThemeMode.system,
  CardBoxThemePalette initialPalette = CardBoxThemePalette.softTeal,
}) async {
  final storedMode = switch (initialMode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
  if (preferences == null) {
    SharedPreferences.setMockInitialValues({
      ThemeService.themeModeKey: storedMode,
      ThemeService.themePaletteKey: initialPalette.storageKey,
    });
  }
  final prefs = preferences ?? await SharedPreferences.getInstance();
  if (preferences != null) {
    await prefs.setString(ThemeService.themeModeKey, storedMode);
    await prefs.setString(
      ThemeService.themePaletteKey,
      initialPalette.storageKey,
    );
  }
  final service = ThemeService(preferences: prefs);
  await service.init();
  return service;
}

CardDatabase createInMemoryDatabase() => CardDatabase.inMemory();

/// Test-only database that throws on any write. Used to verify migration
/// code paths that must not abort app startup when the database rejects
/// a write. Reads still succeed against the in-memory executor so the
/// repository can be constructed and disposed without crashing.
class ThrowingCardDatabase extends CardDatabase {
  ThrowingCardDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> replaceAllCards(Iterable<dynamic> cards) async {
    throw StateError('replaceAllCards is not allowed in this test.');
  }

  @override
  Future<void> upsertCard(dynamic card) async {
    throw StateError('upsertCard is not allowed in this test.');
  }
}

/// Test-only database that throws only on `deleteCardById`. Used to
/// verify the in-memory rollback path of `CardRepository.deleteCard`.
class DeleteThrowingCardDatabase extends CardDatabase {
  DeleteThrowingCardDatabase() : super(NativeDatabase.memory());

  @override
  Future<int> deleteCardById(String id) async {
    throw StateError('deleteCardById is not allowed in this test.');
  }
}

/// Test-only database that records the timestamp of `deleteCardById`
/// calls so callers can assert that the DB row is removed before the
/// on-disk image is deleted.
class RecordingDeleteCardDatabase extends CardDatabase {
  RecordingDeleteCardDatabase() : super(NativeDatabase.memory());

  DateTime? lastDeleteAt;

  @override
  Future<void> deleteCardById(String id) async {
    lastDeleteAt = DateTime.now();
    await super.deleteCardById(id);
  }
}

/// Test-only database that records the set of card IDs that were
/// upserted via `upsertCards`. Used to verify the import persist
/// filter only writes cards that actually changed.
class ImportRecordingCardDatabase extends CardDatabase {
  ImportRecordingCardDatabase() : super(NativeDatabase.memory());

  final List<String> upsertedIds = <String>[];

  @override
  Future<void> upsertCards(Iterable<WalletCard> cards) async {
    upsertedIds.addAll(cards.map((c) => c.id));
    await super.upsertCards(cards);
  }
}

/// Test-only database that throws on `upsertCard` calls for a
/// configured card ID. The throw is conditional so a test can seed
/// the database with a different card first.
class UpsertThrowingCardDatabase extends CardDatabase {
  UpsertThrowingCardDatabase({this.throwForId = ''})
      : super(NativeDatabase.memory());

  /// When set to a non-empty value, `upsertCard` throws if the
  /// incoming card's id matches. Empty disables the throw.
  String throwForId;

  @override
  Future<void> upsertCard(WalletCard card) async {
    if (throwForId.isNotEmpty && card.id == throwForId) {
      throw StateError('upsertCard is not allowed in this test.');
    }
    await super.upsertCard(card);
  }
}

/// Test-only database that records the timestamp of `upsertCard` calls.
/// Used to assert the DB write happens before image cleanup so that
/// partial failures cannot orphan files referenced by stale DB rows.
class OrderingUpsertCardDatabase extends CardDatabase {
  OrderingUpsertCardDatabase() : super(NativeDatabase.memory());

  DateTime? lastUpsertAt;

  @override
  Future<void> upsertCard(WalletCard card) async {
    lastUpsertAt = DateTime.now();
    await super.upsertCard(card);
  }
}

/// Test-only database that counts the number of `upsertCard` calls and
/// the in-flight count (concurrent calls overlapping in time). Used
/// to assert the repository serializes writes through its in-flight
/// queue.
class ConcurrentRecordingCardDatabase extends CardDatabase {
  ConcurrentRecordingCardDatabase() : super(NativeDatabase.memory());

  int writeCount = 0;
  int maxInFlight = 0;
  int inFlight = 0;
  final List<({String id, DateTime started, DateTime ended})> writes =
      <({String id, DateTime started, DateTime ended})>[];

  @override
  Future<void> upsertCard(WalletCard card) async {
    inFlight += 1;
    if (inFlight > maxInFlight) {
      maxInFlight = inFlight;
    }
    final started = DateTime.now();
    try {
      // Simulate some I/O latency to give the queue a chance to overlap.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await super.upsertCard(card);
    } finally {
      inFlight -= 1;
      writes.add((id: card.id, started: started, ended: DateTime.now()));
      writeCount += 1;
    }
  }
}

/// Test-only media manager that records the timestamp of delete calls.
/// Used to assert the ordering of side effects relative to a paired
/// database recording.
class RecordingCardMediaManager extends CardMediaManager {
  final List<({String path, DateTime at})> deletes = <({String path, DateTime at})>[];
  final List<({String path, DateTime at})> existsChecks =
      <({String path, DateTime at})>[];

  @override
  Future<void> deleteImage(String path) async {
    deletes.add((path: path, at: DateTime.now()));
  }

  @override
  Future<bool> exists(String path) async {
    existsChecks.add((path: path, at: DateTime.now()));
    return true;
  }

  @override
  Future<StoredImageBackupData?> readImageForBackup(String path) async => null;

  @override
  Future<String> storeImportedImage({
    required String cardId,
    required String side,
    required Uint8List bytes,
    required String extension,
  }) async =>
      '/imported/${cardId}_$side$extension';
}

Widget wrapForTest(Widget child) {
  return MaterialApp(
    theme: cardBoxLightTheme,
    darkTheme: cardBoxDarkTheme,
    home: child,
  );
}

Future<Directory> createTempDir(String name) async {
  return Directory.systemTemp.createTemp('card_box_$name');
}
