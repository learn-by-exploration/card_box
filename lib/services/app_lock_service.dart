import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/services/device_auth_service.dart';
import 'package:card_box/services/secure_store.dart';

class AppLockService extends ChangeNotifier {
  AppLockService({
    required this.preferences,
    SecureStore? secureStore,
    DeviceAuthService? deviceAuthService,
  }) : _secureStore = secureStore ?? FlutterSecureStore(),
       _deviceAuthService = deviceAuthService ?? LocalDeviceAuthService();

  static const pinKey = 'card_box.app_lock.pin';
  static const lockEnabledKey = 'card_box.app_lock.enabled';
  static const biometricEnabledKey = 'card_box.app_lock.biometric_enabled';
  static const lockOnResumeKey = 'card_box.app_lock.lock_on_resume';

  final SharedPreferences preferences;
  final SecureStore _secureStore;
  final DeviceAuthService _deviceAuthService;

  bool _ready = false;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _lockOnResume = true;
  bool _unlocked = true;
  bool _biometricAvailable = false;
  bool _authenticating = false;
  int _trustedExternalFlowCount = 0;

  bool get ready => _ready;
  bool get lockEnabled => _lockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get lockOnResume => _lockOnResume;
  bool get unlocked => _unlocked;
  bool get biometricAvailable => _biometricAvailable;
  bool get authenticating => _authenticating;
  bool get deferringBackgroundLock => _trustedExternalFlowCount > 0;
  bool get shouldShowLockScreen => ready && lockEnabled && !unlocked;

  Future<void> init() async {
    _lockEnabled = preferences.getBool(lockEnabledKey) ?? false;
    _biometricEnabled = preferences.getBool(biometricEnabledKey) ?? false;
    _lockOnResume = preferences.getBool(lockOnResumeKey) ?? true;
    _biometricAvailable = await _deviceAuthService.hasBiometricsEnrolled();
    _unlocked = !_lockEnabled;
    _ready = true;
    notifyListeners();
  }

  Future<void> enableLock({
    required String pin,
    required bool useBiometrics,
    required bool lockOnResume,
  }) async {
    await _secureStore.write(pinKey, pin);
    await preferences.setBool(lockEnabledKey, true);
    await preferences.setBool(biometricEnabledKey, useBiometrics);
    await preferences.setBool(lockOnResumeKey, lockOnResume);
    _lockEnabled = true;
    _biometricEnabled = useBiometrics;
    _lockOnResume = lockOnResume;
    _unlocked = true;
    notifyListeners();
  }

  Future<void> updateSettings({
    required bool useBiometrics,
    required bool lockOnResume,
  }) async {
    await preferences.setBool(biometricEnabledKey, useBiometrics);
    await preferences.setBool(lockOnResumeKey, lockOnResume);
    _biometricEnabled = useBiometrics;
    _lockOnResume = lockOnResume;
    notifyListeners();
  }

  Future<void> changePin(String pin) async {
    await _secureStore.write(pinKey, pin);
  }

  Future<void> disableLock() async {
    await preferences.setBool(lockEnabledKey, false);
    await preferences.setBool(biometricEnabledKey, false);
    await _secureStore.delete(pinKey);
    _lockEnabled = false;
    _biometricEnabled = false;
    _unlocked = true;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final storedPin = await _secureStore.read(pinKey);
    final matched = storedPin != null && storedPin == pin;
    if (matched) {
      _unlocked = true;
      notifyListeners();
    }
    return matched;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_biometricEnabled || !_biometricAvailable || _authenticating) {
      return false;
    }
    _authenticating = true;
    notifyListeners();
    try {
      final success = await _deviceAuthService.authenticateWithBiometrics();
      if (success) {
        _unlocked = true;
        notifyListeners();
      }
      return success;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  void lockForResume() {
    if (!_lockEnabled || !_lockOnResume || deferringBackgroundLock) {
      return;
    }
    _unlocked = false;
    notifyListeners();
  }

  void beginTrustedExternalFlow() {
    _trustedExternalFlowCount += 1;
  }

  void endTrustedExternalFlow() {
    if (_trustedExternalFlowCount == 0) {
      return;
    }
    _trustedExternalFlowCount -= 1;
  }
}
