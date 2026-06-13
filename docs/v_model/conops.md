# Concept Of Operations

Status: active, last updated 2026-06-13.

## Mission

Card Box helps users reduce physical-card clutter by storing, organizing, and
presenting non-bank cards on a phone where technically and legally possible. It
also tells users when a card can only be stored as a reference.

## Operational Context

Users may carry loyalty cards, membership cards, ID reference cards, library
cards, gift cards, event passes, office/access cards, transit cards, visiting
cards, and other RFID/NFC/barcode cards. Card Box runs as a local-first mobile
app with no hosted backend.

The app must work in ordinary day-to-day environments:

- At a store checkout where a barcode or QR code needs to be shown quickly.
- At home while cataloging many physical cards.
- At an office or building entrance while checking whether an access card is
  phone-compatible.
- After meeting someone and wanting to save a visiting card without retyping
  contact details by hand.
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
| Catalog mode | Add, edit, search, favorite, archive, sort, and view card records |
| Presentation mode | Show barcode/QR or card image clearly for external scanning; the screen is kept awake while the user is presenting, and the card's `lastUsedAt`/`useCount` are updated on entry |
| Compatibility test mode | Determine whether the card is barcode/QR displayable, NFC readable, Android HCE candidate, reference-only, or unsupported |
| Contact extraction mode | Capture a visiting card, extract candidate fields, and let the user review them before save |
| Export/import mode | Let the user create and restore local backup files |
| Reuse / organize mode | Sort, favorites filter, duplicate an existing card as a starting point for a variant |
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
6. If the card is a visiting card, the user runs extraction and reviews
   candidate contact fields.
7. User runs compatibility test if the card has NFC/RFID behavior.
8. App stores the card locally and labels its digital capability.
9. Later, user searches for the card.
10. User presents the barcode/QR, references the photo, opens structured
   contact details, or sees that the card
   remains physical-only.

## Day-To-Day Reuse Patterns

The home list and search screen are the primary entry points once a user has
more than a handful of cards. The current prototype supports the following
reuse patterns:

- **Sort.** The home list can be sorted by name (A→Z, the default), name
  (Z→A), most recently updated, or most recently added. The selection is
  remembered across launches.
- **Favorites filter.** A one-tap chip on the home list hides every
  non-favorited card. It composes with the category filter and the
  free-text search. Favorites continue to sort to the top of any active
  sort.
- **Duplicate.** The more-options sheet for a card offers a "Duplicate"
  action that creates a peer card with the same fields and photos but a
  fresh id, the name suffixed with "(copy)", and new timestamps. This is
  the recommended way to spin up a slightly different variant of an
  existing card (for example, a second loyalty account at the same
  merchant) without re-entering all the data by hand.
- **Scan-time duplicate detection.** When a user is adding or editing a
  card and scans a barcode whose payload is already on another card, the
  app shows a one-tap prompt: jump to the existing card, or keep scanning
  a different code. This prevents the most common data-entry mistake
  (creating a second card that secretly points to the same code).
- **Presentation lock and use tracking.** When the user opens the
  present-code or present-card screen for a card, the app keeps the
  screen awake (via `wakelock_plus`) for the duration of the scan and
  records a `lastUsedAt` timestamp plus an incrementing `useCount`. The
  recent list on the home screen surfaces cards by recency, so frequently
  used cards stay easy to find.

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
