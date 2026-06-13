> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Secrets & Privacy

Single source of truth for "where do secrets live, what can
never be logged, how to handle a leak."

---

## 1. The banned list

The following are **banned in code, banned in `git log`, banned
in issues/PRs**:

- `key.properties` (Android signing config)
- `*.jks` (Java keystore)
- `*.der` (raw key)
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- Anything matching `*API_KEY*`, `*TOKEN*`, `*SECRET*`
  (case-insensitive)
- `google-services.json` (Firebase / Play Services)
- `keystore.p12` (iOS)
- `*.p8`, `*.p12`, `*.cer` (Apple signing)
- App Store Connect API keys
- Play Store service account JSON

If you find any of the above in the diff, **block the PR**,
rotate the secret, scrub the diff, and follow the leak
response in §6.

---

## 2. Secret storage

| Where | What | Who |
|---|---|---|
| **GitHub Actions secrets** (repo-level) | The 4 `ANDROID_*` values for the release build. | CI only. |
| **GitHub Actions secrets** (org-level) | Shared secrets (Codecov token, future service tokens). | CI only. |
| **Local `~/.gradle/gradle.properties`** | The 4 `ANDROID_*` values for local Android release builds. | Each developer, on their own machine. |
| **`android/key.properties`** (gitignored) | The same 4 values, for the local Android Gradle build. | Each developer, on their own machine. |
| **`macOS Keychain`** | The 4 values for local iOS builds. | Each macOS developer, on their own machine. |

**Never:**

- Commit a secret to the repo, even in a "test" or "demo"
  branch.
- Add a secret to `.env` and commit the `.env` (`.env.example`
  is OK; the actual `.env` is gitignored but might be
  committed by accident).
- Email a secret, paste a secret in Slack, screenshot a
  secret in a PR description.
- Use the same secret for production and CI; CI secrets can
  leak in workflow logs.

---

## 3. Pre-commit check

Before every commit, run:

```bash
# Show the diff.
git diff --staged

# Grep for the banned list.
git diff --staged | grep -iE "(key\.properties|\.jks|\.der|api[_-]?key|token|secret|password)" | grep -v "analysis_options.yaml"
```

If that prints anything, fix the diff. The grep is naive —
it'll flag words like "token" in unrelated context. Review
each match.

A more robust approach is a `pre-commit` hook that runs the
same check automatically. We don't ship one in the repo
today; the manual check is the contract.

Reference: a robust `pre-commit` hook pattern is in
[`.git/hooks/pre-commit`](../../.git/hooks/pre-commit) (if
we add one in a future commit).

---

## 4. Logging policy

- **`debugPrint` behind `kDebugMode`.** The convention; the
  `avoid_print` lint enforces no plain `print()`.

  ```dart
  if (kDebugMode) {
    debugPrint('user logged in: ${user.id}'); // no PII
  }
  ```

- **Never log user input.** No `debugPrint(email)`,
  no `debugPrint(searchQuery)`. The user input might be
  malicious (log injection) or PII.
- **Never log PII.** No email, no name, no location, no
  device ID, no IP address.
- **Never log auth tokens.** No `debugPrint(token)` — even
  truncated. A truncated token is still a token.
- **Production logs go to Crashlytics / Sentry / etc., with
  PII stripped at the boundary.** We don't ship a crash
  reporter today; if we add one, the boundary is the rule.

---

## 5. Telemetry / analytics

**Board Box has no analytics today.** The app is local-only
and we don't ship a crash reporter.

If we add analytics (e.g. Firebase, Sentry, Mixpanel) in
the future:

- **Opt-in.** Never opt-out-by-default. The user must
  explicitly opt in.
- **Privacy-respecting.** No PII, no device fingerprinting,
  no third-party trackers.
- **Minimal.** The events you ship should be the events you
  need. "Game started" is fine; "Game started, with user
  email and current location" is not.
- **Configurable in settings.** The user can disable
  telemetry at any time, and the disable takes effect on
  the next app launch (no retroactive deletion unless the
  privacy policy requires it).
- **Documented in the privacy policy.** The privacy policy
  lists what we collect, why, and how to opt out.

---

## 6. Leak response

If a secret leaks (committed, pasted in Slack, screenshotted,
exfiltrated), follow the 5-step protocol.

1. **STOP.** No more commits, no more deploys, no more
   "let me just fix this real quick."
2. **Rotate.** The secret is compromised. Generate a new
   one. Do this *before* the cleanup, so even if the
   compromised secret is still in the wild, the new one
   supersedes it.
3. **Audit.** Find every place the secret was used. CI
   workflow runs, manual deploys, third-party services.
   Update them all to the new secret.
4. **Scrub.** Remove the secret from `git log` (use `git
   filter-repo` or BFG). For GitHub, contact support to
   purge cached views. For Slack, delete the message and
   ask an admin to confirm the deletion.
5. **Notify.** Tell the team. Tell the security@ alias.
   If the leak involves user data, follow the applicable
   regulation (GDPR, CCPA, etc.) for breach notification.

The order matters. Rotating first means the leak window is
closed even if the cleanup is slow.

---

## 7. Privacy policy & data safety

- **`docs/privacy-policy.html`** is the human-facing
  privacy policy, served from the web build. Update it
  with every feature change that affects data.
- **`docs/data-safety.html`** is the Google Play
  data-safety form, served from the web build. Update
  with every feature change that affects data.
- The Android `android/app/src/main/AndroidManifest.xml`
  declares the permissions the app uses. Keep it minimal.

Today, the app:

- Stores local data in `SharedPreferences` (game stats,
  settings).
- Has no network access (no INTERNET permission).
- Has no analytics, no crash reporting, no third-party
  SDKs.

If a future feature changes any of the above, update the
privacy policy + the data safety form + this doc + the
manifest.

---

## See also

- [`../AGENTS.md`](../../AGENTS.md) §"Out of scope" — the
  list of files you should not modify (and should report
  instead).
- [`ci-cd.md`](ci-cd.md) §"Secrets" — the CI-side secret
  storage.
- [Bug-hunt process](bug-hunt-process.md) — the security
  lens of the audit.
