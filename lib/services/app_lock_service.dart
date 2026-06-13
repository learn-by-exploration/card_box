import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/services/device_auth_service.dart';
import 'package:card_box/services/secure_store.dart';

class AppLockService extends ChangeNotifier {
  AppLockService({
    required this.preferences,
    SecureStore? secureStore,
    DeviceAuthService? deviceAuthService,
    DateTime Function()? clock,
  }) : _secureStore = secureStore ?? FlutterSecureStore(),
       _deviceAuthService = deviceAuthService ?? LocalDeviceAuthService(),
       _clock = clock ?? DateTime.now;

  static const pinKey = 'card_box.app_lock.pin';
  static const lockEnabledKey = 'card_box.app_lock.enabled';
  static const biometricEnabledKey = 'card_box.app_lock.biometric_enabled';
  static const lockOnResumeKey = 'card_box.app_lock.lock_on_resume';

  /// A trusted external flow (e.g. the camera scanner, an in-app
  /// browser) asks the lock service to skip the next background-lock
  /// re-prompt. If the OS force-kills the activity while a flow is
  /// still marked as trusted, a `finally` may never run and the
  /// counter would stay elevated forever. The 60s max-age guarantees
  /// the trust window is reclaimed no matter what.
  static const _trustedFlowMaxAge = Duration(seconds: 60);

  final SharedPreferences preferences;
  final SecureStore _secureStore;
  final DeviceAuthService _deviceAuthService;
  final DateTime Function() _clock;

  bool _ready = false;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _lockOnResume = true;
  bool _unlocked = true;
  bool _biometricAvailable = false;
  bool _authenticating = false;
  int _trustedExternalFlowCount = 0;
  DateTime? _trustedFlowStartedAt;

  bool get ready => _ready;
  bool get lockEnabled => _lockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get lockOnResume => _lockOnResume;
  bool get unlocked => _unlocked;
  bool get authenticating => _authenticating;
  bool get biometricAvailable => _biometricAvailable;
  bool get deferringBackgroundLock {
    if (_trustedExternalFlowCount == 0) {
      return false;
    }
    final startedAt = _trustedFlowStartedAt;
    if (startedAt != null &&
        _clock().difference(startedAt) > _trustedFlowMaxAge) {
      // The trust window has outlived its expected lifetime — most
      // likely because an external flow was force-killed and its
      // `finally` never executed. Reclaim the counter so the next
      // background-lock check will actually re-prompt the user.
      _trustedExternalFlowCount = 0;
      _trustedFlowStartedAt = null;
      return false;
    }
    return true;
  }

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
    _trustedFlowStartedAt = _clock();
  }

  void endTrustedExternalFlow() {
    if (_trustedExternalFlowCount == 0) {
      return;
    }
    _trustedExternalFlowCount -= 1;
    if (_trustedExternalFlowCount == 0) {
      _trustedFlowStartedAt = null;
    }
  }

  /// Force-clear the trust window. Called from the lifecycle
  /// observer when the activity enters `AppLifecycleState.detached`
  /// (OS is reclaiming the process); the activity may never come
  /// back, so any pending trust counter would otherwise survive
  /// the process death as stale state.
  void resetForDetached() {
    _trustedExternalFlowCount = 0;
    _trustedFlowStartedAt = null;
  }

  /// Visible for tests: lets a test pin the cached biometric
  /// availability without going through [init] (which would also
  /// re-read the lock-enabled flag from preferences).
  @visibleForTesting
  void setBiometricAvailability(bool value) {
    _biometricAvailable = value;
  }
}
