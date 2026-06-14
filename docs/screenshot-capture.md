# Card Box — Screenshot Capture

How to produce the phone and tablet screenshots required by the Play
Console. Output goes into [`store_assets/`](../store_assets/) with the
filenames referenced in `store_assets/STORE_LISTING.md`.

---

## Device & environment

- **Phone:** Pixel 6+ / Samsung S21+ / OnePlus 9+ (Android 13 or 14).
  Anything with a 1080p+ display works; physical devices are preferred
  over emulators for the real device screenshots.
- **Tablet:** Android Studio AVD — one 7-inch (`Nexus 7` profile) and
  one 10-inch (`Pixel Tablet` profile), both running the closed-testing
  AAB.
- **Build:** the **closed-testing AAB** (not a debug build). Install it
  with `adb install` after downloading from the
  `build-android-release` Actions artifact.
- **Battery:** charge to 100% so the status bar does not show a
  low-battery glyph.
- **Connectivity:** **airplane mode ON**. The status bar should show
  the time only.
- **Seed data:** 5–8 sample cards covering the main categories
  (Loyalty, Transit, Library, ID, Gift). The in-app demo data covers
  this — just install, open, and accept the demo seed on first run.
- **Theme:** use the light theme for screenshots 1–4; the dark theme
  for screenshot 5 (Settings). System font scaling at 100%.

## Capture order

Capture in this order so the in-app state is always right when you
screenshot.

### Phone (5 screenshots)

| # | Filename | What to show |
|---|----------|--------------|
| 1 | `screenshot_phone_1_home.png` | Home screen — full list of cards with one or two visible barcodes |
| 2 | `screenshot_phone_2_card_detail.png` | Card detail — front photo, barcode preview, category, notes |
| 3 | `screenshot_phone_3_scan.png` | Scan flow mid-scan — camera viewport with a barcode/QR in frame |
| 4 | `screenshot_phone_4_edit.png` | Edit form — name, barcode field, category dropdown, notes |
| 5 | `screenshot_phone_5_settings.png` | Settings — theme toggle, app lock section, "Erase all data" |

### 7-inch tablet (1 screenshot)

| # | Filename | What to show |
|---|----------|--------------|
| 1 | `tablet_7in_screenshot_1_home.png` | Home screen (the wider layout) |

### 10-inch tablet (1 screenshot)

| # | Filename | What to show |
|---|----------|--------------|
| 1 | `tablet_10in_screenshot_1_home.png` | Home screen (master / detail split) |

## Quality bar

- **Resolution:** ≥1080 px on the long edge (Play Store promotional
  eligibility).
- **File size:** ≤8 MB per image; PNG preferred.
- **Status bar:** visible but clean (time only, no notifications, no
  low-battery glyph).
- **No cropping:** capture the full screen including the AppBar.
- **No debug banners:** the Flutter debug banner must be off (it is
  off in release builds by default).

## Capture command

```bash
# Capture a screenshot
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png store_assets/screenshot_phone_1_home.png

# Delete the file on the device
adb shell rm /sdcard/screenshot.png
```

The PNG lands in `store_assets/`; commit and push. Screenshots are
not secrets; they are part of the public Play Console listing.

## After capture

```bash
git add store_assets/screenshot_*.png store_assets/tablet_*.png
git commit -m "chore(store): upload Play Console screenshots"
git push
```

Then continue with [`docs/release-process.md`](release-process.md) §1
step G step 4 (fill in the Play Console listing).
