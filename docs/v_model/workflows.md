# Operational Workflows

Status: draft, created 2026-06-03.

## WF-001: Add A New Card

Preconditions:

- App is installed.
- User has a physical card or card details.

Main flow:

1. User taps add card.
2. User enters card name and optional issuer/category.
3. App asks permission before opening camera or NFC interfaces.
4. User captures front and back photos.
5. User scans barcode/QR if present or enters it manually.
6. User optionally runs compatibility test.
7. User saves the card.

Postconditions:

- Card is stored locally.
- Card appears in search/list.
- Capability status is set or marked untested.

## WF-002: Use A Barcode Or QR Card

Preconditions:

- Card has a stored barcode/QR payload.

Main flow:

1. User searches or opens favorites.
2. User opens the card.
3. User taps presentation mode.
4. App displays barcode/QR with high contrast and enough quiet zone.
5. External scanner reads the code.

Postconditions:

- No data leaves the app except the visible barcode/QR shown by the user.

## WF-003: Test RFID/NFC Compatibility

Preconditions:

- Phone supports the relevant NFC test path.
- User owns or is authorized to use the card.

Main flow:

1. User opens compatibility test.
2. App explains that not all RFID/NFC cards can be read or emulated.
3. App asks permission to use the relevant interface.
4. App checks device NFC availability.
5. User taps/scans the card.
6. App records readable metadata where allowed.
7. App classifies the result.

Possible results:

- NFC NDEF readable
- NFC detected but not readable
- Android HCE candidate
- Reference-only
- Unsupported by this phone
- Untested

Postconditions:

- Compatibility result is saved with the card.

## WF-004: Present A Reference-Only Card

Preconditions:

- Card has no usable barcode/QR or supported NFC behavior.
- Card has photos or metadata.

Main flow:

1. User opens the card.
2. App shows front/back images and notes.
3. User uses the physical card if required.

Postconditions:

- App has still helped the user identify the correct physical card.

## WF-005: Export Backup

Preconditions:

- User has at least one stored card.

Main flow:

1. User opens settings or export screen.
2. User chooses export.
3. App asks permission or opens the platform file/share interface.
4. App prepares a local backup file.
5. User saves/shares the file using platform file picker/share UI.

Postconditions:

- User owns a backup file.
- No hosted service is required.

Open decision:

- Resolved for prototype: plain JSON first. Encrypted export should be added
  before public release.

## WF-006: Import Backup

Preconditions:

- User has a Card Box backup file.

Main flow:

1. User opens import.
2. User selects a backup file.
3. App validates file format.
4. App previews import count and conflicts.
5. User confirms.
6. App restores card records and image references where available.

Postconditions:

- Imported cards appear in the catalog.

## WF-007: Future App Lock

Preconditions:

- App lock feature has been enabled.

Main flow:

1. User opens Card Box.
2. App requests biometric/passcode unlock.
3. User authenticates.
4. App opens catalog.

Postconditions:

- Card data is protected from casual access.
