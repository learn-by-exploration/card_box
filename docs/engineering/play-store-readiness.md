# Play Store Readiness

A guideline for the **next** Flutter app in `common_games`. Apply
this *at app creation* so the Play Store path is a non-event, not
a 5-commit retroactive stabilisation. Borrowed from the work that
landed `board_box` and `card_box` on Google Play.

---

## 1. The premise

A Flutter app that wants to ship to Google Play needs 11 things
that the Flutter `create` template does not provide. If you do not
plan them at the start, you will retrofit them later — and
retrofitting is how secrets leak, signing breaks, and the
`android/` directory accumulates things you do not understand.

This doc has three parts:

- **§2 Pre-flight checklist** — the 20-item list to copy into your
  new app's first commit.
- **§3 The 5-commit sequence** — the order in which to land
  pieces if you are retrofitting an existing app.
- **§4 What you must NEVER do** — the 6 anti-patterns that
  `board_box` shipped with and `card_box` had to actively avoid.

Read §4 first. The pre-flight checklist and the 5-commit plan
exist *because* of those anti-patterns.

---

## 2. Pre-flight checklist (apply at app creation)

Copy this list into the new app's `docs/STORE_PREFLIGHT.md` and
tick each item before the first release tag. Items are grouped
by repo area; the order within a group does not matter, but the
groups themselves are ordered by "how painful to retrofit."

### A. Project identity

- [ ] `pubspec.yaml` — `name:` is a single lower-case word
      (`card_box`, not `Card Box` or `card-box`).
- [ ] `pubspec.yaml` — `description:` is one sentence that
      describes what the app *does*, not what it is "for."
- [ ] `android/app/build.gradle.kts` — `namespace` and
      `applicationId` are set (e.g. `com.cardbox.card_box`). Do
      not ship with `com.example.*`.
- [ ] `android/app/build.gradle.kts` — `minSdk` is set
      explicitly (24 is the safe floor as of 2026; lower SDKs
      cost you on Play's compatibility score).
- [ ] `android/app/build.gradle.kts` — `targetSdk` is the
      current Play requirement (35 as of 2026; Play rejects
      apps below the current target).
- [ ] `android/app/src/main/AndroidManifest.xml` —
      `android:label` is the user-facing app name. No version
      numbers, no "Beta."
- [ ] Repo is public or has a published source-mirror (Play's
      "Privacy policy" and "Data safety" forms ask for one).
- [ ] The 3 user-side assets that the developer provides
      exist on disk (or have a placeholder note in
      `store_assets/`):
  - [ ] `app_icon.png` — 2048×2048 RGBA PNG.
  - [ ] `feature_graphic.png` — 1024×500 PNG/JPEG.
  - [ ] Screenshots — at least 2 phone screenshots, taken
        on a real device.

### B. Signing infra

- [ ] `android/key.properties.example` exists. The 4 keys
      (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`)
      use `YOUR_*` placeholders, not real values.
- [ ] `android/.gitignore` contains `key.properties`,
      `**/*.keystore`, `**/*.jks`. (If absent, add them.)
- [ ] `android/app/build.gradle.kts` reads `key.properties`
      and emits a `signingConfigs.release` block. Falls
      through to the debug signing config when no
      `key.properties` is present.
- [ ] `android/app/build.gradle.kts` enables
      `isMinifyEnabled = true`, `isShrinkResources = true`,
      and `proguardFiles(...)` on the release build type.
- [ ] `android/app/proguard-rules.pro` exists. Keep rules for
      the app package, the Flutter embedding, the
      `GeneratedPluginRegistrant`, and every plugin that uses
      reflection (e.g. `flutter_secure_storage`, `sqflite`,
      ML Kit, mobile_scanner, nfc_manager).
- [ ] `android/app/build.gradle.kts` sets
      `lint.checkReleaseBuilds = true`. False means Play's
      static analysis gets weaker over time.
- [ ] `tools/generate-keystore.sh` exists and is `chmod +x`.
      It must: refuse to overwrite an existing keystore,
      prompt for a single password (≥6 chars, with
      confirmation), use a 10 000-day validity, write the
      four `ANDROID_*` values into a `keystore-details.txt`
      with `chmod 600`, and never print the keystore or the
      password to stdout.

### C. Adaptive launcher icon (API 26+)

- [ ] `android/app/src/main/res/values/colors.xml` exists,
      with `<color name="ic_launcher_background">` set.
- [ ] `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
      exists, with `background`, `foreground` (16% inset),
      and `monochrome` references.
- [ ] `android/app/src/main/res/drawable/ic_launcher_foreground.png`
      exists. (`flutter_launcher_icons` regenerates this
      from `app_icon.png` via the `flutter_launcher_icons`
      config in `pubspec.yaml`.)

### D. Privacy & data safety

- [ ] `docs/privacy-policy.html` exists. Sections cover:
      data collected, internet access (be honest about which
      permissions the app holds), advertising, third-party
      SDKs, COPPA, GDPR, Families Policy, data security,
      data retention, changes, contact.
- [ ] `docs/data-safety.html` exists. Has the 4 tables
      Play's Data Safety form mirrors: collection summary,
      sharing, security practices, and a "suggested answers"
      table for the Data Safety form itself.
- [ ] Both files are served from a public URL (GitHub Pages
      is the convention; the path mirrors the repo name,
      e.g. `/CardBox/privacy-policy.html`).
- [ ] `docs/engineering/secrets-and-privacy.md` (or its
      successor in the new repo) lists `key.properties` and
      `*.jks` in its banned-list.

### E. Store assets

- [ ] `store_assets/` directory exists, even if empty at
      first commit.
- [ ] `store_assets/STORE_LISTING.md` is templated with:
      app name, promo text, short description, full
      description, links (privacy, data-safety, GitHub,
      support, contact email), image upload checklist,
      content rating answers.
- [ ] `store_assets/CLOSED_TESTING.md` is templated with:
      developer setup, tester opt-in flow, what-to-test
      matrix, bug report format, known limitations,
      production pre-flight.

### F. Process docs

- [ ] `docs/release-process.md` exists. Covers: pre-flight
      (this checklist), cutting subsequent releases (the
      7-step pubspec → CHANGELOG → commit → push → download
      AAB → upload → notes flow), CI surface area (table
      of jobs and required secrets).
- [ ] `docs/screenshot-capture.md` exists. Covers: device &
      environment, capture order, quality bar, the `adb`
      command, and the post-capture commit.
- [ ] `CHANGELOG.md` has a `## [1.0.0] — YYYY-MM-DD` block at
      the top. The block lists the 5 commit-1..commit-5
      sequence and points the reader at `docs/release-process.md`
      for user-side steps.

### G. CI

- [ ] `.github/workflows/ci.yml` has 6 jobs: `quality`,
      `build-debug`, `build-android-release`,
      `build-web`, `deploy-pages`, `build-ios`.
- [ ] `build-web` copies `docs/privacy-policy.html` and
      `docs/data-safety.html` into `build/web/` **without**
      an `if [ -f ]` guard. The guard is a silent-failure
      hazard: if a future PR removes the policy file, the
      Pages build goes green anyway and the Play Store
      link is dead.
- [ ] `build-android-release` validates the four
      `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEY_ALIAS` /
      `ANDROID_KEY_PASSWORD` / `ANDROID_STORE_PASSWORD`
      secrets, then decodes the keystore, then writes
      `android/key.properties`. The job should fail on a
      fresh clone (no secrets) — that is the expected
      state, not a regression.
- [ ] `android/key.properties` is in `android/.gitignore`.
      The CI creates it on every run from the secrets.

### H. The .gitignore matrix

- [ ] Root `.gitignore` excludes `*.jks`, `**/*.jks`,
      `*.keystore`, `**/*.keystore`, `*.der`, `**/*.der`,
      `*.pem`, `**/*.pem`, `*.p12`, `**/*.p12`, the user's
      local `key.properties`, the build outputs.
- [ ] `android/.gitignore` re-states the most critical
      entries (defence-in-depth, in case the root
      `.gitignore` ever drifts).
- [ ] `keystore-details.txt` is in `android/.gitignore`
      (the keystore script writes it next to the keystore
      itself; it must never be tracked).

---

## 3. The 5-commit sequence (for retrofitting an existing app)

If the app already exists without the above, land these commits
in order. Each commit is independently shippable; do not bundle
them.

### Commit 1 — Signing infra
**Touches:** `android/app/build.gradle.kts` (signing block,
minify, shrink, ProGuard, `targetSdk`, lint), the four
`android/app/proguard-rules.pro` /
`android/app/src/main/res/values/colors.xml` /
`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
files (new), and `android/key.properties.example` (new).
**Risk:** zero. The release job still fails until secrets
land; `build-debug` and `quality` are unaffected.

### Commit 2 — Policy + data-safety HTML
**Touches:** `docs/privacy-policy.html` and
`docs/data-safety.html` (both new). Must land *before* the
CI change in commit 3, so that the "fail loud" copy step
has files to find.
**Risk:** zero. Static HTML.

### Commit 3 — CI: fail loud on missing static docs
**Touches:** `.github/workflows/ci.yml` — drop the
`if [ -f ]` guard in the static-docs copy step.
**Risk:** low. Only fails the `build-web` job if a future
PR removes a policy file; that is the desired behaviour.

### Commit 4 — `store_assets/`
**Touches:** `store_assets/STORE_LISTING.md` and
`store_assets/CLOSED_TESTING.md` (both new). Independent
of commits 1–3.
**Risk:** zero. Markdown.

### Commit 5 — Process docs + decision reversal
**Touches:** `tools/generate-keystore.sh` (new, `chmod +x`),
`docs/release-process.md` (new), `docs/screenshot-capture.md`
(new), `docs/v_model/open_questions.md` (reverse any "store
prep is out of scope" resolution), `CHANGELOG.md` (prepend
a `[1.0.0]` block).
**Risk:** zero. No Dart code changes; the 3-gate is a no-op
on this commit.

### Then — the user-side steps (not in the repo)

Step A: Run `bash tools/generate-keystore.sh` on a secure
machine, paste the four `ANDROID_*` values into GitHub
Secrets, back up `upload-keystore.jks`.

Step B: Capture screenshots per
[`docs/screenshot-capture.md`](../screenshot-capture.md),
drop them in `store_assets/`, generate the 512×512 icon
and the 1024×500 feature graphic.

Step C: Fill in the Play Console listing from
`store_assets/STORE_LISTING.md` and submit the IARC and
Data Safety forms.

Step D: Download the signed AAB from the
`build-android-release` Actions artifact, upload to Testing
→ Closed testing, share the opt-in URL with testers,
promote to Production after
`store_assets/CLOSED_TESTING.md` Part 6 passes.

---

## 4. What you must NEVER do

Six anti-patterns. Each one is a real failure mode from the
`board_box` codebase.

1. **NEVER commit `android/key.properties` with real
   passwords.** The `.gitignore` exists for a reason. If you
   see it in a diff, block the PR and rotate the password
   immediately — a leaked `storePassword` lets an attacker
   sign updates that Play will accept for the listing.

2. **NEVER commit `android/upload-keystore.jks`** (or any
   `*.jks`, `*.keystore`, `*.der`, `*.pem`, `*.p12` file).
   The keystore is the *identity* of your Play Store listing.
   Losing it means losing the listing; leaking it means an
   attacker can publish updates.

3. **NEVER add an `if [ -f ]` guard around a required static
   doc in the CI.** It is the silent-failure hazard. If a
   required file is missing, the build must fail loud.

4. **NEVER use a relative `storeFile` path that depends on
   which directory the build was run from.** The CI writes
   `storeFile=../upload-keystore.jks` (relative to `android/`)
   because the keystore is decoded to
   `android/upload-keystore.jks`. The local dev workflow
   reads `android/key.properties` from inside `android/`,
   so it must point at the same path. Pick one convention
   and document it in `key.properties.example`.

5. **NEVER promise an `INTERNET` permission the app does not
   hold.** `board_box`'s privacy policy says "the `INTERNET`
   permission is declared but currently unused." That is
   true for `board_box` (it declares the permission). If a
   *new* app does not declare `INTERNET`, the policy must
   say so honestly — Play's reviewers, security scanners,
   and security-conscious users will check.

6. **NEVER use the debug signing config for a release AAB
   uploaded to Play.** It works once, but Play's key-pinning
   means the *first* upload locks you in. There is no
   upgrade path from a debug-signed listing to a
   release-signed listing; you have to publish under a new
   package name and migrate users. The signing config block
   in `android/app/build.gradle.kts` exists to make the
   release signing path the default, not the exception.

---

## 5. Verification

Before tagging the first release, the cumulative diff must
pass:

```bash
# 1. Format
dart format --output=none --set-exit-if-changed lib test
# 2. Analyze
flutter analyze --fatal-infos
# 3. Test
flutter test
# 4. Secrets must not be in git
git ls-files | grep -E '(^|/)(key\.properties$|\.jks$|\.der$|\.p12$|\.keystore$|\.pem$|keystore-details\.txt$)' \
  | grep -v 'key\.properties\.example$'
#    Expected: empty
# 5. The CI's static-docs copy step has no guard
grep -n "if \[ -f" .github/workflows/ci.yml
#    Expected: empty
```

If any of §2, §3, §4, or §5 is incomplete, **stop** and finish
the gap before tagging the first release.

---

## 6. See also

- [`docs/release-process.md`](../release-process.md) — the
  per-app runbook that operationalises this guideline.
- [`docs/screenshot-capture.md`](../screenshot-capture.md) —
  the screenshot capture workflow.
- [`docs/engineering/secrets-and-privacy.md`](secrets-and-privacy.md) —
  the secrets policy and the leak response.
- [`docs/engineering/ci-cd.md`](ci-cd.md) — the CI design and
  the 3-gate contract.
- [`docs/privacy-policy.html`](../privacy-policy.html) and
  [`docs/data-safety.html`](../data-safety.html) — the two
  static policy files that the `build-web` job copies into
  `build/web/`.
- `store_assets/STORE_LISTING.md` and
  `store_assets/CLOSED_TESTING.md` — the store listing copy
  and the closed-testing tester brief.
