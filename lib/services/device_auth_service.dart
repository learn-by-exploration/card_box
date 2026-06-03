import 'package:local_auth/local_auth.dart';

abstract class DeviceAuthService {
  Future<bool> isSupported();

  Future<bool> hasBiometricsEnrolled();

  Future<bool> authenticateWithBiometrics();
}

class LocalDeviceAuthService implements DeviceAuthService {
  LocalDeviceAuthService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isSupported() async {
    final canCheckBiometrics = await _authentication.canCheckBiometrics;
    return canCheckBiometrics || await _authentication.isDeviceSupported();
  }

  @override
  Future<bool> hasBiometricsEnrolled() async {
    try {
      if (!await _authentication.canCheckBiometrics) {
        return false;
      }
      final biometrics = await _authentication.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      return _authentication.authenticate(
        localizedReason: 'Unlock Card Box',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
