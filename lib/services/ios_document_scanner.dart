import 'package:flutter/services.dart';

class IosDocumentScanner {
  static const MethodChannel _channel = MethodChannel(
    'card_box/document_scanner',
  );

  Future<String?> scanSinglePage() {
    return _channel.invokeMethod<String>('scanSinglePage');
  }
}
