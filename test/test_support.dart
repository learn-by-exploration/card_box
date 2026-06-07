import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_database.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/category_service.dart';
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
  FakePathProviderPlatform({this.applicationDocumentsPath, this.downloadsPath});

  String? applicationDocumentsPath;
  String? downloadsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return applicationDocumentsPath;
  }

  @override
  Future<String?> getDownloadsPath() async => downloadsPath;
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
