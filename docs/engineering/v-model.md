> **Imported from board_box.** This doc was authored for board_box; the file references and worked-example commits in the body (e.g. KlondikeModel, GameStats, Minesweeper, the b71bd0a / 135eb69..256aa71 commits) are board_box-specific. The *rules* and *patterns* are universal Flutter/Dart practice and apply here. Swap in card_box-local examples (e.g. card_repository, tag_resolver, the project's own v_model/ trace) in follow-up edits — the structure does not need to change.

---

# V-Model Lifecycle

> **The V-Model, adapted for a single-team Flutter app.** The
> textbook V-Model is from systems engineering (aerospace,
> automotive, medical devices). For Board Box we keep the
> *shape* — explicit phases, bidirectional traceability,
> "the test exists because the requirement exists" — and drop
> the certification ceremony (no DO-178, no IEC 62304, no
> independent V&V team). The PR reviewer is the V&V. The
> 3-gate is the verification gate. The PR description is the
> traceability matrix. This doc maps the V to the existing
> Round 3 docs and adds the *gates* and *traceability* that
> those docs don't cover.

---

## 1. The V at a glance

The V has 8 phases: 4 on the left arm (decomposition) and 4
on the right arm (verification), with Operations bridging
the bottom of the V in production. The two arms are mirror
images: every left-arm phase is verified by a right-arm
phase at the same level.

```text
LEFT ARM (decomposition)        RIGHT ARM (verification)

2.1 Requirements                2.7 System / acceptance
  → 01-design-process.md          → 07-pr-review-checklist.md
                                    → 04-ui-ux-principles.md
2.2 System design               2.6 Integration
  → 02-architecture.md            → ci-cd.md
  → 03-design-system.md
2.3 Detailed design             2.5 Unit / widget / golden
  → 05-component-library.md       → testing-strategy.md
  → 02-architecture.md §Game      → .claude/rules/test.md
2.4 Implementation
  → 06-feature-decomposition.md
  → flutter-dart-style.md
  → coding-guidelines.md
            └──── 2.8 Operations ────┘
                → ci-cd.md §"Release"
                ⚠ no observability today (see §8)
```

Each left-arm phase produces an artifact (PRD, architecture
note, model signatures, PR diff). Each right-arm phase
*verifies* the corresponding left-arm phase. The trace is
bidirectional: the verification in phase N can be traced
back to a requirement in phase 2.1, and the requirement in
phase 2.1 can be traced forward to a test in phase N.

### 1.1 Phase → doc map

| Phase | Doc(s) you read | Doc(s) you write |
|---|---|---|
| 2.1 Requirements | [`01-design-process.md`](../design/01-design-process.md) | PRD, feature spec, AC |
| 2.2 System design | [`02-architecture.md`](../design/02-architecture.md), [`03-design-system.md`](../design/03-design-system.md) | Architecture note, ADRs (rare) |
| 2.3 Detailed design | [`05-component-library.md`](../design/05-component-library.md), [`02-architecture.md`](../design/02-architecture.md) §"Game pattern" | Model signatures, widget tree sketch |
| 2.4 Implementation | [`06-feature-decomposition.md`](../design/06-feature-decomposition.md), [`flutter-dart-style.md`](flutter-dart-style.md), [`coding-guidelines.md`](coding-guidelines.md) | PR(s) |
| 2.5 Unit / widget / golden | [`testing-strategy.md`](testing-strategy.md), [`.claude/rules/test.md`](../../.claude/rules/test.md) | Tests in the same PR |
| 2.6 Integration | [`ci-cd.md`](ci-cd.md) | (CI runs the gate) |
| 2.7 System / acceptance | [`07-pr-review-checklist.md`](../design/07-pr-review-checklist.md), [`04-ui-ux-principles.md`](../design/04-ui-ux-principles.md) | PR description, reviewer check |
| 2.8 Operations | [`ci-cd.md`](ci-cd.md) §"Release process" | Release artifact |

---

## 2. The phases, in detail

For each phase: **goal**, **entry criteria (DoR)**, **exit
criteria (DoD)**, **artifacts**, **verification**.

### 2.1 Requirements

- **Goal:** Define what the user gets, in user-facing terms.
  Not "add a method to do X" — "the user can do X."
- **Entry criteria:** a user story, a feature spec, a bug
  report, or a "wouldn't it be nice" idea.
- **Exit criteria:** a PRD or feature spec with acceptance
  criteria (AC), a test plan that names the behaviors to
  verify, and a design review (a human has read the AC and
  agreed each one is demonstrable).
- **Artifacts:** PRD, feature spec, issue with AC.
- **Verification:** the AC items are demonstrable on a
  device. Reviewer reads the AC and confirms each is
  concrete, testable, and in scope.
- **Doc link:** [`01-design-process.md`](../design/01-design-process.md) §"PRD"
  and §"Feature spec".

### 2.2 System design

- **Goal:** Define how the system holds together. Which
  layer does this feature live in? What new service or
  model do we need? What tokens does it touch?
- **Entry criteria:** Requirements phase DoD met.
- **Exit criteria:** the layer boundaries are respected
  (model pure-Dart, service is a singleton, widget reads
  the service via `Future`-returning methods), the data
  flow is sketched (a `*_model.dart` reading
  `GameStats.instance.getXxx()` returning a `Future<int>`),
  and an architecture decision is recorded if it deviates
  from the existing rules.
- **Artifacts:** architecture note (in the PR description
  or a `docs/adr/NNNN-<name>.md` for a big decision).
- **Verification:** the architecture note answers "does this
  respect the model-purity rule / service pattern / token
  system?" with concrete file paths and code shapes.
- **Doc links:** [`02-architecture.md`](../design/02-architecture.md) §"Layer
  boundaries", [`03-design-system.md`](../design/03-design-system.md) §"Tokens".

### 2.3 Detailed design

- **Goal:** Define how each component works. The model
  signatures (`sealed class *State`, the public methods,
  the `toJson` shape), the widget tree (which private
  widgets, which keys, where the `setState` happens), the
  tokens (color, spacing, motion).
- **Entry criteria:** System design DoD met.
- **Exit criteria:** the model has signatures; the widget
  has a tree; the tokens are named; the state transitions
  are named. (You don't write the code yet — you write
  *signatures* and *names*.)
- **Artifacts:** the signatures in the PR description or
  in a sibling design doc.
- **Verification:** a reviewer can read the signatures and
  spot the missing piece (e.g. "where's the save/restore?").
- **Doc links:** [`05-component-library.md`](../design/05-component-library.md)
  (does the widget exist?), [`02-architecture.md`](../design/02-architecture.md) §"Game
  pattern" (the model pattern), [`03-design-system.md`](../design/03-design-system.md) §"Component
  state matrix" (the visual states).

### 2.4 Implementation

- **Goal:** Working code. One logical change per PR.
- **Entry criteria:** Detailed design DoD met. PR-sized
  scope. The PR has a clear title and a draft description.
- **Exit criteria:**
  1. The 3-gate passes
     (`dart format --output=none --set-exit-if-changed .` ·
     `flutter analyze --fatal-infos` · `flutter test`).
  2. The regression test (if a bug) is in the same PR.
  3. The PR description maps each AC item to a file:line
     and a test name (this is the traceability row).
  4. No lint suppressions were added (`ignore:` requires
     a one-line `why:` comment, ideally a `// TODO:` with
     a follow-up issue).
- **Artifacts:** the PR diff.
- **Verification:** the 3-gate output is pasted in the PR
  description. A reviewer reads the diff and the 3-gate
  output and either approves or requests changes.
- **Doc links:** [`06-feature-decomposition.md`](../design/06-feature-decomposition.md)
  (how to break a feature into PRs), [`flutter-dart-style.md`](flutter-dart-style.md)
  (the lints), [`coding-guidelines.md`](coding-guidelines.md)
  (the day-to-day style).

### 2.5 Unit / widget / golden tests

- **Goal:** Every code change is provably correct at the
  smallest scale.
- **Entry criteria:** the unit/widget/golden tests in the
  PR pass locally.
- **Exit criteria:** `flutter test` is green, with ≥80%
  coverage on changed files (per
  [`testing-strategy.md`](testing-strategy.md) §"Coverage").
- **Artifacts:** the test files in `test/`.
- **Verification:** the CI job `test` is green. The
  coverage report is uploaded and reviewed.
- **Doc links:** [`testing-strategy.md`](testing-strategy.md) §"Test
  pyramid", [`.claude/rules/test.md`](../../.claude/rules/test.md)
  (the path-scoped rule for `test/`).

### 2.6 Integration

- **Goal:** The system works as a whole — the build
  produces an installable artifact.
- **Entry criteria:** the 2.5 gate is green.
- **Exit criteria:** the CI pipeline is green: the
  `quality` job, the `build-*` jobs (debug APK, web
  release, optionally iOS), the `deploy-pages` job (for
  web). See [`ci-cd.md`](ci-cd.md) §"CI workflow" for the
  job list.
- **Artifacts:** the CI artifacts (APK, web build, signed
  bundle on tag).
- **Verification:** all green checkmarks on the PR. The
  reviewer can download the APK and confirm it installs.
- **Doc links:** [`ci-cd.md`](ci-cd.md) §"CI workflow" and
  §"Caching".

### 2.7 System / acceptance

- **Goal:** The user-visible feature works on a real
  device, with the real theme, the real haptics, the real
  font scaling.
- **Entry criteria:** the 2.6 gate is green.
- **Exit criteria:**
  1. Manual smoke on an Android debug build
     (`flutter build apk --debug` → sideload to a phone).
  2. Each AC item in the PR description is checked off.
  3. The UI/UX review on the PR passes
     ([`07-pr-review-checklist.md`](../design/07-pr-review-checklist.md) §"UI/UX
     review", [`04-ui-ux-principles.md`](../design/04-ui-ux-principles.md) §"Heuristic
     evaluation").
  4. The accessibility review passes (a11y lint, 48dp
     touch targets, 4.5:1 contrast, semantics labels,
     200% text scaling doesn't break the layout).
- **Artifacts:** the reviewer check, the demo screenshot
  in the PR comment.
- **Verification:** the reviewer approves the PR.
- **Doc links:** [`07-pr-review-checklist.md`](../design/07-pr-review-checklist.md),
  [`04-ui-ux-principles.md`](../design/04-ui-ux-principles.md).

### 2.8 Operations

- **Goal:** The feature runs in production.
- **Entry criteria:** the 2.7 gate is green; the PR is
  merged to `main`.
- **Exit criteria:** the feature is released to the
  distribution channel (GitHub Pages for web, Play Store
  for Android, TestFlight for iOS). The release notes
  mention the feature.
- **Artifacts:** the release artifact (APK, IPA, web
  build), the release notes, the `git tag`.
- **Verification:** the artifact is downloadable from
  the store / Pages URL. The smoke test on the live URL
  passes.
- **Doc links:** [`ci-cd.md`](ci-cd.md) §"Release process".
  **Observability gap (deferred):** see §8 for the
  no-crash-reporting / no-analytics note; until that work
  lands, "verification" is "the artifact is deployed and
  the smoke test passes" — with no field regression
  detection.

---

## 3. The traceability matrix

The PR description is the operational traceability matrix.
Each row is one AC item, with the design element, the code
location, the test, and the verification step.

### 3.1 Shape (one row per AC item)

| AC # | Requirement (from 2.1) | Design element (from 2.3) | Code (from 2.4) | Test (from 2.5) | Verification (from 2.7) |
|---|---|---|---|---|---|
| AC-1 | "User can deal a fresh deck" | `KlondikeModel.deal()` | [`klondike_model.dart:87-112`](../../lib/games/klondike/klondike_model.dart) | `klondike_model_test.dart: <test name>` | PR review + manual deal |
| AC-2 | "First tap on a cell is never a mine" | `MinesweeperModel.reveal()` | [`minesweeper_model.dart`](../../lib/games/minesweeper/minesweeper_model.dart) | `minesweeper_model_test.dart: 'first reveal places the minefield with the tapped cell + 8 neighbors mine-free'` | PR review + manual reveal |
| AC-3 | "Stats persist across cold start" | `GameStats.init()` + `_ready` gate | [`game_stats.dart:36-39`](../../lib/services/game_stats.dart) | `game_stats_test.dart: 'reads suspend until init() completes'` | PR review + manual cold start |

### 3.2 Worked example — GameStats async-gate (commit `b71bd0a`)

> **AC:** "A read of `GameStats.getXxx()` before
> `GameStats.init()` completes must not return `0` silently;
> it must wait for the prefs to load."
>
> **Design:** the `Completer<void> _ready` gate; every
> public read/write `await`s it. The model: singleton +
> init + gate + idempotent init.
>
> **Code:** [`game_stats.dart:24-39`](../../lib/services/game_stats.dart)
> and the per-method `await _ready.future` calls.
>
> **Test:** `test/game_stats_test.dart: 'reads suspend until
> init() completes'` (with a follow-up set of tests in the
> same file that exercise the gate on `getKaruroWins`,
> `getKlondikeWins`, and `getMinesweeperWins`).
>
> **Verification:** PR review by a human + a manual cold-
> start smoke test of the home screen tiles.

### 3.3 Worked example — first-tap-safe Minesweeper (commits `135eb69`–`256aa71`)

This 6-PR decomposition is the reference for the V's
traceability: each PR mapped one slice of the feature to
one or two AC items, and each AC item was traceable back
to a test. The full per-PR table (with the commit, the
AC, the design element, the code, and the test) lives in
[`06-feature-decomposition.md`](../design/06-feature-decomposition.md)
§"Worked example — Minesweeper". The point here is the
*shape*: a 6-PR decomposition produced a 6-row
traceability matrix, and the matrix is what made the
"we covered everything" claim auditable.

---

## 4. The V-phase gates

Each phase has an entry and an exit. The gates are the
*operational* form of the V-Model discipline: you don't
move to phase N+1 until phase N's exit is met. The gates
are simple, verifiable, and cheap to run.

| Phase | Entry (DoR) | Exit (DoD) | The gate you actually run |
|---|---|---|---|
| 2.1 Requirements | A user story or feature spec exists | AC + test plan + design review | "Can a reviewer read the AC and confirm each is demonstrable?" |
| 2.2 System design | AC list is complete | Architecture note + layer-boundary check | `grep -l "import 'package:flutter/" lib/games/*/[a-z]*_model.dart` prints nothing (model purity) |
| 2.3 Detailed design | Architecture note merged | Model signatures + widget tree + tokens named | "Can a reviewer spot the missing piece?" |
| 2.4 Implementation | Signatures + tree + tokens | PR merged, 3-gate green, regression test in the PR | The 3-gate |
| 2.5 Unit / widget / golden | 2.4 merged | `flutter test` green, ≥80% coverage on diff | `flutter test` + `flutter test --coverage` |
| 2.6 Integration | 2.5 green | CI pipeline green (quality + build-*) | The CI check on the PR |
| 2.7 System / acceptance | 2.6 green | Manual smoke + AC check + a11y check + UI/UX check | The PR reviewer's check |
| 2.8 Operations | 2.7 merged | Released to distribution channel | The release artifact exists at the store / Pages URL |

### 4.1 Worked example — merging the implementation PR

Before you click "merge" on the implementation PR for
Minesweeper's first-tap-safe reveal (the
`135eb69`-style PR):

1. **2.4 exit:** the 3-gate is green. The PR description
   pastes the output of all three commands. **This is the
   gate you actually run.** `dart format` is no-op on
   `.md` files; `flutter analyze --fatal-infos` is
   "No issues found!"; `flutter test` is
   "All tests passed!".
2. **2.5 exit:** the new test in
   `minesweeper_model_test.dart` is in the same PR. The
   test name is `'first reveal places the minefield with
   the tapped cell + 8 neighbors mine-free'`. Coverage on
   `minesweeper_model.dart` is ≥80%.
3. **2.6 exit:** the CI check is green. The `build-debug`
   and `build-web` jobs produced artifacts.
4. **2.7 exit:** the PR reviewer read the diff, ran the
   test in their head, and ticked the AC items in the PR
   description.

If any of these fails, the merge is blocked. There is no
"we'll fix it in a follow-up" — the gate is the gate.

---

## 5. What the V-Model is *not*

- **Not waterfall.** The V doesn't forbid iteration
  between adjacent phases. If the detailed design
  uncovers a requirement gap, you go back to 2.1. If
  the implementation PR surfaces a design flaw, you
  update the design doc. The V is a lifecycle, not a
  sequence.
- **Not a sign-off bureaucracy.** The "review" is the PR
  review, not a meeting. We don't have a V&V team, a
  QA lead, or a change-control board. The reviewer is
  the next person to read the code.
- **Not a documentation regime.** We don't write a
  separate requirements document for every feature. The
  feature spec in the PR description is the requirement.
  The model file is the design. The test file is the
  verification. Each artifact lives where it's most
  useful.
- **Not a coverage test.** "100% coverage" is not a
  V-Model goal. The goal is that every requirement has
  a test. Coverage is a *proxy* — high coverage with
  no requirement is still orphan tests (see §6).

---

## 6. Bidirectional verification

The V-Model discipline: **for every test, you can point to
a requirement; for every requirement, you can point to a
test.**

The forward direction (requirement → test) catches *orphan
requirements* — a feature was built but never tested. The
backward direction (test → requirement) catches *orphan
tests* — a test that exists but tests no user-facing
behavior. Both are bugs of attention.

### 6.1 Orphan test (the common case)

```dart
// A unit test with no AC item.
test('internal helper clamps negative values', () {
  expect(MyHelper.clamp(-5), 0);
});
```

This test passes, the coverage report goes up, and the
PR is green. But there is no requirement that the helper
clamp negative values; the test is "testing the
implementation", not "testing the behavior". If the
helper's contract changes (e.g. it now throws on negative
input), the test fails for a reason that has nothing to
do with the user. Bidirectional verification says: if you
can't point to the AC item, delete the test (or write the
AC).

### 6.2 Orphan requirement (the rarer case)

A feature was built, the user can do X, but there's no
test that proves X. The widget test smokes the screen
but doesn't assert X. The PR merges; six months later, a
refactor silently breaks X; nobody notices.

The fix: the test in the PR must name the AC item it's
verifying. `flutter test --name "AC-3: stats persist
across cold start"` is a fine convention. The PR
description maps the AC to the test name.

### 6.3 How to enforce it in Board Box

- The PR template (in the PR description, not a file)
  has a "AC → file:line → test" table.
- The reviewer checks that every row is filled in.
- A test that exists with no AC row is a reviewer
  request to either add the AC row or delete the test.

This is the "100% coverage" anti-goal in another form:
a coverage number doesn't tell you whether the
*behavior* is tested. The AC table does.

---

## 7. Change management

What happens when a requirement changes after
implementation?

1. The AC is updated in the PR description (or the next
   PR's description, if the change is a follow-up).
2. The traceability table is re-walked: which tests fail
   when the requirement changes? Which docs need
   updating?
3. If a test was the *only* reason a piece of code
   existed (orphan test by the new AC), the code is
   deleted.
4. The bug-hunt process
   ([`bug-hunt-process.md`](bug-hunt-process.md)) treats
   a changed requirement as a fresh lens: re-read the
   diff with the new AC in mind and ask "is this
   actually the new behavior, or did the change just
   touch the surface?"
5. The change is reflected in the `CHANGELOG` (we don't
   have one yet — see §"Observability gap" — but the
   PR title is the operational form).

The 2.4 regression-test policy — every bug fix lands
with a failing-then-passing test in the same PR — is
the *operational* form of change management. When the
requirement changes, the test changes; when the
requirement is restored, the test is restored.

---

## 8. Where Board Box deviates from a "textbook" V

Explicit deviations, in one place:

- **No formal requirements-traceability tool.** The
  traceability is the PR description. A custom tool
  would be over-engineering for a single-team app.
- **No independent V&V team.** The PR reviewer is the
  V&V. The "review" is a code review, not a meeting.
- **No certification.** No DO-178 (avionics), no IEC
  62304 (medical devices), no ISO 26262 (automotive).
  The discipline is real; the ceremony is not.
- **No separate test plan document.** The test plan is
  the PR description + the test file names. A test
  plan document would duplicate the test file.
- **Operations is thin.** No observability, no
  production logging, no analytics. This is a known
  gap, flagged in §2.8.
- **Integration test is light.** We have a CI
  pipeline that builds, but no end-to-end test that
  exercises the full system on a real device. The
  manual smoke on Android is the proxy. A future
  follow-up could add `integration_test/` for the
  critical user flows.

Each of these is a *deliberate* trade-off, not an
oversight. If any of them stops making sense — e.g. we
ship to a regulated market that requires IEC 62304 — the
deviations are the first things to revisit.

---

## 9. See also

- [`01-design-process.md`](../design/01-design-process.md)
  — the design funnel; the V's 2.1 and 2.3 are
  elaborations of two steps in this funnel.
- [`02-architecture.md`](../design/02-architecture.md)
  — the model-purity rule, the service pattern, the
  two-file pattern, the state pattern (the V's 2.2 and
  2.3 are anchored in this doc).
- [`03-design-system.md`](../design/03-design-system.md)
  — the tokens the V's 2.3 references.
- [`05-component-library.md`](../design/05-component-library.md)
  — the component catalog the V's 2.3 references.
- [`06-feature-decomposition.md`](../design/06-feature-decomposition.md)
  — the Minesweeper worked example, mapped to the V's
  2.4.
- [`07-pr-review-checklist.md`](../design/07-pr-review-checklist.md)
  — the V's 2.7 reviewer check.
- [`04-ui-ux-principles.md`](../design/04-ui-ux-principles.md)
  — the heuristic evaluation the V's 2.7 references.
- [`testing-strategy.md`](testing-strategy.md) — the V's
  2.5.
- [`ci-cd.md`](ci-cd.md) — the V's 2.6 and 2.8.
- [`bug-hunt-process.md`](bug-hunt-process.md) — the V's
  §7 change management, in operational form.
- [`flutter-dart-style.md`](flutter-dart-style.md) and
  [`coding-guidelines.md`](coding-guidelines.md) — the
  V's 2.4 style anchors.
