> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 08 — AI Assistant Guide

How a human should prompt an AI, and what the AI should do when
the user prompt is ambiguous. The guardrails beyond what fits in
`AGENTS.md`.

---

## 1. Pre-prompt checklist for humans

Before prompting an AI, provide:

- [ ] **File path(s).** Full absolute or repo-relative paths.
  Not "the home screen" — `lib/screens/home_screen.dart`.
- [ ] **Goal.** One sentence. "Make the stats card show a
  dimmed placeholder while loading."
- [ ] **Constraints.** What's allowed, what isn't. "Don't
  change the API of `GameStats`. Don't add a dependency. Don't
  touch `klondike_setup_screen.dart`."
- [ ] **What "done" looks like.** Acceptance criteria. "The
  card shows 'Loading…' on first render, then the actual win
  count once `GameStats` returns."
- [ ] **What NOT to do.** Anti-patterns. "Don't use
  `FutureBuilder`; it caches across tests."

If any of these is missing, the AI will guess. The AI's guess
is not your intent.

For rationale, see Anthropic's prompt engineering docs:
[docs.anthropic.com/en/docs/build-with-claude/prompt-engineering](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering).

---

## 2. Anti-patterns in human prompts

- **"Fix it."** No file, no goal, no constraint. The AI will
  read random files and change random things.
- **"Improve this."** No definition of "improve." Could be
  performance, readability, a11y, security — pick one.
- **"Make it better."** Same problem. The AI will guess.
- **"Add tests."** For what? Which file? What edge cases? The
  AI will write a test for `1+1` and call it done.
- **"Refactor."** What's the target state? What's in scope?
  The AI will rename things and move them around.

A good prompt:

> "In `lib/screens/home_screen.dart`, the `_RecordSummary` widget
> reads `widget.stats` synchronously and shows a `0` for a
> frame. Change it to render a dimmed placeholder while the
> async read is in progress. Use the `StatefulWidget + initState
> + Future` pattern, not `FutureBuilder`. Don't change
> `GameStats` itself. Add a widget test that verifies the
> placeholder is shown for the first frame and the count is
> shown after."

That has: file, goal, constraint, "done", and "not to do."

---

## 3. AI do-list

When working in this repo, the AI:

1. **Reads `AGENTS.md` first.** Portable project rules.
2. **Reads the project's `CLAUDE.md`** (Claude Code-specific
   layer) next.
3. **Reads the path-scoped rule** in `.claude/rules/<path>.md`
   for the area it's touching. Claude Code auto-loads these.
4. **Reads the relevant `docs/` file** for the topic
   (architecture, design system, testing, etc.). See
   [`../CLAUDE.md`](../CLAUDE.md) §"Pointer to docs/".
5. **Plans before code** for any non-trivial change. Plan mode
   in Claude Code, or an explicit numbered plan in the chat.
6. **Runs the 3-gate** after every change.
7. **Pastes the 3-gate output** in the completion message.
8. **Follows the conventions** in `analysis_options.yaml` (the
   18 lints).
9. **Writes tests first** for new behavior (TDD).
10. **Asks before destroying data** (force-push, `rm -rf`,
    `git reset --hard`).

---

## 4. AI don't-list

The AI never:

- **Commits secrets.** API keys, tokens, passwords,
  keystores, `ANDROID_*`, `*.jks`, `*.der`, `key.properties`.
- **Force-pushes** to a shared branch (`main`, `develop`,
  any branch with teammates).
- **Rewrites history** on shared branches.
- **Adds dependencies** without flagging it in the PR
  description.
- **Skips the gate.** "I ran the tests, they look fine" is
  not a gate. The 3 commands must be pasted.
- **Claims "done"** without pasted gate output.
- **Adds AI co-author footers** (`Co-Authored-By: Claude
  ...`).
- **Adds "Generated with Claude Code" trailers** to commits
  or PR bodies.
- **Modifies `android/key.properties`**, `*.jks`, `*.der`,
  or any `ANDROID_*` GitHub Secret.
- **Touches files in `.claude/` other than `AGENTS.md` /
  `CLAUDE.md` / `rules/`.** Skills, hooks, and local settings
  are personal.

---

## 5. Hard enforcement vs prose

Some "never do X" rules can be enforced by the harness, others
must be prose.

**Hard-enforced (the harness stops you):**

- `analysis_options.yaml` — the 18 lints. The model.
  Cannot ship a PR with a lint error.
- `unawaited_futures` — the analyzer errors on a bare
  unawaited `Future`. The GameStats async-gate is the reason
  this lint is loud.
- `always_use_package_imports` — relative `../` imports are
  rejected.
- `use_key_in_widget_constructors` — stateful widgets without
  a `super.key` are rejected.
- `PreToolUse` hooks in `settings.json` — can block `git
  push --force`, `rm -rf` outside `build/` and `.dart_tool/`,
  etc.
- `permissions.deny` in `settings.json` — blacklists commands
  entirely.

**Prose-only (the AI has to read and follow):**

- Don't add dependencies without asking. (No lint catches this.)
- Plan before code for non-trivial changes. (The analyzer
  can't tell.)
- Don't refactor working code in the same PR as a fix. (The
  diff is the same.)
- Don't mutate state, don't add hard-coded colors, don't
  reach for `Theme.of(context)` in a model. (Lint catches the
  Flutter import, but not the design choice.)

**Rule of thumb.** If a rule can be encoded as a lint or a
hook, do that. If it can't, write it in the relevant `docs/`
file and link to it from `AGENTS.md` and `CLAUDE.md`.

---

## 6. Path-scoped rules (Claude Code's mechanism)

Claude Code loads `.claude/rules/<path>.md` **automatically**
when you open a file matching `<path>`. This is per the
[Claude Code memory guide](https://code.claude.com/docs/en/memory).
The 4 files we ship:

- `.claude/rules/lib-games.md` — `lib/games/`. Model purity,
  two-file pattern, when to extract `*_ai.dart`.
- `.claude/rules/lib-screens.md` — `lib/screens/`. `StatefulWidget`
  for async, dimmed placeholders, 48dp targets.
- `.claude/rules/lib-services.md` — `lib/services/`. Singleton
  + `_ready` gate, no Flutter imports.
- `.claude/rules/test.md` — `test/`. Coverage, `runAsync`
  patterns, no skipped tests.

**The AI does not need to "remember to read" these.** Claude
Code injects them into context automatically when the AI
opens a file in the matching path.

---

## 7. Subagent dispatch

For multi-step work, dispatch subagents in this order:

- **Investigate (read-only):** `code-explorer` or `Explore`
  for "find every place that calls X" or "map the
  architecture."
- **Plan:** `planner` or `Plan` for multi-file features and
  refactors.
- **Implement:** `flutter-expert` (Flutter patterns) or
  `code-architect` (cross-language design).
- **Test:** `tdd-guide` (write-tests-first) or the
  `flutter-test` skill (run the suite).
- **Review:** `code-reviewer` (general), `flutter-reviewer`
  (Flutter), `security-reviewer` (auth / PII / input
  validation).
- **Debug:** `debugger` for test failures, `build-error-resolver`
  for `dart analyze` / `flutter build` failures.

**Subagent output is not a substitute for the 3-gate.** After
the subagents return, the AI runs the 3-gate itself and pastes
the output.

---

## 8. When to ask the user

The AI asks the user (with `AskUserQuestion` for one-of-N, or
plain text for open-ended) when:

- **Destructive action.** `rm -rf`, `git reset --hard`,
  force-push, branch delete on shared branches.
- **Ambiguous intent.** The prompt has multiple valid
  interpretations and the choice is the user's.
- **Multiple valid approaches.** Two designs both work; the
  user's preference matters.
- **Security-sensitive code.** Auth, signing, secrets, PII.
- **Dependency changes.** Adding or upgrading a dep changes
  the supply chain.
- **Plan mode exit.** When the plan is ready, the AI uses
  `ExitPlanMode` (or its CLI equivalent) to request approval.

The AI does **not** ask when the answer is conventional
(formatting, lint fixes, following an approved plan, etc.).
The 3-gate output is the answer, not a question.

---

## 9. Memory hygiene

The AI's per-project memory at
`~/.claude/projects/.../memory/` is for things the AI should
remember across sessions:

- **User preferences.** "User prefers `unawaited` over
  explicit `await null`." "User does not want AI co-author
  footers."
- **Non-obvious project facts.** "The 3-gate is mandatory."
  "GameStats has an async gate."
- **Feedback the user has given.** "Don't use FutureBuilder;
  it caches across tests." "The 6-in-a-row gomoku test
  catches `count == 5` regressions."

The AI does **not** save:

- Code structure (lives in the repo).
- Past fixes (lives in `git log`).
- File paths (the AI can re-discover).
- Lint rules (live in `analysis_options.yaml`).

For repo-wide conventions that should apply across sessions
and across AI tools, edit the relevant `AGENTS.md` / `docs/`
file in the repo, not memory.

---

## 10. Common AI mistakes in this repo

Top 5 with file paths and the "this is wrong because":

1. **Importing `package:flutter/material.dart` in a model.**
   File: `lib/games/<name>/<name>_model.dart`. Wrong because
   the model-purity rule is verified by
   `grep -l "import 'package:flutter/" lib/games/*/[a-z]*_model.dart`
   — this would print the file.
2. **Returning a `Future<int>` without awaiting it.** File:
   `lib/services/game_stats.dart` (after the async-gate
   change, commit 43). Wrong because the `unawaited_futures`
   lint errors at compile time.
3. **Using `Theme.of(context)` in a model.** Same reason as
   #1 — the import is the symptom, the design choice is the
   disease.
4. **Calling `setState` in `build`.** File: any
   `*_board.dart`. Wrong because it schedules a re-build that
   re-calls `setState` — infinite loop.
5. **Using `pumpAndSettle` after a drag in a widget test.**
   File: `test/<game>_widget_test.dart`. Wrong because scroll
   physics never settle — the test times out after 10
   minutes. Use `pump()` + `pump(duration)`.

---

## See also

- [`../CLAUDE.md`](../CLAUDE.md) — the Claude Code-specific
  operational layer.
- [`../AGENTS.md`](../AGENTS.md) — the portable project rules.
- [`.claude/rules/`](../../.claude/rules/) — the path-scoped
  rules.
