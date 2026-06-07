# Android Device Acceptance

This checklist is for validating the Android build on a real phone after the
automated Flutter test suite passes.

## Goal

Confirm that the user-facing camera, scanner, backup, NFC, and lock flows feel
correct on real hardware, not just in code.

## Test Build

- Install the latest release APK:
  - `build/app/outputs/flutter-apk/app-release.apk`

## Recommended Order

Run this alongside:

- [Android device validation matrix](android_device_matrix.md)
- [Android test session log](android_test_session_log.md)
- [Prefilled 2026-06-07 session runbook](android_test_session_2026-06-07.md)
- [Android bug report template](android_bug_report_template.md)

Suggested execution:

1. fill in the device/session header
2. run the acceptance checklist below
3. mark each scenario in the validation matrix
4. file one bug report per failure
5. summarize the session in the session log

## Capture Environment

Record these before testing:

- Phone model
- Android version
- Region / language
- Whether Google Play Services is up to date

## Acceptance Flow

### 1. First Launch

- Open the app
- Confirm the app launches without a crash
- Confirm the first screen is readable and uncluttered
- Confirm a fresh install starts empty unless demo seeding was intentionally enabled

Expected:

- App opens cleanly
- No overflow, missing text, or frozen controls

### 2. Add Barcode Card

- Tap `Add card`
- Choose `Barcode card`
- Use `Scan barcode or QR`
- Hold a real code in frame
- Confirm the app waits for a stable read
- Accept the suggested code
- Save the card
- Open the card and tap `Show code`

Expected:

- Scanner opens
- No accidental instant misread
- Candidate confirm step appears
- Saved code renders correctly full-screen

### 3. Add Reference Card With Camera

- Tap `Add card`
- Choose `Reference card`
- Tap `Use camera`
- Capture a front image
- Save the card

Expected:

- Camera opens
- Captured image appears in the editor
- Save completes
- Card detail shows the saved image

### 4. Smart Scan

- Edit a card or add a new photo-backed card
- Tap `Smart scan`
- Complete a one-page scan
- Save the card

Expected:

- Scanner opens
- Edge/corner flow is usable
- Result returns to Card Box
- Scanned image is visible after save

If this fails, record exactly which one happened:

- nothing happens
- scanner opens then closes
- scanner opens but no result returns
- error message appears
- fallback prompt appears

### 5. Edit Photo

- Open a saved card with an image
- Tap `Edit photo`
- Crop or rotate
- Save the edit

Expected:

- Editor opens
- Crop/rotate controls work
- Returning to Card Box keeps the edited image

If this fails, record:

- nothing happens
- editor opens then closes
- editor saves but image does not change
- error message appears

### 6. Camera Fallback After Scan Failure

Only run this if `Smart scan` fails on the device.

- Trigger `Smart scan`
- Confirm Card Box offers `Use camera`
- Continue with `Use camera`

Expected:

- User is not stuck
- Camera fallback is clear and usable

### 7. Visiting Card OCR

- Add a `Visiting card`
- Capture or scan the card
- Tap `Extract details`
- Review the suggested fields
- Save

Expected:

- OCR review screen appears
- Name / company / phone / email suggestions are editable
- Saved contact fields appear in detail view
- Original card image remains available

### 8. Full Image Viewer

- Open a card with a saved image
- Tap the image
- Zoom
- Rotate left / right
- Reset rotation

Expected:

- Full-screen viewer opens
- Zoom and pan feel normal
- Rotation controls work

### 9. Encrypted Backup

- Open `Backup and import`
- Create an encrypted backup
- Confirm a password prompt appears
- Confirm the Android share sheet opens

Expected:

- Backup completes
- Share sheet opens
- No overflow or stuck loading state

### 10. Import Backup

- Reopen `Backup and import`
- Choose the exported backup file
- If encrypted, enter the password

Expected:

- Import succeeds
- Cards and images are restored

### 11. NFC Settings Flow

- Open an NFC / RFID card
- Tap `Test NFC/RFID`
- If NFC is off, use `Turn on NFC`
- Return to the app

Expected:

- Card Box returns cleanly from Android settings
- NFC availability refreshes
- No unnecessary relock during this trusted external flow

### 12. NFC Scan Flow

Use two real cards if possible:

- one readable or partially readable NFC card
- one card the phone only detects but cannot read usefully

Expected:

- session starts only after user consent
- readable card produces a useful summary
- non-readable card produces a clear detected-only style result
- app does not freeze when leaving or returning during the flow

### 13. App Lock Lifecycle

If app lock is enabled:

- lock the app
- unlock with PIN
- if available, unlock with biometrics
- background the app
- reopen from recents
- leave and return during camera / scanner / settings flows

Expected:

- normal backgrounding can require unlock again when configured
- trusted external flows do not create annoying immediate relock loops
- recent-apps preview should not expose sensitive content

## Pass Criteria

Android is ready for broader testing when:

- no crashes occur in the core flows above
- `Smart scan`, `Edit photo`, and `Use camera` are all usable on the device
- barcode and visiting-card flows are end-to-end functional
- encrypted backup export/import works
- app lock behaves predictably

## If Something Fails

Use [android_bug_report_template.md](android_bug_report_template.md) and fill
in one report per issue.
