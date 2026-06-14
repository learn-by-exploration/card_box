# Card Box — Release Process

How Card Box ships. Read this end-to-end the first time; thereafter it is
a checklist.

---

## 1. Pre-flight (first release only)

The 5 in-repo commits (sections §A–§E below) and the 4 user-side steps
(§F–§I) together take Card Box from "compiles on `main`" to "ready in
the Play Console for the first closed-testing build."

### A. Signing infra
The `android/app/build.gradle.kts` reads `key.properties` and the CI
decodes a base64 keystore from the `ANDROID_*` secrets. Both pieces
must be in place before the release job can produce a signed AAB.

### B. Policy + data-safety HTML
`docs/privacy-policy.html` and `docs/data-safety.html` are served from
GitHub Pages and pasted into the Play Console.

### C. CI change
The `build-web` job fails loud if either policy HTML is missing.

### D. Store assets
`store_assets/STORE_LISTING.md` and `store_assets/CLOSED_TESTING.md`
hold the copy and the tester brief.

### E. Process docs
This file, [`docs/screenshot-capture.md`](screenshot-capture.md), and
`tools/generate-keystore.sh` make the next release repeatable.

### F. Generate the keystore + add 4 GitHub Secrets
1. Pull the latest `main`.
2. `bash tools/generate-keystore.sh` (the script is in this repo).
3. Move `android/upload-keystore.jks` to a long-term backup
   (1Password / sealed envelope / offline USB). **Losing it means
   losing the ability to publish updates to the same Play Store
   listing.**
4. Open `android/keystore-details.txt` and paste each value into
   GitHub → Settings → Secrets and variables → Actions:
   - `ANDROID_KEYSTORE_BASE64` (the long base64 string, one line)
   - `ANDROID_KEY_ALIAS` = `upload`
   - `ANDROID_KEY_PASSWORD` (the password you typed)
   - `ANDROID_STORE_PASSWORD` (the same password)
5. Delete `keystore-details.txt` from the machine.
6. Verify by pushing a small commit to `main` and watching the
   `build-android-release` job log into the "Decode keystore" step
   successfully.

### G. Capture screenshots + create the Play Console listing
1. Capture screenshots per [`docs/screenshot-capture.md`](screenshot-capture.md).
   Drop the resulting PNGs in `store_assets/` with the filenames in
   that doc. Commit and push.
2. Drop a 2048×2048 RGBA `app_icon.png` at the repo root. Run
   `dart run flutter_launcher_icons` to regenerate the mipmaps.
   Resize to 512×512 and place in `store_assets/icon_512.png` (Pillow
   one-liner in `STORE_LISTING.md`).
3. Create a 1024×500 feature graphic and place at
   `store_assets/feature_graphic_1024x500.png`.
4. Go to [play.google.com/console](https://play.google.com/console),
   create a new app, and fill in:
   - App name: **Card Box**
   - Category: **Productivity** (recommended) or Games → Card
   - Default language: English (United States)
   - Free, no in-app purchases
   - Short description, full description, promo text — paste from
     `store_assets/STORE_LISTING.md`
   - App icon → upload `icon_512.png`
   - Feature graphic → upload `feature_graphic_1024x500.png`
   - Phone screenshots → upload the 5 in the order listed
   - Tablet screenshots → upload the 7-inch and 10-inch pairs
   - Privacy policy URL:
     `https://learn-by-exploration.github.io/CardBox/privacy-policy.html`
   - Data safety form → use the pre-filled table in
     [`docs/data-safety.html`](data-safety.html)
   - Content rating → submit the IARC questionnaire; all answers
     in `store_assets/STORE_LISTING.md` §"Content Rating & Policy Answers"
   - Target audience: All ages including children;
     Families-policy declaration = yes
   - Support URL:
     `https://github.com/learn-by-exploration/CardBox/issues`
   - Contact email: the user's real email

### H. First closed-testing release
1. Download the AAB from the `build-android-release` Actions artifact.
2. Go to **Testing → Closed testing → Create new release**. Upload
   the AAB. Add testers (email list or Google Group). Share the
   opt-in URL.
3. Hand the opt-in URL to testers along with
   `store_assets/CLOSED_TESTING.md` as the test brief.

### I. Promote to production
1. Work the testers through `store_assets/CLOSED_TESTING.md` Part 3.
2. When testers report green, run through
   `store_assets/CLOSED_TESTING.md` Part 6 (production pre-flight).
3. In Play Console → Testing → Closed testing → Promote release →
   Production.

---

## 2. Cutting subsequent releases

For releases 1.0.1+, the keystore and Play Console listing already
exist. The work each release is:

1. Bump `version` in `pubspec.yaml` (e.g. `1.0.0+1` → `1.0.1+2`).
2. Add a "## [X.Y.Z] — YYYY-MM-DD" block at the top of
   `CHANGELOG.md` summarising the changes. Keep the existing
   stabilisation block below as "## [Unreleased]".
3. Commit: `chore(release): prepare vX.Y.Z`.
4. Push to `main`. The `build-android-release` job produces a new
   signed AAB.
5. Download the AAB from the Actions artifact.
6. In Play Console → Testing → Closed testing → Create new
   release. Upload the new AAB. Or, if you have already promoted
   to Production, go straight to Production → Create new release.
7. Add release notes (a copy-paste of the CHANGELOG block is fine).

---

## 3. CI surface area

| Job | Trigger | Required secrets |
|-----|---------|------------------|
| `quality` | every push | none |
| `build-debug` | every push | none |
| `build-android-release` | every push | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD` |
| `build-web` | push to `main` | none |
| `deploy-pages` | after `build-web` on `main` | `GITHUB_TOKEN` (built-in) |
| `build-ios` | every push | none (compile-check only; no signing certs) |

The `build-android-release` job will fail until the four `ANDROID_*`
secrets are set; that is the expected state on a fresh clone.

---

## See also
- `store_assets/STORE_LISTING.md` — full Play Console copy.
- `store_assets/CLOSED_TESTING.md` — tester brief and pre-flight.
- [`docs/screenshot-capture.md`](screenshot-capture.md) — capture workflow.
- [`docs/privacy-policy.html`](privacy-policy.html) and
  [`docs/data-safety.html`](data-safety.html) — the policy pages.
- [`docs/engineering/secrets-and-privacy.md`](engineering/secrets-and-privacy.md) — secrets policy and the leak response.
- [`docs/engineering/ci-cd.md`](engineering/ci-cd.md) — CI/CD design.
