# Android Device Test Session - 2026-06-07

This is the first recommended real-device validation pass for the current
Card Box release build.

## Build Under Test

- APK: `/home/shyam/common_games/card_box/build/app/outputs/flutter-apk/app-release.apk`
- Test date: `2026-06-07`

## Session Header

- Tester:
- Phone model:
- Android version:
- Region / language:
- Play Services up to date:

## Recommended Test Order

Run these in order. This sequence is designed to surface the highest-risk
native/device issues first.

### 1. Launch and Home

- Install and open the release APK
- Confirm first launch is clean
- Switch between `Cards` and `Contacts`
- Switch between `List` and `Grid`
- Open search from the floating search button

Record:
- any overflow
- any clipped text
- any lag or frozen controls

### 2. Live Scanner

- Add a `Barcode card`
- Open scanner in `QR` mode and scan one real QR code
- Reopen scanner in `Barcode` mode and scan one real 1D barcode
- Switch between `Barcode -> QR -> All -> Barcode`
- Toggle torch while the scanner is active

Record:
- whether scanner opens reliably
- whether wrong reads happen
- whether torch works
- whether any camera/null-object/device-level error appears

### 3. Camera and Photo Editing

- Add a `Reference card`
- Use `Use camera`
- Save the card
- Open it again and use `Edit photo`
- Crop or rotate, then save
- Open the full image viewer and test zoom / rotate / reset

Record:
- if camera opens
- if crop/editor opens
- if edited image actually changes
- if any photo path gets lost

### 4. Smart Scan

- Edit a card or add a new photo-backed card
- Tap `Smart scan`
- Complete a one-page guided scan if it opens
- If the guided scanner fails, continue with fallback if offered

Record exactly which happened:
- guided scanner opens and returns image
- nothing happens
- opens then closes
- fallback appears
- fallback works
- error message appears

### 5. Visiting Card Flow

- Add a `Visiting card` from the standard `Add card` flow
- Capture or scan the front
- Run `Extract details`
- Adjust one or two extracted fields
- Save the card
- Open `Show contact QR`
- Try `Share contact` or `Export vCard`

Record:
- quality of OCR suggestions
- whether original image remains visible
- whether contact actions feel obvious

### 6. Backup and Import

- Create a normal backup
- Create an encrypted backup
- Confirm the Android share sheet appears
- Re-import a previously exported backup

Record:
- any overflow in password prompts
- whether import restores images
- whether import reports added/updated/skipped clearly

### 7. Categories and Archive

- Add a custom category
- Rename it
- Migrate cards into or out of it
- Archive one card from card details
- Open `Archived cards`
- Restore it

Record:
- any dialog crash/assertion
- whether counts/results are clear
- whether archive feels discoverable

### 8. NFC / RFID

- Open an NFC/RFID-capable or test card
- Use `Test NFC/RFID`
- If NFC is off, use `Turn on NFC`
- Return to the app and test scanning

If available, test:
- one readable card
- one detected-only / unreadable card

Record:
- whether settings handoff returns cleanly
- whether availability refreshes
- whether result wording is understandable

### 9. App Lock and Lifecycle

If app lock is enabled:

- lock and unlock with PIN
- test biometrics if available
- background the app and reopen
- leave and return during camera, scanner, and settings flows

Record:
- whether relock is predictable
- whether trusted flows avoid annoying relock loops
- whether recents preview behavior is acceptable on the device

## Overall Result

- Pass
- Pass with warnings
- Failed

## Main Bugs Found

1.
2.
3.

## What To Send Back

After the run, send back:

- phone model
- Android version
- which step failed
- exact user-visible behavior
- any error text shown on screen
- whether the issue is always reproducible or intermittent

If an issue appears, prefer one short report per issue rather than one giant
mixed note.
