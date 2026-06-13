> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# CI/CD

The pipeline doc. Describes
[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) and
the local 3-gate. The "paste output" contract.

---

## 1. The 3 gates (local + CI)

Every PR must pass, in order, with zero failures:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

**Expected output for each.**

- `dart format --output=none --set-exit-if-changed .` —
  exits 0 with no output. If any file would be reformatted,
  it prints the file path and exits 1.
- `flutter analyze --fatal-infos` — exits 0 with
  "No issues found!" If there are issues, it prints file:line
  and the message; `--fatal-infos` makes info-level lints
  fail the build.
- `flutter test` — exits 0 with "All tests passed!" If any
  test fails, it prints the failing test and the assertion
  that failed.

**The paste-output contract.** Every PR description and every
"task done" message must paste the output of all three
commands. "Looks done" is not done. If a gate cannot run
(e.g. no Flutter SDK), say so explicitly and explain why.

**Why these three?**

- `dart format` enforces the formatting that the team
  agreed to. No bike-shedding in code review.
- `flutter analyze --fatal-infos` enforces the 18 lints +
  type safety. Info-level lints are the early warning that
  become errors if ignored.
- `flutter test` is the regression contract. Every bug
  caught before merge is a bug not caught in production.

---

## 2. Local workflow

```bash
# 1. Edit a file.
# 2. Format.
dart format .

# 3. Verify.
( \
  dart format --output=none --set-exit-if-changed . && \
  flutter analyze --fatal-infos && \
  flutter test \
)

# 4. Commit.
git add <files>
git commit -m "feat(scope): description"
```

The format step (`dart format .`) is auto-fix. The verify
step is `dart format --output=none --set-exit-if-changed .`,
which exits non-zero if anything would be reformatted.

For coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# open coverage/html/index.html
```

---

## 3. CI workflow (`.github/workflows/ci.yml`)

The pipeline is 6 jobs. Concurrency: cancel-in-progress on
the same branch.

| Job | Runner | Trigger | What it does |
|---|---|---|---|
| `quality` | ubuntu-latest | push, PR | Runs the 3-gate, uploads coverage to Codecov. |
| `build-debug` | ubuntu-latest | push, PR | `flutter build apk --debug`. Sanity check that the project compiles for Android. |
| `build-android-release` | ubuntu-latest | push to `main` | `flutter build appbundle --release`. Needs `ANDROID_KEYSTORE_*` secrets. |
| `build-web` | ubuntu-latest | push, PR | `flutter build web --release --base-href /BoardBox/`. |
| `deploy-pages` | ubuntu-latest | push to `main` (after `build-web`) | Deploys the web build to GitHub Pages. |
| `build-ios` | macos-latest | push, PR | `flutter build ios --no-codesign`. Sanity check; no signing. |

**`quality`** is the gate. The other jobs are smoke checks
that the project builds for each target.

---

## 4. Caching

- `~/.pub-cache` — keyed by `pubspec.lock` hash. Use
  `actions/cache@v4`.
- `~/.gradle` — keyed by `android/gradle/wrapper/gradle-
  wrapper.properties` and `android/build.gradle`. Speeds up
  Android builds from ~5min to ~1min.
- `~/Library/Developer/Xcode/DerivedData` — iOS, on
  `macos-latest` runners. Keyed by the iOS podfile lock.
- `build/` — Flutter's own build cache. Cleared on the
  runner per job.

The cache `key` includes the lock file; a `pubspec.lock`
change busts the cache.

---

## 5. Runner matrix

- **Linux (ubuntu-latest).** Unit + widget tests, Android
  debug, Android release, web, Pages deploy.
- **macOS (macos-latest).** iOS build, no codesign. Golden
  tests (we don't have golden tests in CI today; if we
  add them, run on macOS for the consistent font metrics).
- **Self-hosted Mac.** For codesigned iOS builds. Not used
  today; would be needed for App Store distribution.

---

## 6. Coverage upload

The `quality` job runs `flutter test --coverage` and uploads
`coverage/lcov.info` to Codecov.

- `fail_ci_if_error: false` — coverage upload failures
  don't fail the build.
- The coverage diff is reported as a PR comment, advisory
  only. PRs that drop coverage on a changed file are
  *flagged* but not blocked.

If we ever want a hard coverage gate (e.g. "merged coverage
must be ≥80% on the diff"), set `fail_ci_if_error: true` and
configure the Codecov `target` and `threshold`.

---

## 7. Secrets

Required GitHub Actions secrets for the release build:

- `ANDROID_KEYSTORE_BASE64` — the `*.jks` file, base64-encoded.
- `ANDROID_KEYSTORE_PASSWORD` — the keystore password.
- `ANDROID_KEY_ALIAS` — the key alias.
- `ANDROID_KEY_PASSWORD` — the key password.

**Never in code, never in `git log`, never in issues/PRs.**
See [`secrets-and-privacy.md`](secrets-and-privacy.md) for the
full rules and the leak-response protocol.

A missing secret fails only the `build-android-release` job.
The other jobs continue; the PR can be merged.

---

## 8. Release process

1. **Bump version** in `pubspec.yaml`. (`version: 1.2.3+45`
   → `version: 1.2.4+46`.)
2. **Update `CHANGELOG.md`.** What changed, who tested,
   what to look for.
3. **Tag.** `git tag v1.2.4`.
4. **Push the tag.** `git push origin v1.2.4`.
5. **The `build-android-release` job runs** on `main` (and
   on the tag). The AAB is uploaded as a workflow artifact.
6. **Manual step.** Upload the AAB to the Play Store
   console. (We don't have automatic Play Store deploys
   today; this is the human step.)

iOS follows the same flow but with TestFlight instead of
the Play Store. macOS-only, requires the
`build-ios-codesign` job (future).

---

## 9. Optional tooling

Alternatives to GitHub Actions for Flutter CI:

- **Codemagic.** Flutter-first. macOS + Linux runners. Free
  tier for open source. See
  [blog.codemagic.io](https://blog.codemagic.io/getting-started-with-codemagic/).
- **Bitrise.** Mobile-first. Flutter template. Free tier.
- **fastlane.** Local + CI. `fastlane match` for code
  signing. See [docs.flutter.dev/deployment/cd](https://docs.flutter.dev/deployment/cd).
- **GitLab CI.** Self-hosted. `.gitlab-ci.yml` with
  `flutter:` Docker image.

For Board Box today, GitHub Actions is the right answer
(we're already on GitHub, the runner matrix is fine, and
the cost is zero for a public repo).

---

## See also

- [`secrets-and-privacy.md`](secrets-and-privacy.md) — full
  secrets policy and leak response.
- [`../AGENTS.md`](../../AGENTS.md) §"The 3-gate" — the
  portable version of this section.
- [`../CLAUDE.md`](../../CLAUDE.md) §"Pre-approved commands"
  — the commands an AI can run without asking.
