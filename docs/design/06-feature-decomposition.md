> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 06 — Feature Decomposition

The "break a feature into PRs" playbook. Pairs with
[`01-design-process.md`](01-design-process.md) §"Decomposition
methodology"; this doc is the long form with worked examples.

---

## Decomposition checklist

When a feature is too big for a single PR:

- [ ] **Vertical slice first.** Each PR is a thin end-to-end
  path through model + board + screen + tests, not a layer.
- [ ] **Ship the spine, harden the rest.** The first PR ships
  the happy path. Later PRs add error handling, a11y,
  performance, edge cases.
- [ ] **Tests ship with the code.** Every PR includes its
  tests. No "tests in a follow-up" (it never happens).
- [ ] **Generated code is its own commit.** `*.g.dart` /
  `*.freezed.dart` in a separate commit, marked `[generated]`.
  (We don't use codegen today; this rule kicks in when we do.)
- [ ] **Feature flag for risky work.** A new AI algorithm, a
  new game mode, a new platform — wrap in a `kEnableX` flag
  in `SettingsService` and ship behind it. Remove the flag
  in a follow-up commit.

---

## PR sizing rules

| Rule | Limit | Why |
|---|---|---|
| **LOC Dart** | <300 | Above 300, review quality drops sharply. |
| **Files changed** | <5 | More than 5 means you're touching a layer. |
| **Logical changes** | 1 | One PR, one thing. If "and" is in the title, split. |
| **Commits per PR** | 1 (default) | Squash before merge. Multi-commit PRs only for the rare case that each commit is a logical change. |

**If a PR exceeds these limits**, decompose. See the worked
examples below.

---

## Worked example: Minesweeper (commits 11-16 in git history)

A single PRD "Add Minesweeper" became 6 PRs, all merged in
order:

1. **`feat(minesweeper): add pure-Dart model with first-tap-safe minefield generation`**
   - `lib/games/minesweeper/minesweeper_model.dart`
   - `test/minesweeper_model_test.dart` (initial state, reveal,
     flag, win, loss, first-tap-safe, cascade)
   - 250 LOC, 2 files, vertical slice = "the rules work."

2. **`feat(minesweeper): add 9x9 / 16x16 / 16x30 board widget with tap-to-reveal`**
   - `lib/games/minesweeper/minesweeper_board.dart`
   - `test/minesweeper_widget_test.dart` (golden path: tap a
     safe cell, see the number)
   - 220 LOC, 2 files, vertical slice = "the user can play."

3. **`feat(minesweeper): add setup screen with difficulty picker`**
   - `lib/screens/minesweeper/minesweeper_setup_screen.dart`
   - `test/minesweeper_widget_test.dart` extended (the screen
     shows difficulty cards)
   - 180 LOC, 1 file, vertical slice = "the user can start."

4. **`feat(minesweeper): add game screen with timer + mine counter`**
   - `lib/screens/minesweeper/minesweeper_game_screen.dart`
   - `test/minesweeper_widget_test.dart` extended (the screen
     shows timer, mine counter, status)
   - 200 LOC, 1 file, vertical slice = "the user can finish."

5. **`test(minesweeper): cover cascade-induced win`**
   - `test/minesweeper_model_test.dart` (a regression test for
     the cascade revealing the last safe cell)
   - 50 LOC, 1 file, hardening.

6. **`feat(minesweeper): a11y pass — Semantics labels, 48dp targets`**
   - `lib/games/minesweeper/minesweeper_board.dart` (add
     `Semantics` widgets, 48dp wrap)
   - `test/minesweeper_widget_test.dart` extended (`Semantics`
     matcher)
   - 120 LOC, 2 files, hardening.

**Total: 6 PRs, each independently mergeable, each ships a
working slice, total <1000 LOC across all six.** A reviewer can
sign off on PR 1 in 15 minutes. A reviewer signing off on the
whole feature in one go would have given up at PR 3.

---

## Worked example: Stats async-gate (commit 43)

A single audit finding (race condition in `GameStats`) became 1
PR, but the PR was *not* a 5-file mega-change — the changes
were scoped tight:

- `lib/services/game_stats.dart` — `Completer<void> _ready`
  gate, all getters → `Future<int>`, all writers `await`.
- `lib/models/game_mode.dart` — `enum GameType` moved here
  (resolving a circular import with `home_screen.dart`).
- `lib/screens/home_screen.dart` — `_GameRecord.read()` and
  `minesweeperRecordLabel()` now `Future`-returning; UI uses
  `FutureBuilder` / `StatefulWidget + initState`.
- `lib/screens/klondike/klondike_setup_screen.dart` —
  converted to `StatefulWidget` with `_loadWins()` in
  `initState`.
- `lib/screens/minesweeper/minesweeper_setup_screen.dart` —
  `_StatsCard` is now a `StatefulWidget` with `_loadStats()`.
- `lib/screens/klondike/klondike_game_screen.dart` +
  `lib/screens/karuro/karuro_game_screen.dart` — `unawaited(...)`
  wraps the new `Future`-returning record methods.
- 3 test files updated to `await` the new futures.

**12 files, 426 insertions, 122 deletions.** Bigger than the
<300 LOC budget because the change is a fundamental API shift,
not a feature. The PR is still scoped: "all reads and writes
block on `_ready`". Nothing else in the PR.

**Lesson.** When the change is an API shift, the LOC budget is
a guideline, not a rule. The rule that holds is "one logical
change, no scope creep." The PR is reviewable because every
change is part of the same migration.

---

## Worked example: Klondike a11y pass (commit 19)

A single finding ("Klondike cards don't have semantic labels
or 48dp touch targets") became 1 PR:

- `lib/games/klondike/klondike_board.dart` — every `CardView`
  wrapped in `Semantics(label: '...')`; every drag handle
  wrapped in `Material` with a 48dp `InkWell`.
- `test/klondike_widget_test.dart` — `Semantics` matcher
  added; "spoken-form labels" tests for the mine counter and
  timer pills.

**Single PR, 2 files, ~120 LOC.** Hardening, not new feature.
Same review depth as a normal feature PR (read every line),
but the surface area is small enough to review in one sitting.

---

## Anti-patterns

### "All models first" (horizontal slice)

```
PR 1: model for game A
PR 2: model for game B
PR 3: model for game C
PR 4: board for game A
PR 5: board for game B
PR 6: board for game C
PR 7: screen for game A
...
```

**Why this is wrong.** The user can't see anything shippable
until PR 7. Integration bugs hide between layers. If the
design is wrong, you find out in PR 7 after 6 PRs of work.

**Right way:** vertical slice per game. PR 1 ships A end-to-end.
PR 2 ships B end-to-end. Each is independently shippable.

### "Mega-PR"

```
PR: "Add 3 games, refactor the model layer, fix 5 bugs,
upgrade shared_preferences, and update the home screen."
```

**Why this is wrong.** A reviewer can't tell what's a feature
from what's a refactor. Reverting is impossible (the bugfix is
tangled with the upgrade). The CI matrix of "did this break
something" becomes unreviewable.

**Right way:** one PR per logical change. If you have 5 logical
changes, you have 5 PRs. They can land in the same release, but
each is independently reviewable and revertable.

### "Test in a follow-up"

```
PR 1: feat: add Minesweeper.
PR 2: test: add Minesweeper tests.
```

**Why this is wrong.** "Test in a follow-up" never happens. The
follow-up is always pushed to "after the demo." The model is
shipped untested. The next person to touch it breaks an
invariant because there was no regression test.

**Right way:** tests ship in the same PR as the code. If the
PR is too big without tests, it's too big with tests too —
decompose the feature.

---

## See also

- [`01-design-process.md`](01-design-process.md) §"Decomposition
  methodology" — the short form of this doc.
- [`07-pr-review-checklist.md`](07-pr-review-checklist.md) — the
  reviewer's checklist that catches mega-PRs.
