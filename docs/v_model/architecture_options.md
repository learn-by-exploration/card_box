# Architecture Options

Status: draft, created 2026-06-03; updated 2026-06-11.

## Baseline Tech Stack

Use Flutter, matching the existing `board_box` project.

Candidate packages to evaluate during the prototype:

| Capability | Candidate | Notes |
| --- | --- | --- |
| Barcode/QR scan | `mobile_scanner` | Supports Android, iOS, macOS, and web. Uses CameraX/ML Kit on Android and AVFoundation/Apple Vision on iOS/macOS. |
| NFC read | `nfc_manager` | Flutter NFC plugin for Android and iOS. Good first choice for NDEF/tag read experiments. |
| On-device text recognition | `google_mlkit_text_recognition` | Used for visiting-card OCR and for the smart-scan `CardPhotoTightener`. Latin + Japanese scripts, on-device only, no network. |
| Smart-scan document capture | `google_mlkit_document_scanner` (Android) / `VNDocumentCameraViewController` (iOS) | The native document scanner is used as the capture UI. Its output is post-processed by the tightener (see Module design below). |
| Image decoding / cropping | `image` (Dart) | Used by `CardPhotoTightener` to decode the scanner's JPEG, crop to the tightened region, and re-encode. |
| Secure key storage | `flutter_secure_storage` | Uses platform secure storage; latest pub.dev metadata lists Android, iOS, Linux, macOS, web, and Windows support. |
| App database | `drift` or `sqflite` | Drift gives typed reactive SQLite; sqflite is simpler but lower-level. |
| Preferences | `shared_preferences` | Already used in `board_box`; suitable for settings, not sensitive card data. |

Sources checked:

- https://pub.dev/packages/mobile_scanner
- https://pub.dev/packages/flutter_secure_storage
- https://pub.dev/packages/drift
- https://pub.dev/packages/sqflite
- https://pub.dev/packages/nfc_manager
- https://pub.dev/packages/google_mlkit_text_recognition
- https://pub.dev/packages/google_mlkit_document_scanner
- https://pub.dev/packages/image

## Proposed Logical Modules

| Module | Responsibility |
| --- | --- |
| Card catalog | CRUD operations, search, groups, favorites, archival state |
| Card media | Front/back images, thumbnails, secure file references |
| Card photo tightener | On-device refinement of smart-scan output: run text recognition, find the text region, expand to ID-1 aspect ratio, re-encode. Pure-function geometry (`computeCardCrop`) for testability. |
| Barcode wallet | Store, scan, validate, and display barcode/QR payloads |
| NFC reader | Detect availability, read supported tags, store safe metadata |
| Capability classifier | Mark cards as displayable, readable, reference-only, unsupported |
| Privacy/security | Local storage, encryption choices, export/backup policy |
| Import/export | User-controlled backup and restore |

## Early Design Decisions To Make

- Whether to encrypt every card record or only sensitive fields.
- Whether to use a passcode/biometric gate for opening the whole app.
- Whether to include images in encrypted backups.
- Whether to support web/desktop later or focus only on Android/iOS.
- Whether Android HCE is a separate experimental module instead of part of MVP.

