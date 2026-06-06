import 'dart:typed_data';

class ScannedCode {
  const ScannedCode({
    required this.payload,
    required this.format,
    this.displayValue = '',
    this.valueType = '',
    this.structuredData = '',
    this.rawBytesHex = '',
    this.capturedAt,
    this.imageBytes,
  });

  final String payload;
  final String format;
  final String displayValue;
  final String valueType;
  final String structuredData;
  final String rawBytesHex;
  final DateTime? capturedAt;
  final Uint8List? imageBytes;
}
