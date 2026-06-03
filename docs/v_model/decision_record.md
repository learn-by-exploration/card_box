# Decision Record

## DR-001: MVP Strategy For Card Emulation

Date: 2026-06-03

Decision: The MVP will focus on storage, organization, barcode/QR presentation,
camera capture, and NFC reading/capability detection. It will not depend on
RFID/NFC emulation being available before the app becomes useful.

Reasoning:

- The product vision includes the phone acting like physical RFID/NFC cards.
- Android can support some host-based card emulation scenarios, but not all
  cards can be emulated. Cards depending on fixed UID behavior, secure elements,
  proprietary protocols, or cryptographic challenge-response may not work.
- iOS does not provide broad general-purpose third-party RFID/NFC emulation.
- Many low-frequency RFID cards are outside normal phone NFC hardware support.
- A useful free app can ship sooner by organizing cards and making supported
  cards presentable/readable while labeling unsupported cards honestly.

Implication:

- Emulation becomes a later, platform-specific feature track, starting with
  Android and only for legally controlled, technically compatible cards.
- The app UI should classify capabilities per card:
  - Reference-only
  - Barcode/QR displayable
  - NFC readable
  - NFC writable to blank tag
  - Android HCE candidate
  - Unsupported

## DR-002: Payment Cards

Date: 2026-06-03

Decision: Card Box will not store credit card or debit card data.

Reasoning:

- Payment cards require compliance, issuer approval, security review, and
  potentially regulated infrastructure.
- The user explicitly does not want to include credit or debit cards.

Implication:

- Payment-card cloning, payment-card reading, and payment-card storage remain
  out of scope.
- The app may still support non-payment loyalty, membership, gift, library,
  student, event, identity reference, and access-card inventory use cases where
  legal and technically practical.

## DR-003: Biometric And Passcode Lock

Date: 2026-06-03

Decision: Biometric/passcode lock is not mandatory for the first MVP, but the
architecture should plan for it.

Reasoning:

- Card images, IDs, access card metadata, notes, and barcodes can still be
  sensitive even when bank cards are excluded.
- The user said it is not necessary on day one but is definitely wanted.

Implication:

- Storage and navigation should avoid choices that make later app-lock support
  awkward.
- The first implementation should evaluate secure storage and encrypted local
  data patterns.

## DR-004: Prototype Platform Priority

Date: 2026-06-03

Decision: Use Flutter and prioritize Android for the first real prototype, while
keeping iOS compatibility in the architecture.

Reasoning:

- Android gives the best early path for NFC reading experiments and later HCE
  investigation.
- Flutter still lets the app keep a credible iOS path for organization,
  barcode/QR, photos, export, and supported NFC reading.

Implication:

- Early device tests should focus on Android.
- Package choices should be checked for iOS support before adoption.
- Android-only behavior should be isolated behind capability services.

## DR-005: Backup Strategy

Date: 2026-06-03

Decision: The app will not rely on hosted cloud backup. Users should export
their own data.

Reasoning:

- The project should remain free to run and publish.
- Hosting introduces cost, privacy, maintenance, account, and security burdens.

Implication:

- Export/import becomes a first-class requirement.
- Encrypted export should be evaluated before public release.

## DR-006: Card Photos

Date: 2026-06-03

Decision: Card photos should be included in the first prototype.

Reasoning:

- Photos make the app useful even when barcode, QR, NFC, or RFID behavior is not
  supported.
- Photos help identify cards quickly in a crowded wallet.

Implication:

- The first data model must support front and back image references.
- Storage size and export size should be considered early.

## DR-007: Compatibility Test Flow

Date: 2026-06-03

Decision: The app should include a card compatibility test flow.

Reasoning:

- Users want to know whether a card can be read, displayed, emulated, or only
  stored as a reference.
- This prevents false expectations around RFID/NFC support.

Implication:

- The app should guide users through barcode/QR scan, NFC scan, and manual
  classification.
- The result should be stored on the card record.

## DR-008: Prototype Export Format

Date: 2026-06-03

Decision: The first prototype will export plain JSON. Encrypted export should be
added before public release.

Reasoning:

- Plain JSON is easiest to implement, inspect, and test in the early prototype.
- Export is user-controlled and no hosted service is involved.
- Card data can still be sensitive, so encrypted export remains important for
  release readiness.

Implication:

- v0.1 export/import tests can verify structure and round-trip behavior.
- Release requirements should include encrypted export.

## DR-009: App Name

Date: 2026-06-03

Decision: Use Card Box as the working app name.

Reasoning:

- It is simple, understandable, and matches the existing `board_box` naming
  pattern.
- A simpler or more creative public name can be revisited before release.

Implication:

- The project folder remains `card_box`.
- Product copy can use Card Box unless renamed later.

## DR-010: Permission-First Platform Interfaces

Date: 2026-06-03

Decision: The app should ask permission before using camera, NFC, file
export/import, or other platform interfaces.

Reasoning:

- Users should understand which phone capability is about to be used.
- Compatibility testing depends on card type and platform support.

Implication:

- Workflows should show permission or consent steps before scan/export actions.
- Platform services should expose capability checks and permission outcomes.
