# Implementation Status

Status: v0.1 prototype stabilization pass complete, updated 2026-06-13.

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
  - last-used timestamp and use count (set automatically when the
    user opens the present-code or present-card screen)
- Local repository using Drift / SQLite, with legacy `shared_preferences`
  migration support for older installs.
- Demo seed cards are development-only via `--dart-define=CARD_BOX_SEED_DEMOS=true`.
- Plain JSON export/import with native backup file creation, native share-sheet
  handoff, and file-picker import, including portable photo attachments in
  backup files.
- Encrypted backup export/import using a user password.
- Camera/photo-library card image capture wired with local file storage.
- Barcode/QR camera scanning wired.
- Barcode/QR rendering wired for supported formats.
- Android-first NFC availability check and tag-summary scanning wired into the
  compatibility flow.
- Visiting-card capture and OCR-assisted review flow:
  - visiting-card add preset
  - edge-scan/photo capture reuse
  - on-device OCR extraction
  - Latin and Japanese OCR passes for better meishi/business-card parsing
  - field-by-field review before save
  - structured contact details plus raw OCR text storage
  - quick actions for call, email, and website
  - vCard export
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
  - category settings (rename, merge into built-in categories)
- Permission-first prototype messaging for camera, NFC, and file flows.
- Native in-repo settings bridge for NFC settings handoff instead of relying on
  `app_settings`.
- Smart-scan refinement: the document scanner's auto-cropped JPEG is
  post-processed on-device by `CardPhotoTightener`, which runs ML Kit
  text recognition (Latin + Japanese), unions the detected text-line
  bounding boxes, pads them, and expands the result to the ID-1 card
  aspect ratio (1.586:1). The tightener is fail-safe and never regresses
  the existing behavior. Applies to all smart-scan paths (Android ML Kit,
  iOS VisionKit, and the Android camera + ID-1 fallback).
- Card organization and reuse improvements (added in the 2026-06-13
  stabilization pass):
  - Duplicate a card from the more-options sheet; the copy is created
    locally with a new id, "(copy)" appended to the name, and fresh
    `createdAt`/`updatedAt` timestamps. The duplicate is a peer of the
    original and can be edited independently.
  - Sort options on the home list: name A→Z (default), name Z→A, most
    recently updated, most recently added. The last-used selection is
    persisted across launches.
  - Favorites filter on the home list: a one-tap filter chip that hides
    every non-favorited card. The chip composes with the existing
    category and free-text filters.
  - Scan-time duplicate detection: while editing a card, scanning a
    barcode whose payload already exists on a different card surfaces a
    dialog ("This code is already on `X`") with options to keep scanning
    or jump straight to the existing card. Re-scanning the same card's
    own payload does not self-prompt.
  - Wakelock on the present-code and present-card screens so the phone
    does not dim mid-scan. The lock is released as soon as the user
    leaves the screen.
  - `markUsed` records the timestamp and bumps a per-card use counter
    whenever the user opens the present-code or present-card screen.
    `lastUsedAt` and `useCount` round-trip through the JSON payload, so
    no schema migration is needed and existing backups upgrade
    gracefully on import.

## Verified

- `flutter pub get`
- `dart format .`
- `flutter analyze`
- `flutter test` (151 tests, all green as of 2026-06-13)
- `flutter build apk --debug`
- `flutter build apk --release`
- `flutter build appbundle --release`

## Build Notes

- Android debug build succeeds with `mobile_scanner`.
- `mobile_scanner` is vendored under `third_party/mobile_scanner` and patched to
  use Flutter 3.44 built-in Kotlin support, removing the earlier KGP warning on
  Android builds.
- `nfc_manager` is vendored under `third_party/nfc_manager` and patched to use
  Flutter 3.44 built-in Kotlin support, removing the earlier KGP warning on
  Android builds.
- `app_settings` has been removed and replaced with a small native settings
  bridge on Android and iOS.
- iOS deployment target is raised to `15.5` to match the OCR package
  requirement.
- iOS Podfile now includes the Japanese ML Kit text-recognition package for the
  visiting-card OCR path.
- `wakelock_plus 1.6.x` is the wakelock dependency used by the present
  screens.

## Deferred to a later pass

- Expiry reminders. The data model does not yet track card expiry dates and
  the app does not schedule notifications. The home list will not surface an
  "expiring soon" chip until this is implemented.
- Acceptance locations. The data model does not track per-card "where this
  card is accepted" entries and the app does not request geolocation
  permission or run a proximity search.
- iOS NFC entitlement setup and validation.
- Broader iOS-specific validation.
- De-vendoring `mobile_scanner` and `nfc_manager` once upstream Android build
  integration is fully aligned with the active Flutter toolchain.
