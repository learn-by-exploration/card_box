> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Per-PR Code Review Checklist

The reviewer's checklist. Bridges
[`../design/07-pr-review-checklist.md`](../design/07-pr-review-checklist.md)
(which is the design / UX / a11y / security angle) — this doc
adds the code-quality focus.

For severity definitions, see
[`bug-hunt-process.md`](bug-hunt-process.md) §"Severity ladder".

---

## 1. Pre-flight

Before reading code:

- [ ] **PR description.** What changed, why, how it was verified
  (3-gate output pasted).
- [ ] **Linked issue.** Every PR links to an issue or a
  one-paragraph rationale.
- [ ] **3-gate output.** `dart format --output=none --set-exit-
  if-changed .`, `flutter analyze --fatal-infos`, `flutter
  test` — all in the PR description, all clean.
- [ ] **PR is <300 LOC Dart, <5 files, one logical change.**
  If not, request decomposition before reading code.
- [ ] **No `Co-Authored-By:` footer.** The project's
  `AGENTS.md` §"Commit & branch" bans them.

If any of the above is missing, request changes before reading
code.

---

## 2. Architecture

- [ ] **Feature-folder respected.** New code is in the right
  `lib/games/<name>/`, `lib/screens/<feature>/`,
  `lib/services/`, `lib/models/` folder.
- [ ] **Model purity.** `*_model.dart` has no Flutter imports.
  Verifiable:
  `grep "import 'package:flutter/" lib/games/<name>/<name>_model.dart`
  returns nothing.
- [ ] **Service pattern.** A new service is a singleton with
  `Completer<void> _ready`; public reads/writes `await
  _ready.future`. See
  [`../design/02-architecture.md`](../design/02-architecture.md)
  §"Service pattern".
- [ ] **State pattern.** Sealed `*State` classes, not bare
  enums.
- [ ] **No god-widgets.** A widget that builds a whole screen
  is a smell.
- [ ] **Layer boundaries.** No back-edges (a model never
  imports a widget; a widget never imports `data` directly).

---

## 3. Code quality

- [ ] **Readable.** Names are descriptive; comments are
  present where the code is non-obvious; the comment density
  matches the surrounding code.
- [ ] **Functions <50 lines.** A function that fits on one
  screen is a function you can review in one pass.
- [ ] **Files <800 lines.** A file that's longer than the
  editor viewport is a file that hides complexity. Split.
- [ ] **No deep nesting (>4 levels).** Use early returns or
  extract a helper. See
  [`flutter-dart-style.md`](flutter-dart-style.md) §"Common
  pitfalls".
- [ ] **Proper error handling.** No empty `catch`. No
  stringly-typed errors. No silent failures.
- [ ] **No mutation.** Collections are `unmodifiable` or
  rebuilt; state transitions return new instances.
- [ ] **No magic numbers.** Use named constants for
  meaningful thresholds.
- [ ] **No hard-coded values.** Colors → `colorScheme.*`.
  Sizes → spacing tokens. Strings → ARB files.
- [ ] **No `print()`.** `debugPrint` behind `kDebugMode` or
  surface-to-UI.
- [ ] **No unawaited futures.** Every `Future` is `await`ed
  or wrapped in `unawaited(...)`.

---

## 4. Tests

- [ ] **Coverage ≥80% on changed files.** Not the whole repo;
  the diff. `flutter test --coverage` → `genhtml coverage/
  lcov.info -o coverage/html`.
- [ ] **AAA structure.** Arrange / Act / Assert.
- [ ] **Round-trip test for model changes.** If the model has
  `toJson` / `fromJson`, the round-trip is tested.
- [ ] **Widget test for new screens.** `pumpWidget`, `tap`,
  `pump`, verify the rendered tree.
- [ ] **Regression test for bug fixes.** The test fails on
  `main` before the fix and passes after.
- [ ] **No skipped tests.** `skip:` requires an issue link.
  `@Tags(['flaky'])` requires an issue link and a fix-within-
  one-sprint promise.
- [ ] **Async tests use `tester.runAsync` for real `Future`s.**
- [ ] **No `pumpAndSettle` after a drag.** Scroll physics
  loops forever; use `pump()` + `pump(duration)`.
- [ ] **Test names describe behavior.** "returns empty array
  when no markets match query" not "test 1".

---

## 5. Performance

- [ ] **No `setState` in `build`.** A `setState` during build
  schedules another build, which schedules another
  `setState` — infinite loop.
- [ ] **No `Opacity` widget.** Use `AnimatedOpacity` or
  `Visibility`. `Opacity` forces off-screen compositing.
- [ ] **Large images have `cacheWidth` / `cacheHeight`.**
  Decoded at the displayed size, not the source size.
- [ ] **`ListView` with `itemExtent` if fixed-size.** Tells
  the framework the size up front; skips a layout pass.
- [ ] **No deep widget trees.** `Container` containing
  `Padding` containing `Container` containing `Column` is a
  smell.
- [ ] **No `BuildContext` across async gaps.** After an
  `await`, check `mounted` before using `context`.

---

## 6. Security

- [ ] **No secrets.** No API keys, no `ANDROID_*`, no
  `key.properties`, no `*.jks`, no `*.der`. Pre-commit grep
  should be the last line of defense.
- [ ] **No PII in logs.** No `debugPrint(user.email)`, no
  `print(token)`. Wrap in `kDebugMode` guards.
- [ ] **Input validation.** All user input is validated at
  the boundary. No string-concatenated SQL, no
  `exec(userInput)`.
- [ ] **OWASP Mobile Top 10 mental scan.** See
  [`../design/07-pr-review-checklist.md`](../design/07-pr-review-checklist.md)
  §"Security review".

---

## 7. A11y

- [ ] **48dp / 44pt touch targets.** Every tap target is
  ≥48dp on Android, ≥44pt on iOS.
- [ ] **4.5:1 contrast.** All text. WebAIM Contrast Checker
  on the `colorScheme.onX` / `colorScheme.X` pair.
- [ ] **Focus visible.** Logical focus order, visible focus
  ring.
- [ ] **TalkBack / VoiceOver labels.** Every interactive
  widget has a `Semantics(label: ...)`. Every `IconButton`
  has a `tooltip`.
- [ ] **`prefers-reduced-motion` respected.** Animations
  collapse when the system asks.
- [ ] **200% text scaling.** Layouts don't break at 200%
  text size.

---

## 8. i18n

- [ ] **No hard-coded strings** in widgets. Every visible
  string is in the ARB files.
- [ ] **RTL-safe.** `EdgeInsetsDirectional` not
  `EdgeInsets.fromLTRB`.
- [ ] **Plural-aware.** ICU `plural` rule, not string
  interpolation.

---

## 9. Acceptance criteria

- [ ] **Every AC demonstrably met.** The PR description maps
  each AC to the code that satisfies it (file:line) or the
  test that verifies it (`test/file_test.dart:test name`).
- [ ] **Screenshots for UI ACs.** A picture for each visible
  state in the AC.

---

## 10. Approval

| Verdict | Criteria |
|---|---|
| **Approve** | No CRITICAL or HIGH issues. The PR is ready to merge. |
| **Warn (request changes, but acceptable to override)** | Only HIGH issues that the author can fix in a follow-up. The author must explicitly call out the override. |
| **Block** | Any CRITICAL issue, any security finding, any secret in the diff, any regression test missing for a bug fix, any AC not met. |

**Never approve a PR with a secret in the diff.** Even if the
secret is "test-only" or "for the demo." Rotate the secret,
drop it from the diff, and update the PR.

**Never approve a PR that doesn't have the 3-gate output
pasted.** "Looks fine" is not done. The 3-gate is the contract.

---

## See also

- [`../design/07-pr-review-checklist.md`](../design/07-pr-review-checklist.md)
  — the design / UX / a11y / security-focused checklist.
- [`flutter-dart-style.md`](flutter-dart-style.md) — the
  rationale for each lint.
- [`testing-strategy.md`](testing-strategy.md) — the test
  patterns and the regression policy.
- [`bug-hunt-process.md`](bug-hunt-process.md) — the
  severity ladder and the audit process.
