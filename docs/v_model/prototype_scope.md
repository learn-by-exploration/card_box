# Prototype Scope

Status: draft, created 2026-06-03.

## Prototype Goal

Build an Android-first Flutter prototype that proves Card Box can be useful
without hosted services and without payment-card support.

## First Prototype Screens

| Screen | Purpose |
| --- | --- |
| Home / Cards | Search, filter, and open saved cards |
| Add Card | Create a card manually and choose card type/category |
| Card Detail | View card fields, photos, barcode/QR, NFC capability status |
| Capture Photos | Add front and back card images |
| Barcode / QR Scan | Scan or manually enter barcode/QR payload |
| Compatibility Test | Run guided checks and classify card behavior |
| Visiting Card Review | Review OCR-extracted visiting-card details before save |
| Export / Import | Save and restore user-controlled backups |
| Settings | Theme, export, future app-lock entry point |

## Default v0.1 Categories

- Loyalty
- Membership
- Access
- Transit
- Gift
- ID
- Library
- Other

Categories should be modeled so custom categories can be added later.

## Compatibility Test Flow

1. Ask user what kind of card they believe it is.
2. Ask for permission before using camera, NFC, or other platform interfaces.
3. Offer barcode/QR scan if the card has visible codes.
4. Offer NFC scan if the device supports NFC.
5. Capture result:
   - Barcode/QR displayable
   - NFC NDEF readable
   - NFC detected but not readable
   - Android HCE candidate
   - Reference-only
   - Unsupported by this phone
6. Save the result to the card record with a timestamp and platform details.

## Prototype Data Model

Draft fields:

- `id`
- `name`
- `issuer`
- `category`
- `notes`
- `expiryDate`
- `favorite`
- `archived`
- `frontImagePath`
- `backImagePath`
- `barcodePayload`
- `barcodeFormat`
- `nfcTagSummary`
- `compatibilityStatus`
- `createdAt`
- `updatedAt`

Additional visiting-card fields:

- `cardType`
- `rawOcrText`
- `contactName`
- `contactCompany`
- `contactTitle`
- `contactPhones`
- `contactEmails`
- `contactWebsites`
- `contactAddress`
- `contactNotes`

## Prototype Non-Goals

- Credit/debit cards.
- Cloud sync.
- User accounts.
- Guaranteed RFID/NFC emulation.
- Publishing to app stores.

## Prototype Export

The first prototype should export plain JSON because it is easy to build, debug,
and verify. Encrypted export should be added before public release.
