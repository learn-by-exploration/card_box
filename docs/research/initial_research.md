# Initial Research Notes

Date: 2026-06-03.

## Existing Open-Source Or Relevant Projects

- `nfc_manager` is a Flutter plugin for NFC on Android and iOS.
  Source: https://github.com/dghilardi/flutter_nfc_manager
- `okadan/nfc-manager` is a Flutter demo app for accessing NFC features.
  Source: https://github.com/okadan/nfc-manager
- `flutter_nfc` is another Flutter NFC plugin that supports Android and iOS.
  Source: https://github.com/skwcrd/flutter_nfc
- `emv-card-reader` is an Android-only Flutter plugin for reading some payment
  card metadata, but its scope and privacy/safety implications need careful
  review before any use.
  Source: https://github.com/paytrek/emv-card-reader
- OSS CardWallet describes an open-source app for scanning business cards,
  loyalty cards, passbooks, barcodes, and QR codes.
  Source: https://opencollective.com/oss-appscollective/projects/oss-cardwallet
- NFSee is a Flutter cross-platform app for reading multiple NFC tag/card types.
  Source: https://nfsee.nfc.im/

## Platform And Feasibility Findings

- Android supports host-based card emulation starting from Android 4.4, but HCE
  is protocol-specific and does not imply universal card cloning.
  Source: https://developer.android.com/develop/connectivity/nfc/hce
- Android Quick Access Wallet is aimed at payment cards and relevant passes and
  is part of the platform wallet experience.
  Source: https://source.android.com/docs/core/connect/quick-access-wallet
- Apple Core NFC is available for supported NFC reading use cases, but iOS does
  not provide a general-purpose path for arbitrary third-party RFID/NFC card
  emulation.
  Source: https://developer.apple.com/documentation/corenfc
- Many RFID/NFC discussions repeat the same practical lesson: RFID and NFC are
  broad families of standards, so no single phone app can scan and emulate all
  cards.
  Source: https://www.reddit.com/r/NFC/comments/u83fo5

## Requirement Consequences

- The app should classify card capability instead of saying every card can be
  digitized.
- A useful free app can still exist without universal emulation by focusing on:
  card inventory, card photos, barcodes/QR, searchable metadata, expiry alerts,
  local privacy, and NFC reading where possible.
- We should investigate reusable libraries for:
  - Local encrypted storage
  - Camera/image capture
  - Barcode and QR scanning/generation
  - NFC reading
  - Optional OCR

