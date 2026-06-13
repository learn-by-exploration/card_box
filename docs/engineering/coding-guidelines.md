> **Imported from board_box.** This doc was authored for board_box; the file references and worked-example commits in the body (e.g. KlondikeModel, GameStats, Minesweeper, the b71bd0a / 135eb69..256aa71 commits) are board_box-specific. The *rules* and *patterns* are universal Flutter/Dart practice and apply here. Swap in card_box-local examples (e.g. card_repository, tag_resolver, the project's own v_model/ trace) in follow-up edits — the structure does not need to change.

---

# Coding Guidelines

> **Companion to [`flutter-dart-style.md`](flutter-dart-style.md).** That
> doc is organized by *lint* (one section per lint, with before/after
> pairs) and answers **why** each rule exists. This doc is organized by
> *activity* (the order a human writes code) and answers **how** to apply
> the rules in practice. Read this when you're about to write Dart/Flutter
> in Board Box; reach for the other doc when you're chasing a lint
> message.
>
> **Split into two parts.** The cross-cutting rules every file follows
> (naming, file organization, imports, comments, constants) are in
> this doc. The rules specific to each kind of file (models, services,
> widgets, errors, tests, Dart 3 idioms) are in
> [`coding-guidelines-types.md`](coding-guidelines-types.md). Read this
> doc first; reach for the types doc when you're about to write a
> model, service, widget, or test.

---

## 1. Quick reference card

The first screen of the doc. Paste into your editor if you like.

```text
┌──────────────────────────────────────────────────────────────────────┐
│ BOARD BOX DART/FLUTTER CODING — ONE-PAGE CHEAT SHEET                 │
├──────────────────────────────────────────────────────────────────────┤
│ Files:        snake_case (klondike_setup_screen.dart)                │
│ Types:        PascalCase (KlondikeModel, MinesweeperCell)            │
│ Methods/var:  camelCase (recordWin, elapsedSeconds)                  │
│ Private:      _leadingUnderscore (_ready, _history, _pushHistory)   │
│ Constants:    lowerCamel, no k-prefix (_key, _karuroWinsKey)         │
│ Keys:         ValueKey('klondike_stock') — snake_case string         │
│ Model files:  PURE DART, no flutter/ imports. *Verifiable.*          │
│ Services:     singleton + Completer<void> _ready gate + idempotent  │
│               init(); await _ready.future at the top of every public │
│               read/write.                                            │
│ Widgets:      const everywhere, super.key in every ctor,            │
│               extract a private widget when build() > 80 lines.      │
│ Imports:      dart: → package:flutter/ → package:common_games/      │
│               NEVER relative. One blank line between groups.         │
│ Comments:     /// for public API; // for the why, not the what.      │
│               No region markers. No AI co-author footers.            │
│ Tests:        AAA, test name = behavior, one expect per assertion,   │
│               setUp (not setUpAll) for shared state.                 │
│ 3-gate:       dart format · flutter analyze --fatal-infos ·         │
│               flutter test. ALL must pass.                           │
└──────────────────────────────────────────────────────────────────────┘
```

If a rule on this card is unclear, jump to the numbered section below.

---

## 2. Naming conventions

| What | Convention | Example from this repo |
|---|---|---|
| File name | `snake_case.dart` | `klondike_setup_screen.dart`, `game_stats.dart` |
| Type (class, enum, mixin, sealed) | `PascalCase` | `KlondikeModel`, `MinesweeperState`, `GameMode` |
| Extension type | `PascalCase` | — |
| Public method / getter / setter | `camelCase` | `recordWin`, `getKlondikeWins`, `isEmpty` |
| Public field | `camelCase` (usually `final`, not `var`) | `moves`, `tableau`, `selectedPile` |
| Private field / method | `_camelCase` | `_ready`, `_history`, `_pushHistory` |
| Parameter | `camelCase` | `KlondikeModel.deal({int? seed})` |
| Local | `camelCase` | `final card = stock.removeLast();` |
| Top-level constant | `lowerCamel` (no `k`-prefix) | `static const String _karuroWinsKey = 'karuro_wins';` |
| Enum value | `lowerCamel` | `GameMode.twoPlayer`, `MinesweeperDifficulty.expert` |
| `Key` string | `snake_case` | `ValueKey('klondike_stock')` |

### 2.1 The `k`-prefix rule

The `k` prefix is reserved by the Dart team for top-level compile-time
constants exported from `package:flutter/foundation.dart`:
`kDebugMode`, `kIsWeb`, `kReleaseMode`, `kToolbarHeight`. **Our own
constants do not need it.** The lints don't enforce either way; the
convention is by hand.

```dart
// GOOD (this repo)
static const String _karuroWinsKey = 'karuro_wins';
static const String _klondikeWinsKey = 'klondike_wins';
static String _minesweeperWinsKey(MinesweeperDifficulty d) =>
    'minesweeper_${d.name}_wins';

// BAD — reserves the prefix for foundation.dart
static const String kKaruroWinsKey = 'karuro_wins';
```

### 2.2 Why a leading underscore for "private"

Dart has library-level privacy (not class-level). An identifier
prefixed with `_` is private to the *library* (the `.dart` file, by
default). The lint set doesn't flag missing `_`. The rule is
enforced by code review.

```dart
// GOOD — these are library-private; tests in another file can't
// touch them.
class GameStats {
  GameStats._();
  final Completer<void> _ready = Completer<void>();
  SharedPreferences? _prefs;
}

// BAD — the underscore is a contract, not a style preference.
class GameStats {
  GameStats();
  final Completer<void> ready = Completer<void>();
  SharedPreferences? prefs;
}
```

---

## 3. File organization

The "skimmable file" pattern. A reviewer should be able to find any
class member in 3 seconds.

A well-organized `.dart` file goes in this order:

1. `library;` directive (if needed for docs; the `lib/games/klondike/
   klondike_model.dart` uses one for the top-of-file doc comment).
2. Top-of-file doc comment (`///`).
3. Imports — see §4.
4. Constants (`static const` at the top of the class, not the file,
   unless the constant is shared).
5. Type definitions (enums, sealed hierarchies, value classes).
6. The main class:
   1. Static members, then instance members.
   2. Public fields and constructors first.
   3. Public methods.
   4. Private fields and methods (`_helper`, `_checkX`).
   5. The `// ─── Section name ───` divider is OK between major
      groups; we use it in `game_stats.dart` and `klondike_model.dart`.
7. Private types (`class _Snapshot`) at the bottom of the file.

**Example** (from `lib/games/klondike/klondike_model.dart`):

```dart
/// Pure-Dart Klondike Solitaire model. No Flutter imports — the visuals
/// and gesture layer live in `klondike_board.dart`. Save/restore is
/// versioned (`version: 1`).
library;

import 'package:common_games/games/cards/card.dart';
import 'package:common_games/games/cards/deck.dart';

// ─── State ────────────────────────────────────────────────────────────
sealed class KlondikeState { ... }
final class KlondikePlaying extends KlondikeState { ... }
final class KlondikeWon extends KlondikeState { ... }

// ─── Value types ──────────────────────────────────────────────────────
class PileCard { ... }
class Pile { ... }
class KlondikeSelection { ... }

// ─── Model ────────────────────────────────────────────────────────────
class KlondikeModel {
  // public ctor + factory
  // public fields
  // public methods
  // private helpers
  // private types at the very bottom
}
class _Snapshot { ... }
```

**Don't** alphabetize class members. Alphabetization helps
`grep -n` but hurts reading. The "skimmable file" is read
top-to-bottom, with the most important info first.

---

## 4. Imports

The 18-lint set includes `always_use_package_imports` (commit-time
enforced). You **must** use `package:common_games/...`; you **may
not** use relative imports.

Order, with one blank line between groups:

```dart
// 1. dart: (core, async, collection, math, ui as needed)
import 'dart:async';
import 'dart:math';

// 2. package:flutter/ (the framework)
import 'package:flutter/material.dart';

// 3. package:common_games/... (everything we own)
import 'package:common_games/games/klondike/klondike_model.dart';
import 'package:common_games/models/game_mode.dart';
import 'package:common_games/services/game_stats.dart';
```

Rules:

- **No wildcard imports** (`import 'package:flutter/material.dart'
  show ...` is fine; `import 'package:flutter/material.dart' hide
  ...` is fine; `import 'x.dart' as y` only when there's a real
  name clash).
- **No `part` / `part of`.** We don't use Dart's old library-
  splitting mechanism. One file = one library.
- **No re-exports.** If two files need the same type, both
  import it. We don't curate a barrel file.

---

## 5. Comments and doc comments

The rule: **explain the why, not the what.** Code shows *what*
happens; comments show *why* it happens that way.

### 5.1 `///` (doc comments) — for the public API

- Public types, public methods on services, public methods on
  models that are part of the public contract.
- The first sentence is what shows up in IDE tooltips and
  `dart doc`. Make it a single, complete sentence ending in
  a period.
- After the first sentence, a blank line, then a longer
  explanation if needed.

```dart
/// Number of user-driven moves made so far. Each mutation that pushes
/// onto the history stack increments this; `undo()` decrements it.
/// Surfaced in the game screen's status bar.
int get moves => _history.length;
```

### 5.2 `//` (line comments) — for the why, not the what

```dart
// GOOD — explains the why
// Recycle: waste becomes stock in reverse order. The card that was
// on top of the waste is the new top of the stock.
final reversed = waste.reversed.toList();

// BAD — narrates the what
// Loop through the waste list and reverse it.
final reversed = waste.reversed.toList();
```

### 5.3 Match the surrounding code's density

The `game_stats.dart` file has dense doc comments because it's
a service. The `minesweeper_model.dart` file has dense comments
on the public methods but thin comments on the helpers. Match
the surrounding density — if every method in the file has a
`///`, yours should too. If none do, yours probably shouldn't
either.

### 5.4 Don't use region markers

`// #region`, `// #endregion`, `// ==== Methods ====` block markers
are noise. The `// ─── Stock / waste ───` line we use in
`klondike_model.dart` is *not* a region marker — it's a label for
the *human* ("the next ~30 lines are about the stock/waste
domain"). Region markers are a Visual Studio / VS Code IDE
folding feature and are not used here.

---

## 6. Constants and magic numbers

Extract a `static const` for any literal that:

- Appears more than once in the same file.
- Has a non-obvious meaning that a reader would have to look up
  (e.g. `'karuro_wins'` is a persisted-prefs key).
- Is a magic number that a future maintainer might want to tune
  (animation duration, retry count, threshold).

Naming is `lowerCamel` with no `k` prefix. The constant lives
at the top of the class (most common) or at the top of the
file (only if shared across classes in the same file).

```dart
// GOOD — named, scoped, single source of truth
static const String _karuroWinsKey = 'karuro_wins';
static const Duration _boardAnimDuration = Duration(milliseconds: 250);

// BAD — magic string in the call site
await prefs.setInt('karuro_wins', ...);
```

**Where design tokens go** (color, spacing, typography, motion):
**not** in this file. They live in `lib/app_theme.dart` (see
[`../design/03-design-system.md`](../design/03-design-system.md) §"Tokens").
Reach for `Theme.of(context).colorScheme.primary` instead of
`Color(0xFF5C35CC)`.

---

## 7. Where to next

You now have the cross-cutting rules. For the type-specific
rules — how a `*_model.dart` is shaped, how a service's
`Completer<void> _ready` gate is built, how a widget's `build`
method is split into private widgets, how errors are thrown
and caught, how tests are arranged and asserted, and the
Dart 3 idioms we use — go to
[`coding-guidelines-types.md`](coding-guidelines-types.md).

If you're not sure which doc to open next:

| About to write… | Read this section |
|---|---|
| A pure-Dart game or feature model | §7. Models |
| A new service in `lib/services/` | §8. Services |
| A screen, a board, or a private widget | §9. Widgets |
| `try` / `catch` / `throw` / `assert` | §10. Errors |
| A unit, widget, or golden test | §11. Tests |
| A switch, a record, or a sealed class | §12. Idiomatic Dart 3 |
| Anything where the rule feels wrong | §13. When to deviate |

---

## 8. See also

- [`coding-guidelines-types.md`](coding-guidelines-types.md) —
  the rules specific to each kind of file (models, services,
  widgets, errors, tests, Dart 3).
- [`flutter-dart-style.md`](flutter-dart-style.md) — the
  *why* of every lint, with before/after pairs.
- [`../design/02-architecture.md`](../design/02-architecture.md)
  — the model-purity rule, the service pattern, the
  two-file pattern, the state pattern.
- [`testing-strategy.md`](testing-strategy.md) — the test
  pyramid, async patterns, regression test policy.
- [`../design/06-feature-decomposition.md`](../design/06-feature-decomposition.md)
  — how a feature becomes a PR.
- [`../../analysis_options.yaml`](../../analysis_options.yaml)
  — the 18 enabled lints. This doc doesn't restate them;
  it tells you how to live with them.
- [`.claude/rules/lib-games.md`](../../.claude/rules/lib-games.md),
  [`.claude/rules/lib-screens.md`](../../.claude/rules/lib-screens.md),
  [`.claude/rules/lib-services.md`](../../.claude/rules/lib-services.md),
  [`.claude/rules/test.md`](../../.claude/rules/test.md) —
  path-scoped rules auto-loaded by Claude Code.
