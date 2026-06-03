# Concept Of Operations

Status: draft, created 2026-06-03.

## Mission

Card Box helps users reduce physical-card clutter by storing, organizing, and
presenting non-bank cards on a phone where technically and legally possible. It
also tells users when a card can only be stored as a reference.

## Operational Context

Users may carry loyalty cards, membership cards, ID reference cards, library
cards, gift cards, event passes, office/access cards, transit cards, and other
RFID/NFC/barcode cards. Card Box runs as a local-first mobile app with no hosted
backend.

The app must work in ordinary day-to-day environments:

- At a store checkout where a barcode or QR code needs to be shown quickly.
- At home while cataloging many physical cards.
- At an office or building entrance while checking whether an access card is
  phone-compatible.
- While preparing for travel or cleanup by exporting a backup file.

## Actors

| Actor | Role |
| --- | --- |
| Primary user | Owns cards and manages them in the app |
| Checkout staff / scanner | Scans visible barcode/QR shown by the user |
| Phone platform | Provides camera, storage, NFC, and optional biometric APIs |
| Physical card | Source of photos, barcode/QR, NFC metadata, or unsupported behavior |

## Operating Modes

| Mode | Description |
| --- | --- |
| Catalog mode | Add, edit, search, favorite, archive, and view card records |
| Presentation mode | Show barcode/QR or card image clearly for external scanning |
| Compatibility test mode | Determine whether the card is barcode/QR displayable, NFC readable, Android HCE candidate, reference-only, or unsupported |
| Export/import mode | Let the user create and restore local backup files |
| Future secure mode | Protect app entry or sensitive cards with biometric/passcode lock |

## Default Card Categories

The v0.1 app starts with Loyalty, Membership, Access, Transit, Gift, ID,
Library, and Other. Categories must remain extensible so the product can support
new real-world card types without redesigning the card model.

## Normal Operational Scenario

1. User opens Card Box.
2. User adds a card.
3. User captures front and back photos.
4. User scans visible barcode/QR if present.
5. User grants permission before camera/NFC/file interfaces are used.
6. User runs compatibility test if the card has NFC/RFID behavior.
7. App stores the card locally and labels its digital capability.
8. Later, user searches for the card.
9. User presents the barcode/QR, references the photo, or sees that the card
   remains physical-only.

## Constraints

- No credit or debit cards.
- No hosted backend.
- No universal RFID/NFC emulation promise.
- Android is the first prototype platform.
- iOS support must remain planned.
- Data should remain local unless the user explicitly exports it.

## Success Definition

The app succeeds if a user can meaningfully reduce day-to-day card clutter for
non-bank cards, even when some RFID/NFC cards cannot be emulated.
