> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 07 — PR Review Checklist

What a reviewer must check before approving a PR. Bridges
[`../engineering/code-review-checklist.md`](../engineering/code-review-checklist.md)
(which is the per-PR code-quality checklist) — this doc adds
the design / UX / a11y / security angle.

For severity definitions, see
[`../engineering/bug-hunt-process.md`](../engineering/bug-hunt-process.md)
§"Severity ladder".

---

## 1. Required pre-flight

Before reading code, the reviewer verifies:

- [ ] **PR description.** What changed, why, how it was verified
  (3-gate output pasted).
- [ ] **Linked issue.** Every PR links to an issue or a
  one-paragraph rationale.
- [ ] **3-gate output.** `dart format --output=none --set-exit-
  if-changed .`, `flutter analyze --fatal-infos`, `flutter
  test` — all in the PR description, all clean.
- [ ] **Screenshots / recordings for UI.** Before/after for any
  visible change. Both light and dark mode.
- [ ] **PR is <300 LOC Dart, <5 files, one logical change.**
  If not, the author decomposes.

If any of the above is missing, request changes before reading
code.

---

## 2. Code review

- [ ] **Architecture rules respected.** Model purity (no
  Flutter imports in `*_model.dart`), service pattern
  (`_ready` gate), state pattern (sealed `*State`).
  See [`02-architecture.md`](02-architecture.md).
- [ ] **No god-widgets.** A screen is a `StatefulWidget`; a
  widget builds a piece of UI. A widget that builds the
  whole screen is a smell — split.
- [ ] **Immutable updates.** State transitions return new
  model instances. No `this.field = value` in a `move()`
  method.
- [ ] **Error handling.** No empty `catch`. No stringly-typed
  errors. No silent failures.
- [ ] **No hardcoded values.** Colors → `colorScheme.*`. Sizes
  → spacing tokens. Strings → ARB files.
- [ ] **No mutation.** Collections are `unmodifiable` or rebuilt
  with `..add()` on a copy. See
  [`../engineering/flutter-dart-style.md`](../engineering/flutter-dart-style.md)
  §"Collections".
- [ ] **No `print()`.** `debugPrint` behind `kDebugMode` or a
  surface-to-UI pattern.
- [ ] **No unawaited futures.** Every `Future` is `await`ed or
  wrapped in `unawaited(...)`.
- [ ] **No relative imports.** `package:common_games/...`
  only. `always_use_package_imports` lint catches this.
- [ ] **Keys on stateful widgets.** `super.key` in the
  constructor; `use_key_in_widget_constructors` catches this.
- [ ] **Lint clean.** `flutter analyze --fatal-infos` is in
  the PR description. If it's not, request changes.

---

## 3. Test review

- [ ] **Coverage ≥80% on changed files.** Not the whole repo;
  the diff. `flutter test --coverage` → `genhtml coverage/
  lcov.info -o coverage/html`.
- [ ] **AAA structure.** Arrange / Act / Assert, one assertion
  per `expect` (where possible).
- [ ] **Round-trip test for model changes.** If the model has
  a `toJson` / `fromJson`, the round-trip is tested.
- [ ] **Widget test for new screens.** `pumpWidget`, `tap`,
  `pump`, verify the rendered tree.
- [ ] **Regression test for bug fixes.** The test fails on
  `main` before the fix and passes after.
- [ ] **No skipped tests.** `skip:` requires an issue link.
  `@Tags(['flaky'])` requires an issue link and a fix-within-
  one-sprint promise.
- [ ] **Async tests use `tester.runAsync` for real `Future`s.**
  See [`../engineering/testing-strategy.md`](../engineering/testing-strategy.md)
  §"Async patterns".
- [ ] **No `pumpAndSettle` after a drag.** Scroll physics loops
  forever; use `pump()` + `pump(duration)`.

---

## 4. UI/UX review

- [ ] **48dp / 44pt touch targets.** Every tap target is
  ≥48dp on Android, ≥44pt on iOS.
- [ ] **4.5:1 contrast.** All text. WebAIM Contrast Checker on
  the `colorScheme.onX` / `colorScheme.X` pair.
- [ ] **All 4 states (empty / loading / error / success).** Every
  list and state-driven screen.
- [ ] **Keyboard nav.** Logical focus order, visible focus ring.
- [ ] **TalkBack / VoiceOver labels.** Every interactive widget
  has a `Semantics(label: ...)`. Every `IconButton` has a
  `tooltip`.
- [ ] **RTL-safe.** `EdgeInsetsDirectional` not
  `EdgeInsets.fromLTRB`. Test with a fake RTL locale.
- [ ] **Dark mode.** Manually check both light and dark.
- [ ] **Motion tokens.** Durations are 100/200/300ms. Easing
  is M3 default. `prefers-reduced-motion` respected.
- [ ] **Heuristic 10-point checklist.** (See
  [`04-ui-ux-principles.md`](04-ui-ux-principles.md) §"Heuristic
  evaluation checklist".) All 10 pass.

---

## 5. Security review

Use the `security-reviewer` agent for these:

- [ ] **No secrets.** No API keys, no `ANDROID_*`, no
  `key.properties`, no `*.jks`, no `*.der`. Pre-commit grep
  should be the last line of defense.
- [ ] **No PII in logs.** No `debugPrint(user.email)`, no
  `print(token)`. Wrap in `kDebugMode` guards.
- [ ] **Input validation.** All user input is validated at the
  boundary. No string-concatenated SQL, no `exec(userInput)`.
- [ ] **OWASP Mobile Top 10 mental scan.** Run through the
  top 10 mentally:
  1. M1: Improper credential use — Board Box has no auth, but
     check for future features.
  2. M2: Inadequate supply-chain security — pinned versions
     in `pubspec.lock`, `flutter pub outdated` reviewed
     before upgrade.
  3. M3: Insecure authentication / authorization — N/A
     today.
  4. M4: Insufficient input / output validation — see
     "input validation" above.
  5. M5: Insecure communication — N/A (no network).
  6. M6: Inadequate privacy controls — see
     [`../engineering/secrets-and-privacy.md`](../engineering/secrets-and-privacy.md).
  7. M7: Insufficient binary protections — Android signing
     (see `secrets-and-privacy.md`).
  8. M8: Security misconfiguration — `android/app/src/
     main/AndroidManifest.xml` permissions are minimal.
  9. M9: Insecure data storage — `SharedPreferences` only,
     no plaintext credentials.
  10. M10: Insufficient cryptography — N/A (no cryptography).

---

## 6. A11y review

- [ ] **WCAG 2.2 AA quick scan.**
  - Contrast 4.5:1 text / 3:1 large text / 3:1 UI components.
  - Focus visible.
  - 200% text scaling — layout doesn't break.
  - `prefers-reduced-motion` respected.
- [ ] **Semantics tree.** Run the app in TalkBack / VoiceOver
  and read the screen. Every interactive widget has a label.
- [ ] **Touch target spacing.** 8dp gap between adjacent
  targets.

---

## 7. Performance review

- [ ] **No `setState` in `build`.** A `setState` during build
  schedules another build, which schedules another `setState`
  — infinite loop.
- [ ] **No `Opacity` widget.** Use `AnimatedOpacity` or
  `Visibility`. `Opacity` forces an off-screen compositing
  layer for the whole subtree.
- [ ] **Large images have `cacheWidth` / `cacheHeight`.**
  Decoded at the displayed size, not the source size.
- [ ] **`ListView` with `itemExtent` if fixed-size.** Tells
  the framework the size up front; skips a layout pass.
- [ ] **No deep widget trees.** A `Container` containing a
  `Padding` containing a `Container` containing a `Column`
  is a code smell. Use a `Column` with `mainAxisAlignment`
  and `crossAxisAlignment`.
- [ ] **No `BuildContext` across async gaps.** After an
  `await`, check `mounted` before using `context`.

---

## 8. Acceptance criteria

- [ ] **Every AC demonstrably met.** The PR description maps
  each AC to the code that satisfies it (file:line) or the
  test that verifies it (`test/file_test.dart:test name`).
- [ ] **Screenshots for UI ACs.** A picture for each visible
  state in the AC.

---

## 9. Approval criteria

| Verdict | Criteria |
|---|---|
| **Approve** | No CRITICAL or HIGH issues. The PR is ready to merge. |
| **Warn (request changes, but acceptable to override)** | Only HIGH issues that the author can fix in a follow-up. The author must explicitly call out the override. |
| **Block** | Any CRITICAL issue, any security finding, any secret in the diff, any regression test missing for a bug fix, any AC not met. |

**Never approve a PR with a secret in the diff.** Even if the
secret is "test-only" or "for the demo." Rotate the secret, drop
it from the diff, and update the PR.

**Never approve a PR that doesn't have the 3-gate output
pasted.** "Looks fine" is not done. The 3-gate is the contract.

---

## See also

- [`../engineering/code-review-checklist.md`](../engineering/code-review-checklist.md)
  — the code-quality-focused checklist.
- [`../engineering/bug-hunt-process.md`](../engineering/bug-hunt-process.md)
  — the severity ladder and the audit process.
- [`06-feature-decomposition.md`](06-feature-decomposition.md) —
  the PR-sizing rules this checklist enforces.
