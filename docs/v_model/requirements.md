# Initial Requirements Baseline

Status: draft, created 2026-06-03; updated 2026-06-11.

## User Need

People carry many physical cards and struggle to find, remember, or present the
right one. Existing apps may be paid, closed, cloud-dependent, or unclear about
what they do with private card data. Card Box should provide a free,
privacy-respecting alternative.

## Product Scope

### In Scope For MVP

- Create a card record manually.
- Capture front and back card images.
- Store card name, issuer, category, notes, expiry date, and custom fields.
- Store barcode and QR payloads from camera scan or manual entry.
- Display barcode/QR cards in a presentation mode suitable for checkout desks.
- Read NFC tag metadata and NDEF data where supported by the phone and platform.
- Clearly label unreadable or unsupported cards instead of pretending they can
  be digitized.
- Search, filter, favorite, and group cards.
- Local-first storage.
- User-controlled export/backup without requiring hosted infrastructure.
- No ads and no paid unlocks.
- Exclude credit and debit card storage from the product scope.
- Android-first prototype while preserving iOS compatibility decisions for a
  later release.
- Extensible card categories so the default list can grow without changing the
  core card model.
- Support visiting-card capture and structured contact extraction with user
  review before final save.

### Possible Later Scope

- Android-only host card emulation for standards-compatible, legally controlled
  use cases.
- Write NDEF data to blank writable NFC tags.
- Import Apple Wallet `.pkpass` files or Google Wallet pass metadata where
  legally and technically practical.
- OCR for card text.
- OCR-assisted extraction for visiting cards.
- Shared family/team card folders.
- F-Droid release.
- Biometric/passcode app lock.

### Out Of Scope Unless Re-Approved

- Cloning payment cards.
- Storing credit card or debit card data.
- Bypassing access-control systems.
- Promising universal RFID/NFC emulation.
- Storing secrets in cloud services by default.
- Supporting cards the user is not authorized to possess or use.

## System Requirements

| ID | Requirement | Verification |
| --- | --- | --- |
| SYS-001 | The app shall allow a user to add a card with name, category, issuer, notes, and optional expiry date. | Widget test and manual acceptance test |
| SYS-002 | The app shall allow front and back images to be attached to a card. | Integration/manual test |
| SYS-003 | The app shall allow barcode/QR payloads to be stored and displayed. | Unit/widget test plus camera test |
| SYS-004 | The app shall read NFC NDEF data when platform APIs and the scanned tag support it. | Device integration test |
| SYS-005 | The app shall show a clear unsupported state when a card cannot be read or emulated. | Widget/manual test |
| SYS-006 | The app shall store card data locally by default. | Storage test |
| SYS-007 | The app shall not send card data to a server without explicit user action. | Code review and network behavior test |
| SYS-008 | The app shall support Android and iOS for the MVP app shell. | Android/iOS build checks |
| SYS-009 | The app shall keep payment-card cloning and unauthorized access-card copying out of the product scope. | Requirements review |
| SYS-010 | The app shall include user-controlled export/backup. | Integration/manual test |
| SYS-011 | The app shall not store credit card or debit card data. | Requirements review and code review |
| SYS-012 | The app shall support future biometric/passcode lock without making it mandatory in the first MVP. | Architecture review |
| SYS-013 | The prototype shall prioritize Android functionality while avoiding choices that block later iOS support. | Architecture review and Android/iOS build checks |
| SYS-014 | The app shall provide a card compatibility test flow that classifies a card's supported digital behavior. | Integration/manual test |
| SYS-015 | The app shall ask for permission before using camera, NFC, file export/import, or any other platform interface. | Manual/platform permission test |
| SYS-016 | The prototype shall export plain JSON first, with encrypted export planned before public release. | Export integration test and release review |
| SYS-017 | The app shall support extensible card categories beyond the default v0.1 category list. | Unit/widget test |
| SYS-018 | The app shall support a Visiting card preset with front-image capture and optional back image. | End-to-end visiting-card workflow test |
| SYS-019 | The app shall support on-device OCR extraction from visiting-card images. | Device/manual extraction test |
| SYS-020 | The app shall preserve raw OCR text alongside extracted visiting-card fields. | Unit/widget/integration test |
| SYS-021 | The app shall require user review before final save of extracted visiting-card fields. | Widget/manual workflow test |
| SYS-022 | The app shall support structured visiting-card fields including name, company, title, phone, email, website, and address-like text. | Unit/widget/integration test |
| SYS-023 | The smart-scan output shall be tightened on-device into a card-shaped region before being stored, so the saved image is OCR-friendly and presentable. The refinement shall be fail-safe (original output preserved on any failure) and shall not require new user permissions or network access. | Unit test for `computeCardCrop` geometry, integration test for `CardMediaService.scanCardPhoto` byte path, manual device check on Android/iOS |

## Platform Constraints

- Android supports NFC reading and, for some card types, host-based card
  emulation. HCE still does not mean every physical card can be copied, because
  many systems depend on secure elements, cryptographic challenge-response,
  fixed UIDs, issuer provisioning, or proprietary protocols.
- iOS Core NFC supports reading certain tags and sessions, but broad third-party
  card emulation is restricted. Apple Wallet/pass support is a separate issuer
  and platform pathway, not generic RFID cloning.
- Low-frequency RFID cards such as many 125 kHz access cards cannot be read by
  standard phone NFC hardware.

## MVP Success Criteria

- A user can replace a pile of loyalty/membership/barcode cards for lookup and
  presentation purposes.
- A user can inventory access/RFID/NFC cards and understand whether each card is
  readable, displayable, emulatable, or reference-only.
- A user can scan a visiting card and save reviewed contact details without
  retyping everything manually.
- The app gives honest guidance: "readable", "stored as reference only",
  "barcode displayable", "NFC NDEF readable", or "unsupported".
- The app remains free and private by design.

## User Direction Captured

- Support whatever non-bank card categories Android and iOS can realistically
  support.
- Do not store credit cards or debit cards.
- The long-term goal includes both storage and phone-as-card behavior for RFID
  and NFC cards.
- The MVP should be decided by feasibility, not by desire alone.
- Biometric/passcode unlock is not required on day one, but should be planned as
  an expected feature.
- The prototype should prioritize Android first, with iOS planned later.
- Card photos should be included from day one.
- The app should not depend on hosted cloud backup. Users should be able to
  export their data.
- A compatibility test flow is valuable and should be part of the prototype.
- The prototype export format should start as plain JSON for speed, then add
  encrypted export before release.
- The app should ask permission before using phone interfaces such as camera,
  NFC, and file access.
- Default categories are acceptable as long as they can be extended later.
