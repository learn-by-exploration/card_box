> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 01 — Design Process

How we design an app, from idea to PR. This is the funnel; the other
docs in this tree drop into the steps that need them.

---

## The funnel

```
Idea
  ↓
PRD (one-pager)
  ↓
Feature Spec (per feature)
  ↓
Architecture Decision (when crossing a layer)
  ↓
Tasks (PR-sized, <300 LOC each)
  ↓
PRs (one logical change per commit)
  ↓
Ship
```

The funnel collapses left-to-right as scope shrinks. Most features
skip the formal PRD and go straight from an issue to a Feature Spec;
most small fixes skip the Feature Spec and ship a single PR. The funnel
is a thinking tool, not a paperwork requirement.

---

## PRD template

Use this when the scope is "could be a new app" or a major new subsystem.
For per-feature work, skip to the Feature Spec.

```markdown
# PRD: <one-line title>

## Problem
What user pain or business need are we addressing? In one paragraph.

## Users
Who is this for? Persona, device, context.

## Goals
What must be true when we're done? 3-5 measurable outcomes.

## Non-goals
What are we explicitly not doing? (Tells reviewers what to ignore.)

## Success metrics
How will we know we succeeded? (Retention, time-to-X, error rate, etc.)

## Open questions
What don't we know yet? List them — they become spikes.

## Worked example: "Add Connect Four to Board Box"
- **Problem.** Board Box has 9 games, none of which are 2-player
  drop-disc. Users who want a 2-player drop game have to leave the app.
- **Users.** Existing Board Box players, parents with kids, casual
  1v1 sessions on a single device.
- **Goals.** Local 2-player Connect Four; 7×6 grid; standard rules
  (gravity, 4-in-a-row wins, draw when full); AI opponent for solo play.
- **Non-goals.** Online multiplayer, animations beyond the drop,
  variable board sizes, tournament mode.
- **Success metrics.** ≥80% of polled users rate it "fun"; AI loses
  to a competent player at >70% rate (sanity check on AI strength).
- **Open questions.** What's the right AI depth for solo? 4-ply
  (good) or 6-ply (overkill for a phone)? 1-pager: skip — go to spec.
```

---

## Feature spec template

Use this for every feature that lands in a release. Smaller fixes can
ship without one if they don't change user-visible behavior.

```markdown
# Feature: <name>

## User stories (INVEST)
- **I**ndependent: doesn't depend on another story's PR
- **N**egotiable: scope can be cut without losing the value
- **V**aluable: user-visible win
- **E**stimable: ≤2 days of solo work
- **S**mall: fits in one PR (≤300 LOC Dart)
- **T**estable: acceptance criteria below are demonstrable

- As a <persona>, I want <goal>, so that <reason>.
- As a <persona>…

## Acceptance criteria (Gherkin)
- Given <precondition>
- When <action>
- Then <expected outcome>

## Out of scope
- …

## Dependencies
- …

## Test plan
- Unit: <file> covers <edge cases>
- Widget: <file> covers <golden path>
- Manual: <device/setting> for <scenario>

## Worked example: "Add per-difficulty win/loss tracking to Minesweeper"
- **User stories.** As a player, I want to see my best time per
  difficulty, so I can challenge myself.
- **Acceptance criteria.** Given I have a saved beginner win,
  when I open the setup screen, then the beginner card shows
  "best: 00:42, wins: 3."
- **Out of scope.** Global leaderboard, online sync, replays.
- **Test plan.** Unit test in `minesweeper_model_test.dart` for
  save/load round-trip; widget test in `minesweeper_widget_test.dart`
  for the card rendering; manual on Android emulator for persistence.
```

---

## Definition of Ready (gate to start)

A feature is ready to implement when:

- [ ] Acceptance criteria are written and reviewed
- [ ] Sized (S/M/L/XL — see Estimation below)
- [ ] Dependencies identified (other features, design assets, etc.)
- [ ] Test plan written
- [ ] Design / UX reviewed (if user-visible)
- [ ] Issue / ticket exists

If any of these is missing, the work is not ready — clarify or split.

---

## Definition of Done (gate to merge)

A feature is done when:

- [ ] Code merged to `main`
- [ ] All 3-gate checks pass (`dart format` / `flutter analyze
      --fatal-infos` / `flutter test`) — output pasted in the PR
- [ ] ≥80% coverage on changed files
- [ ] Regression test added for the bug (if a bugfix)
- [ ] Acceptance criteria demonstrably met (screenshots / recordings
      for UI)
- [ ] PR description follows the template
- [ ] Peer reviewed and approved (per `code-review-checklist.md`)
- [ ] No `print()`, no `Co-Authored-By:` footer, no banned secret

---

## Decomposition methodology

Default to **vertical slices**, not horizontal layers. A vertical slice
is a thin end-to-end path through model + board + screen + tests.
A horizontal layer is "all models first, then all boards, then all
screens" — that doesn't work because the design isn't validated
until the screen ships, and integration bugs hide.

**Sizing rules.** Each PR should be <300 LOC Dart, <5 files, one
logical change. If it's bigger, split.

**Generated code.** `*.g.dart` / `*.freezed.dart` in a separate
commit, marked `[generated]`. (Board Box doesn't use codegen today;
this rule kicks in when we add `freezed` or `json_serializable`.)

**Worked example: how Minesweeper was decomposed** (commits 11-16 in
the actual git history, mapped to a single feature spec):

1. **`minesweeper_model.dart`** — pure-Dart model, save/load, win/loss
   state. No widget. Unit test mirror.
2. **`minesweeper_board.dart`** — the 9×9 grid widget, tap-to-reveal,
   flag toggle. Widget test: tap a safe cell, see number.
3. **`minesweeper_setup_screen.dart`** — difficulty picker,
   per-difficulty best-time display. Widget test: card renders.
4. **`minesweeper_game_screen.dart`** — wires model + board, timer,
   mine counter. Widget test: win flow.
5. **First-tap-safe + cascade reveal** — pure-Dart addition, two
   unit tests (one for each invariant).
6. **A11y pass** — `Semantics` labels on every cell, 48dp targets,
   focus order. Widget test: `Semantics` matcher.

Six PRs, each independently mergeable, each one a vertical slice. The
feature is shippable after PR 4; PRs 5 and 6 are hardening.

---

## Spike vs story vs task vs bug

- **Spike.** Time-boxed investigation. No production code. Output is
  a doc / decision record. Examples: "evaluate Riverpod vs Bloc for
  state management", "benchmark Karuro puzzle load times".
- **Story.** User-visible feature. Has user-story format. Sized
  S/M/L.
- **Task.** Engineering work that's not user-visible. Examples:
  "add a CI job", "refactor model purity lint", "bump shared_preferences".
- **Bug.** Defect in shipped behavior. Has a repro template (see
  `bug-hunt-process.md`). Lands with a regression test.

---

## Estimation

For solo Flutter work, t-shirt sizes map to hours as:

| Size | Hours | What fits |
|------|-------|-----------|
| **S** | 1-3 | One-file fix, a single new widget, format/lint cleanup |
| **M** | 4-8 | One-screen feature, model+board for a simple game, a new service |
| **L** | 1-2 days | Multi-screen feature, game with AI, a new subsystem |
| **XL** | 3+ days | New app, major refactor, anything touching a layer boundary |

**XL is a smell.** If a feature is XL, decompose it (see above) before
starting. The biggest single PR in Board Box's history is the 5-commit
stats fix in commits 38-43.

---

## See also

- [`02-architecture.md`](02-architecture.md) — for the architecture
  rules to reference in the spec.
- [`06-feature-decomposition.md`](06-feature-decomposition.md) — for
  the full PR-splitting playbook.
- [`../engineering/bug-hunt-process.md`](../engineering/bug-hunt-process.md)
  — for the bug template.
