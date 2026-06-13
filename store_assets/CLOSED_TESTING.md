# Card Box — Closed Testing Guide

Instructions for both the developer (Play Console setup) and testers (how to join and what to test).

---

## Part 1 — Developer: Setting Up the Closed Testing Track

### 1. Upload the AAB
1. Go to **Play Console → Card Box → Testing → Closed testing**
2. Click **Create new release**
3. Upload `app-release.aab` (from CI artifacts or `flutter build appbundle --release`)
4. Fill in **Release notes** (e.g. "Initial closed test build — local-first card organiser, scan/edit/lock/export")
5. Click **Save → Review release → Start rollout**

### 2. Add testers
1. Go to **Closed testing → Testers** tab
2. Either:
   - **Email list** — paste individual Gmail addresses (one per line)
   - **Google Group** — create a group at groups.google.com and paste the group email
3. Click **Save changes**
4. Copy the **opt-in URL** shown on the same page — share this with testers

### 3. Check release status
- The build usually takes **a few hours** to become available after rollout
- Status should change from "In review" → "Available on Google Play"

---

## Part 2 — Tester: How to Join

1. Open the **opt-in URL** shared by the developer on your Android device
2. Tap **Become a tester**
3. Tap the **download link** on that page — it opens the Play Store
4. Install **Card Box** normally from the Play Store
5. To leave the test: return to the opt-in URL and tap **Leave the program**

**Requirements:**
- Android device (phone or tablet) — Android 7.0+ (API 24+)
- Google account that was added to the tester list
- Play Store app installed and signed in with that account
- Optional: a device with NFC to test the NFC read flow

---

## Part 3 — What to Test

Work through each area below. Note anything unexpected and report it (see Part 4).

### Core flow (add / edit / delete / organise)
- [ ] Add a new card manually (name + barcode value + category)
- [ ] Add a new card by scanning a barcode / QR code
- [ ] Edit an existing card — change name, notes, category
- [ ] Duplicate a card from the detail screen
- [ ] Delete a card — confirm the confirmation dialog
- [ ] Mark a card as favorite; un-favorite it
- [ ] Sort by name, by recent, by category
- [ ] Search for a card by partial name

### Lock & security
- [ ] Enable **PIN lock** in Settings — set a 4–6 digit PIN
- [ ] Lock and unlock with the PIN
- [ ] Enable **biometric lock** (where supported) — set up, lock, unlock with fingerprint/face
- [ ] **Lock on resume** — put the app in the background, return → lock screen appears
- [ ] **Erase all data** in Settings → confirm the database and key are wiped; the app returns to the empty state
- [ ] Wrong PIN rejected with a clear error

### Export & import
- [ ] Export to **plain JSON** — the file is human-readable and contains your card entries
- [ ] Export to **encrypted JSON** — set a password; the file is opaque
- [ ] Import the plain JSON you just exported → cards reappear
- [ ] Import the encrypted JSON with the **correct** password → cards reappear
- [ ] Import the encrypted JSON with the **wrong** password → rejected with a clear error

### Barcode / QR
- [ ] First scan triggers a **camera permission** prompt
- [ ] Scan a QR code → the payload populates the barcode field
- [ ] Scan a 1D barcode (EAN, Code 128) → the value populates
- [ ] Scan a duplicate → app nudges you to the existing card rather than creating a new one
- [ ] Rapid-tap a card — no crash, no double-entry

### NFC (where supported)
- [ ] Place a contactless card on the back of the device → identifier populates a new card
- [ ] Move the card away before the read completes → graceful "no card" / "move closer" message
- [ ] iOS-only session errors do not affect Android testers

### OCR (where supported)
- [ ] Capture a card photo and use **Extract text** → the printed card number populates
- [ ] Repeat in **airplane mode** → the extraction still works (it is on-device)

### Settings
- [ ] **Theme** — toggle system / light / dark; persists across restarts
- [ ] **Sort order** — persists
- [ ] **Custom categories** — add, rename, delete (with the warning that the rename may be one-way)

### Privacy policy
- [ ] Open **Settings → Privacy Policy** — page loads inside the app
- [ ] The page is also accessible in a browser at:
  `https://learn-by-exploration.github.io/CardBox/privacy-policy.html`

### Edge cases
- [ ] Tap rapidly through screens — no crash
- [ ] Rotate the device on the home screen, card detail, edit form — layout adapts cleanly
- [ ] Add 100+ cards and scroll — list stays responsive
- [ ] Uninstall and reinstall — the database is gone (this is expected; the data is local-only)

---

## Part 4 — How to Report Issues

Please report bugs with the following details:

1. **Device** — model and Android version (e.g. Pixel 7, Android 14)
2. **Card feature and mode** — e.g. "Scan flow, Code 128 barcode"
3. **Steps to reproduce** — exactly what you tapped and in what order
4. **What happened** — describe the bug
5. **What you expected** — what should have happened
6. **Screenshot or screen recording** if possible
7. **Whether the device is in airplane mode** — relevant for the OCR and any network-claim checks

Send reports to the developer via the agreed channel (email / WhatsApp / GitHub issue).

---

## Part 5 — Known Limitations in This Build

- **Local-only** — no cloud sync, no account, no cross-device transfer. Use the export / import flow to move data between devices.
- **Read-only NFC** — Card Box reads contactless card identifiers but does not emulate cards (no HCE).
- **No Drive / iCloud integration** — exports are file-based; you choose where to back them up.
- **Expiry reminders** — deferred to a later release (see the v-model open question DR-013).
- **OCR languages** — the on-device text recognition pack includes English, Chinese, Devanagari, Japanese, and Korean; other scripts will fall back to manual entry.

---

## Part 6 — Promoting to Production

Before moving from closed testing to production, confirm:

- [ ] No CRITICAL or HIGH bugs reported by testers
- [ ] All core flows complete without crashing (add, edit, delete, scan, sort, export, import)
- [ ] Lock & security: PIN, biometric, lock-on-resume, and erase-all-data all behave as documented
- [ ] Privacy policy URL is live and accessible
- [ ] Data safety form is submitted (matches [`docs/data-safety.html`](../docs/data-safety.html))
- [ ] Play Console — all required sections complete:
  - [ ] Store listing (text + all images uploaded)
  - [ ] Privacy policy URL set
  - [ ] Content rating questionnaire submitted
  - [ ] Target audience set (All ages / Families)
  - [ ] Data safety form submitted
  - [ ] App category set (**Productivity** — recommended; alternative is Games → Card)
  - [ ] Contact details filled in
