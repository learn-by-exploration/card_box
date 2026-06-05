import 'package:flutter/services.dart';

class FileShareService {
  const FileShareService();

  static const MethodChannel _channel = MethodChannel('card_box/file_share');

  Future<bool> shareFile({
    required String path,
    required String subject,
    String? text,
  }) async {
    final shared = await _channel.invokeMethod<bool>('shareFile', {
      'path': path,
      'subject': subject,
      'text': text,
    });
    return shared ?? false;
  }
}
