> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Bug-Hunt Process

The "how we audit a working app" playbook. Directly applies the
lessons from the Minesweeper audit (12 findings) and the
6-commit Round 2 follow-on.

---

## 1. The funnel

```
Audit (multi-perspective review)
  ↓
Triage (severity + repro + fix scope)
  ↓
Fix in commits (one finding per commit, regression test first)
  ↓
Ship (PR + CHANGELOG)
```

The funnel collapses left-to-right as scope shrinks. A small
audit might produce 1 finding that ships in 1 commit. A large
audit (Minesweeper had 12) produces a triage doc and a
sequence of PRs.

---

## 2. Adversarial mindset

The reviewer reviews to **break**, not to confirm.

> Assume every state transition is a race.
> Assume every async call is a leak.
> Assume every input is malicious.
> Assume every boundary check is missing.

This is the mindset that finds the bugs. Cite OWASP Mobile Top
10 ([owasp.org/www-project-mobile-top-10/](https://owasp.org/www-project-mobile-top-10/))
for the security lens.

The opposite mindset — "I read it, it looks right" — is what
ships the race condition that doesn't show up in unit tests
but crashes the app on a 4G connection.

---

## 3. Multi-perspective reviews

Every audit runs **6 lenses** in parallel. For each, the
reviewer asks 3-5 questions.

### Correctness

- Does this match the spec / game rules?
- What happens on the first move, last move, no-move,
  invalid-move?
- What happens at the boundary (timer at 0:00, board full,
  all flags placed)?
- Are invariants (no-mutation, no-leak, no-double-count)
  preserved across state transitions?
- **Worked example.** Minesweeper "first-tap safe" — the
  minefield is generated on the first reveal, with the
  tapped cell + 8 neighbors guaranteed mine-free. The
  audit found the original implementation generated the
  field *before* the tap, allowing a "tap to lose" if the
  user started on a mine.

### Performance

- Any `setState` in `build`? (Infinite loop.)
- Any `Opacity` widget? (Forces off-screen compositing.)
- Any `ListView` without `itemExtent` for fixed-size items?
- Any image without `cacheWidth` / `cacheHeight`?
- Any deep widget tree (`Container` inside `Padding` inside
  `Container`)?
- **Worked example.** The tictactoe AI was cloning the board
  on every move (a deep copy of an N×N grid). The fix was
  to expose non-mutating move enumeration on the model
  (commit 22) and have the AI use the original reference
  (commit `b2b09a7`).

### Security

- Any `print(user.email)` or `print(token)`?
- Any hard-coded secret, even "for the demo"?
- Any `exec(userInput)` or `eval(userInput)`?
- Any `SharedPreferences` key that holds PII?
- **Worked example.** Board Box has no auth today, but the
  audit must scan for future features: if a future PR adds
  login, the audit catches the unencrypted `prefs.setString(
  'token', ...)` early.

### Accessibility (a11y)

- Any `IconButton` without a `tooltip`?
- Any interactive widget without a `Semantics(label: ...)`?
- Any touch target <48dp?
- Any color-only signaling (red dot = mine)?
- **Worked example.** Klondike's drag handles had no spoken
  hint. The fix wrapped every drag handle in a `Semantics`
  with a label like "Drag the seven of hearts to a red
  four" (commit 19).

### UX

- Are all 4 states (empty / loading / error / success)
  present on every list?
- Is the primary action above the fold?
- Is the back button always visible (or is the system back
  gesture sufficient)?
- Is the empty state helpful (action + reason) or just
  blank?
- **Worked example.** The home screen showed a "0" for a
  frame on first render (because stats were loaded
  async). The fix added a dimmed placeholder
  (commit `b71bd0a` and the commits around it).

### i18n

- Any hard-coded string in a widget?
- Any `EdgeInsets.fromLTRB` (not `EdgeInsetsDirectional` —
  breaks in RTL)?
- Any plural that doesn't use the CLDR `plural` rule
  ("1 win" / "2 wins")?
- **Worked example.** We don't have a non-English locale
  today, but the audit scans for these so we're ready.

---

## 4. Severity ladder

| Level | Meaning | Action |
|---|---|---|
| **CRITICAL** | Data loss, security, crash on launch, or hours to fix. | **Block.** Must fix before merge. |
| **HIGH** | Major feature broken, no workaround, current sprint. | **Warn.** Should fix before merge. |
| **MEDIUM** | Workaround exists, next sprint. | **Note.** File an issue, fix in a follow-up. |
| **LOW** | Cosmetic, backlog. | **Note.** File an issue, fix when convenient. |

The same severity ladder applies to PR review
([`../design/07-pr-review-checklist.md`](../design/07-pr-review-checklist.md))
and to the audit.

Cite the table from the
[code-review checklist](../design/07-pr-review-checklist.md)
§"Approval criteria".

---

## 5. Repro template

Every bug report uses this template. (Adopted from CVE-style
reporting — see [cve.org](https://www.cve.org/).)

```markdown
# Bug: <one-line title>

## Environment
- Device: <Pixel 7, iPhone 14, web Chrome 122>
- OS: <Android 14, iOS 17, web>
- App version: <1.2.3+45>
- Build: <debug, release>

## Preconditions
- <What state was the app in?>
- <What data was loaded?>
- <What settings were on?>

## Steps to reproduce
1. <Step 1>
2. <Step 2>
3. <Step 3>

## Expected
<What should happen>

## Actual
<What actually happens>

## Frequency
<Always / sometimes / once>

## Logs
<paste logs or screenshots>

## Severity
<CRITICAL / HIGH / MEDIUM / LOW, with rationale>

## Proposed fix
<Optional. If you have an idea, write it.>
```

**Worked example.** From the Minesweeper audit:

> # Bug: Tapping a mine is possible on the first move.
>
> ## Environment
> Pixel 7, Android 14, app 1.2.0+42, debug build.
>
> ## Preconditions
> Fresh install. No saved games.
>
> ## Steps to reproduce
> 1. Open Minesweeper, choose Beginner.
> 2. Tap the center cell of the 9×9 grid.
> 3. If the center cell is a mine, the game ends immediately.
>
> ## Expected
> First tap is always safe (per game invariants; see
> `AGENTS.md`).
>
> ## Actual
> The first tap can be a mine.
>
> ## Frequency
> ~1/9 chance per first tap.
>
> ## Severity
> HIGH — violates the documented game invariant.
>
> ## Proposed fix
> Generate the minefield on the first reveal, with the
> tapped cell + 8 neighbors guaranteed mine-free. The model
> is the right place; the screen calls `reveal` first, then
> the model generates the field if it hasn't yet.

---

## 6. Triage flow

1. **Confirm.** A second person reproduces the bug. If
   unreproducible, downgrade severity and add a
   `@Tags(['flaky'])` if it's intermittent.
2. **Triage.** Severity + fix scope. Which commit? Which
   file? Which test?
3. **Fix.** Root cause, not symptom. The fix should be
   smaller than the bug (a one-line off-by-one is a
   one-line fix).
4. **Regress-test.** A test that fails on `main` and passes
   on the fix. The test must be in the same PR.
5. **Ship.** PR + CHANGELOG + a re-run of the audit if
   the fix is HIGH or CRITICAL.

---

## 7. Bundling rules

Bundle only when "revert one requires reverting all."
Otherwise, split.

**Rule of thumb.** If the commits share a code path, bundle.
If they share a test, don't bundle — the test can cover
both.

**Worked example.** The Round 2 bug-hunt for the
"GameStats reads return `Future<int>`" audit produced 6
commits (38, 39, 40, 41, 43 — 42 was a false positive).
Each addressed a separate finding:

- 38: dependency upgrade + gitignore
- 39: home screen pre-render dimmed placeholders
- 40: refactor stats to return `Future<int>` from getters
- 41: surface async stats via stateful `_RecordSummary`
- 43: block reads and writes until `GameStats.init()`
  completes

Each is independently revertable. Each has its own
regression test. Each is one logical change.

The Minesweeper audit's 5 defects were committed in commits
9 + 33-37. Same pattern: one finding per commit, one
regression test per commit.

---

## 8. Audit cadence

- **Major.** Before each release (Play Store, TestFlight).
  1-2 days of multi-perspective review. All 6 lenses.
- **Minor.** After each game ships. Half a day. Correctness
  + a11y + perf only.
- **Opportunistic.** When adding a new subsystem (a new
  service, a new screen type, a new game). One day. The
  lens that matches the subsystem.

For Board Box today, the cadence is opportunistic + a
quarterly major audit. We don't have release cycles tight
enough to demand a major audit before every release.

---

## 9. The audit agents

Use these agents (in Claude Code) for the audit:

- **`Explore`** — read-only fan-out search. Good for "find
  every place that calls `SharedPreferences.setInt`" or
  "find every stateful widget without a key."
- **`code-reviewer`** — general code quality. The
  "correctness" + "performance" lens.
- **`code-explorer`** — read-only research. The "map the
  current architecture" agent.
- **`security-reviewer`** — auth, PII, input validation. The
  "security" lens.
- **`accessibility-expert`** — a11y audit. The "a11y" lens.

**Order of dispatch.**

1. **`Explore`** in parallel to map the area. One agent per
   lens if the area is large.
2. **`code-reviewer`** + **`security-reviewer`** in parallel
   on the mapped area.
3. **`accessibility-expert`** for any user-facing surface.
4. **Adversarial verify.** Spawn 2-3 skeptical reviewers
   on each finding. Default to refuted if uncertain.
5. **Synthesize.** A single finding list, severity-scored.

The output of the audit is a doc: `audits/<date>-<scope>.md`
in the repo, with the severity-scored finding list and the
proposed fix commits. The doc is the input to the next
phase.

---

## 10. When to skip the audit

- **Single-line docs change.** A typo, a broken link, a
  wording fix. No code touched.
- **Dependency bump without behavior change.** `flutter
  pub upgrade` of a patch version. The audit is the
  changelog review.
- **Format-only.** `dart format .` on an unformatted file.
  No semantics change.
- **Generated code.** The build's output, not hand-written.

For everything else, run the audit (or at least the
correctness + a11y lens).

---

## See also

- [`../design/07-pr-review-checklist.md`](../design/07-pr-review-checklist.md)
  — the PR reviewer's checklist; same severity ladder.
- [`testing-strategy.md`](testing-strategy.md) §"Regression
  test policy" — the test that lands with the fix.
- [`ci-cd.md`](ci-cd.md) — the CI pipeline that catches
  regressions before they ship.
