# Card Box — Google Play Store Listing

All text and asset details needed to fill in the Play Console store listing.

---

## Listing Text

### App name (8 / 30 chars)
```
Card Box
```

### Promo text (≤80 chars)
```
Local-first card organiser. No ads. No data leaves your device.
```

### Short description (≤80 chars)
```
A free, local-first card organiser. No ads. No data collected. Works offline.
```

### Full description (paste as-is)
```
Card Box keeps all your non-bank cards in one place on your device — no account, no cloud, no ads, no internet permission. Loyalty, membership, library, ID, transit, gift, and visiting cards stay private and offline.

━━ WHAT YOU CAN STORE ━━

🎟 Loyalty & rewards — supermarket, café, restaurant, hotel
🚇 Transit — metro, bus, train, ferry, bike-share
📚 Library & education — public library, university, museum
🪪 ID & membership — gym, club, association, employee
🎁 Gift & prepaid — gift cards with a balance
🛂 Visiting — temporary passes and one-time codes

━━ FEATURES ━━

• Scan — use the camera to read a barcode (1D/2D) or QR code. Detects common formats.
• Front / back photos — optionally capture each side of a physical card.
• Manual entry — type the barcode value, name, notes, and category.
• Categories — built-in categories (Loyalty, Transit, Library, ID, Gift, Visiting) plus your own.
• Favorites — pin the cards you reach for daily.
• Sort & search — by name, category, recent, or favorites first.
• Export — JSON (plain) or AES-256-GCM encrypted with PBKDF2-HMAC-SHA256 (password-derived key).
• Import — restore from a previous export. Encrypted imports require the password.
• NFC — read contactless card identifiers via the device's NFC radio.
• OCR — on-device text recognition (English, Chinese, Devanagari, Japanese, Korean) to extract the printed card number from a photo.
• Optional app lock — PIN or device biometric. The app must be unlocked on resume when enabled.
• Dark mode — easy on the eyes, follows the system theme.
• Erase all data — one tap in Settings permanently wipes the local database.

━━ PRIVACY ━━

Card Box does NOT hold the Android INTERNET permission. It cannot make any network request. All data is stored locally on your device in an encrypted SQLite database; the encryption key lives in Android's hardware-backed keystore.

No ads. No tracking. No accounts. No in-app purchases. Safe for all ages and fully compliant with COPPA, GDPR, and the Google Play Families Policy.

Privacy policy: https://learn-by-exploration.github.io/CardBox/privacy-policy.html
Data safety:    https://learn-by-exploration.github.io/CardBox/data-safety.html
```

---

## Links

| Field | Value |
|-------|-------|
| Privacy policy URL | `https://learn-by-exploration.github.io/CardBox/privacy-policy.html` |
| Data safety reference | `https://learn-by-exploration.github.io/CardBox/data-safety.html` |
| GitHub repo | `https://github.com/learn-by-exploration/CardBox` |
| Support URL | `https://github.com/learn-by-exploration/CardBox/issues` |
| Contact email | _(TBD — your real contact email; set in Play Console)_ |

---

## Image Upload Checklist

Upload each file to the indicated slot in **Play Console → Store listing → Default (en-US)**.

### App icon
| File | Slot | Spec |
|------|------|------|
| `icon_512.png` | App icon | 512×512 PNG, ≤1 MB |

### Feature graphic
| File | Slot | Spec |
|------|------|------|
| `feature_graphic_1024x500.png` | Feature graphic | 1024×500 PNG/JPEG, ≤15 MB |

### Phone screenshots *(upload in order, 2–8 allowed)*
| # | File | Content |
|---|------|---------|
| 1 | `screenshot_phone_1_home.png` | Home screen — list of cards (real device) |
| 2 | `screenshot_phone_2_card_detail.png` | Card detail — front photo, barcode, notes (real device) |
| 3 | `screenshot_phone_3_scan.png` | Barcode / QR scan in progress (real device) |
| 4 | `screenshot_phone_4_edit.png` | Edit card form — name, category, notes (real device) |
| 5 | `screenshot_phone_5_settings.png` | Settings — theme, app lock, erase data (real device) |

### 7-inch tablet screenshots *(up to 8)*
| # | File | Content |
|---|------|---------|
| 1 | `tablet_7in_screenshot_1_home.png` | Home screen |

### 10-inch tablet screenshots *(up to 8)*
| # | File | Content |
|---|------|---------|
| 1 | `tablet_10in_screenshot_1_home.png` | Home screen |

### Skip / leave blank
- Video — no YouTube video
- Chromebook screenshots — not required
- Google Play Games on PC — not applicable
- Android XR — not applicable

---

## Content Rating & Policy Answers

| Section | Answer |
|---------|--------|
| App access | All features accessible, no login required |
| Ads | No ads |
| Content rating | Everyone (no violence, no mature content) |
| Target audience | All ages including children — Families policy compliant |
| Data safety — collects data? | No |
| Data safety — shares data? | No |
| Data safety — encrypted in transit? | N/A (no data transmitted — no INTERNET permission) |
| Data safety — user can request deletion? | Yes (in-app "Erase all data" or uninstall) |
| App category | **Productivity** _(recommended for an organiser; alternative: Games → Card)_ |
| Government apps | No |
| Financial features | No |
| Health | No |

---

## Regenerating Assets

If you need to regenerate the icon or feature graphic:

```bash
# Resize the source icon (2048×2048 app_icon.png → 512×512)
python3 -c "
from PIL import Image
img = Image.open('app_icon.png').convert('RGBA')
img.resize((512, 512), Image.LANCZOS).save('store_assets/icon_512.png')
"
```

For the adaptive icon foreground, place the source at `app_icon.png` at the
repo root and run `dart run flutter_launcher_icons` to regenerate the
mipmaps (see `flutter_launcher_icons` config in `pubspec.yaml`).

### Screenshot quality notes
- Capture on a real device (Pixel 6+ / Samsung S21+ / OnePlus 9+) on
  Android 13 or 14, **from the closed-testing AAB** (not a debug build).
- Enable **airplane mode** so the status bar shows the time only.
- Charge to **100%** so the battery icon does not show low.
- Seed the app with **5–8 sample cards** (the demo data covers this).
- Screenshot at full resolution (≥1080 px on the long edge).
- See [`docs/screenshot-capture.md`](../docs/screenshot-capture.md) for
  the full capture workflow and the `adb` commands.
