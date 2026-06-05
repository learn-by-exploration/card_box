import 'package:flutter/services.dart';

class DeviceSettingsService {
  const DeviceSettingsService();

  static const MethodChannel _channel = MethodChannel(
    'card_box/device_settings',
  );

  Future<bool> openNfcSettings() async {
    final opened = await _channel.invokeMethod<bool>('openNfcSettings');
    return opened ?? false;
  }

  Future<bool> openAppSettings() async {
    final opened = await _channel.invokeMethod<bool>('openAppSettings');
    return opened ?? false;
  }
}
