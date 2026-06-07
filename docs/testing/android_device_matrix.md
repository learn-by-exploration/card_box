# Android Device Validation Matrix

Use this matrix with the release APK during real-device validation. The goal is
to turn "I tried a few things" into a repeatable pass that shows where native
behavior is solid and where it still varies by device.

## Test Assets

Prepare these before starting:

- 1 QR code card
- 1 one-dimensional barcode card
- 1 photo/reference-only card
- 1 visiting card
- 1 readable or partially readable NFC card, if available
- 1 NFC card that the phone detects but cannot usefully read, if available
- 1 previously exported backup file

## Device Record

Fill this in once per phone:

| Field | Value |
| --- | --- |
| Tester |  |
| Date |  |
| Phone model |  |
| Android version |  |
| Region / language |  |
| Play Services up to date | Yes / No |
| App build | release APK path or version |

## Result Codes

Use one result per row:

- `PASS`
- `PASS-WARN`
- `FAIL`
- `N/A`

Use `PASS-WARN` when the flow works but feels rough, slow, or confusing.

## Matrix

| Area | Scenario | What to check | Result | Notes |
| --- | --- | --- | --- | --- |
| Launch | Fresh open | App opens cleanly, no crash, no clipped text |  |  |
| Launch | Fresh install state | Empty state is correct unless demo seeding was intentionally enabled |  |  |
| Home | Browse cards | Cards/contacts views are understandable and uncluttered |  |  |
| Home | Search flow | Search screen opens from FAB and returns useful results |  |  |
| Home | Grid/list toggle | Both layouts render cleanly with no overflow |  |  |
| Add card | Barcode card | Add flow is understandable and save succeeds |  |  |
| Scanner | QR scan | Scanner opens, stable read works, confirm flow feels good |  |  |
| Scanner | 1D barcode scan | Barcode mode detects correctly and is not overly jumpy |  |  |
| Scanner | Mode switch | Barcode / QR / All switches behave correctly |  |  |
| Scanner | Torch | Torch toggles correctly while scanner is active |  |  |
| Scanner | Permission denied | Open settings path works and recovery is smooth |  |  |
| Photos | Use camera | Camera returns image into Card Box cleanly |  |  |
| Photos | Choose photo | Library import returns image correctly |  |  |
| Photos | Edit photo | Crop/edit flow works and result is saved |  |  |
| Photos | Full image viewer | Zoom / rotate / reset all behave correctly |  |  |
| Smart scan | Guided path | Smart scan opens and returns image |  |  |
| Smart scan | Fallback path | Fallback to camera/crop is understandable if guided scan fails |  |  |
| Visiting card | Capture | Visiting card add flow is clear from Add card |  |  |
| Visiting card | OCR extraction | Suggestions are useful and review flow is editable |  |  |
| Visiting card | Contact QR | Contact QR opens and looks scannable |  |  |
| Visiting card | vCard export | Export completes without crash |  |  |
| Backup | Standard export | Backup file is created and share sheet opens |  |  |
| Backup | Encrypted export | Password flow is usable and no overflow occurs |  |  |
| Backup | Import | Import succeeds and images restore correctly |  |  |
| Categories | Add custom category | Add succeeds without dialog errors |  |  |
| Categories | Rename custom category | Rename succeeds and cards update |  |  |
| Categories | Migrate category | Move cards flow works and result is clear |  |  |
| Archive | Archive card | Archive action is discoverable and succeeds |  |  |
| Archive | Archived screen | Restore/delete/open all work |  |  |
| NFC | Settings handoff | Turn on NFC opens settings and refreshes on return |  |  |
| NFC | Readable card | Scan produces a useful summary |  |  |
| NFC | Detected-only card | Scan produces a clear detected-only result |  |  |
| Lock | Unlock flow | PIN/biometric flow works if enabled |  |  |
| Lock | Background lifecycle | Resume behavior feels predictable |  |  |
| Lock | External flow trust | Camera/scanner/settings do not trigger annoying relock loops |  |  |

## Exit Criteria

This device is considered healthy for the current release when:

- all core flows are `PASS` or `PASS-WARN`
- no `FAIL` remains in:
  - scanner
  - smart scan
  - camera/photo edit
  - backup export/import
  - NFC settings return
  - app lock lifecycle

Any `FAIL` should get its own report using
[android_bug_report_template.md](android_bug_report_template.md).
