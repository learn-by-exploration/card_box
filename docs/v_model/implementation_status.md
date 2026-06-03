# Implementation Status

Status: v0.1 prototype started, updated 2026-06-03.

## Built

- Flutter app scaffold in `card_box`.
- Android, iOS, and web project targets generated.
- Android-first package identity: `com.cardbox.card_box`.
- App shell named Card Box.
- Launcher icon generated from `app_icon.png` for Android and iOS.
- Local card model:
  - name
  - issuer
  - category
  - custom category support
  - notes
  - front/back photo references
  - barcode/QR payload and format
  - NFC summary
  - compatibility status
  - favorite/archive
- Local repository using `shared_preferences`.
- Demo seed cards are development-only via `--dart-define=CARD_BOX_SEED_DEMOS=true`.
- Plain JSON export/import with native backup file creation and file-picker
  import, including portable photo attachments in backup files.
- Encrypted backup export/import using a user password.
- Camera/photo-library card image capture wired with local file storage.
- Barcode/QR camera scanning wired.
- Barcode/QR rendering wired for supported formats.
- Android-first NFC availability check and tag-summary scanning wired into the
  compatibility flow.
- Biometric app lock with fallback app PIN, optional biometric unlock, and
  optional lock-on-resume settings.
- Demo acceptance cards:
  - office/access card
  - supermarket loyalty card
  - metro/transit card
  - library card
- Screens:
  - card list/search/filter
  - archived cards restore/delete
  - card detail
  - add/edit card
  - compatibility test
  - export/import
- Permission-first prototype messaging for camera, NFC, and file flows.

## Verified

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

## Build Notes

- Android debug build succeeds with `mobile_scanner`.
- `mobile_scanner` is vendored under `third_party/mobile_scanner` and patched to
  use Flutter 3.44 built-in Kotlin support, removing the earlier KGP warning on
  Android builds.
- `nfc_manager` is vendored under `third_party/nfc_manager` and patched to use
  Flutter 3.44 built-in Kotlin support, removing the earlier KGP warning on
  Android builds.

## Not Yet Built

- System share flow for backup files.
- iOS NFC entitlement setup and validation.
- Broader iOS-specific validation.
