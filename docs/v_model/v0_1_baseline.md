# v0.1 Requirements Baseline

Status: active, created 2026-06-03, last reviewed 2026-06-13.

## Product Name

Working name: Card Box.

The name is acceptable for now. It may be revisited before public release if a
simpler or more creative name is chosen.

## Prototype Strategy

- Flutter app.
- Android-first implementation.
- iOS support planned later.
- Offline/local-first.
- No hosted backend.
- No credit or debit cards.
- Card photos included from day one.
- Barcode/QR support included from day one.
- NFC compatibility testing included from day one where Android hardware and
  permissions allow it.
- RFID/NFC emulation is a later capability track, not required for v0.1.

## Default Categories

- Loyalty
- Membership
- Access
- Transit
- Gift
- ID
- Library
- Other

The category system must be extensible.

## Export Strategy

v0.1 export format: plain JSON.

Release readiness target: encrypted export.

Reason: plain JSON is faster to implement and verify in the prototype. Since
there is no hosted backend, export/import is the user's backup path.

## Permission Strategy

The app should ask before using:

- Camera
- NFC
- File export/import
- Future biometric/passcode flows

The compatibility test should be permission-first and card-type aware.

## Acceptance Test Card Set

Use common non-bank cards for manual testing without recording private card
numbers:

- Office/access card, NFC/RFID unknown
- Supermarket loyalty card, barcode
- Metro/transit card, NFC
- Library card, barcode
- Membership card, barcode or QR
- Gift card, barcode
- ID/reference card, photo-only/reference-only

## Approval Status

This baseline is ready to drive initial Flutter scaffolding and prototype
implementation unless the user changes one of the product decisions above.

## What Has Shipped Against This Baseline

As of 2026-06-13 the prototype is past the scaffolding stage and the
catalog, presentation, compatibility-test, contact-extraction, and
export/import modes from the ConOps doc are all functional on Android
(see `implementation_status.md` for the full inventory). Two capabilities
called out in the ConOps as future work — expiry reminders and
acceptance locations — have been formally deferred to a later pass;
see `open_questions.md` for the rationale.

