enum CompatibilityStatus {
  untested('Untested', 'Run a compatibility test when you are ready.'),
  barcodeDisplayable(
    'Barcode/QR displayable',
    'This card can be shown on screen.',
  ),
  nfcReadable('NFC readable', 'This phone can read supported NFC data.'),
  nfcDetectedNotReadable(
    'NFC detected, not readable',
    'The phone saw the card but could not read useful data.',
  ),
  androidHceCandidate(
    'Android HCE candidate',
    'This may be investigated later for Android-only emulation.',
  ),
  referenceOnly(
    'Reference-only',
    'Keep photos and notes, but use the physical card.',
  ),
  unsupported(
    'Unsupported by this phone',
    'This card cannot be digitized by this phone.',
  );

  const CompatibilityStatus(this.label, this.description);

  final String label;
  final String description;

  static CompatibilityStatus fromName(String value) {
    return CompatibilityStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CompatibilityStatus.untested,
    );
  }
}
