import 'package:card_box/models/compatibility_status.dart';

class NfcScanResult {
  const NfcScanResult({
    required this.status,
    required this.summary,
    required this.detail,
  });

  final CompatibilityStatus status;
  final String summary;
  final String detail;
}
