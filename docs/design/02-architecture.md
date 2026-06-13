> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 02 — Architecture

The shape of the code. Every rule in this doc is verifiable by
reading a specific file or running a specific grep.

---

## Feature-folder pattern

```
lib/
├── main.dart                 # entry point; initializes services
├── models/                   # cross-game value types & enums
│   ├── game_mode.dart        # GameType enum, GameMode class
│   └── json_helpers.dart
├── screens/                  # top-level navigation + per-game setups
│   ├── home_screen.dart
│   ├── mode_select_screen.dart
│   ├── game_screen.dart
│   ├── settings_screen.dart
│   ├── privacy_policy_screen.dart
│   ├── splash_screen.dart
│   ├── sudoku/
│   ├── karuro/
│   ├── klondike/
│   └── minesweeper/
├── games/                    # one folder per game
│   ├── cards/                # shared PlayingCard, Deck, CardView
│   ├── checkers/             # checkers_model.dart + checkers_board.dart
│   ├── dots_and_boxes/
│   ├── gomoku/
│   ├── karuro/               # + karuro_puzzle.dart, karuro_assets.dart
│   ├── klondike/             # + klondike_ai.dart (AI > 150 LOC)
│   ├── minesweeper/          # + minesweeper_difficulty.dart
│   ├── othello/
│   ├── sudoku/
│   └── tictactoe/
├── services/                 # singletons with _ready gate
│   ├── game_stats.dart
│   ├── settings_service.dart
│   └── haptic_service.dart
├── theme/
│   └── app_theme.dart        # M3 ThemeData, seed 0xFF5C35CC
└── widgets/                  # cross-game UI primitives
```

**Why feature folders, not type folders?** A new game is one
self-contained folder. Deleting a game is one `rm -rf`. Reviewing a
game is opening one folder.

---

## Model-purity rule

**`lib/games/<name>/<name>_model.dart` MUST be pure Dart** — no
`package:flutter/*` imports. Game logic must be unit-testable
without a widget tree.

**Sole exception:** sibling `<name>_assets.dart` (e.g.
`karuro_assets.dart`) is allowed to import `package:flutter/services.dart`
for `rootBundle`, because puzzle files are bundled assets. The
returned types are still pure-Dart value objects.

**Verifiable:**

```bash
# Should print nothing.
grep -l "import 'package:flutter/" lib/games/*/[a-z]*_model.dart
```

If that command ever prints a file, that file is violating the rule.

**Why?** Three reasons.

1. **Test speed.** A pure-Dart model test runs in <1ms. A widget-tree
   test takes ~50ms minimum, even when it's not testing widgets.
2. **Reuse.** The same model can be reused for a future web build
   (Wasm), a CLI, a server-side validator, or a test fixture
   generator.
3. **Discipline.** A model that *can't* see Flutter makes different
   choices. It doesn't reach for `Theme.of(context)` to decide a
   color. It doesn't reach for `Navigator` to navigate. It exposes
   pure data.

**Worked example: Klondike.** `klondike_model.dart` is pure Dart.
`klondike_board.dart` imports `package:flutter/material.dart` and
contains the `KlondikeBoard` widget, the drag-and-drop handlers, the
stock-pile animation, and the AI. `klondike_ai.dart` is the third file
(extracted because AI grew past 150 LOC).

---

## Two-file game pattern

The minimum for a new game is:

- `<name>_model.dart` — pure Dart. State, transitions, win/loss
  detection, save/load, AI move generation (if simple).
- `<name>_board.dart` — Flutter widget. Renders the model, handles
  user input, runs the AI (or imports a third file).

Extract `<name>_ai.dart` if:

- The AI implementation in `<name>_board.dart` grows past ~150 LOC
  (Klondike is the one case today), OR
- The AI is independently testable and you want to unit-test it
  without a widget tree.

**Worked example: Klondike (3 files).**

```
lib/games/klondike/
├── klondike_model.dart     # pure Dart, ~800 LOC, all game rules
├── klondike_ai.dart        # pure Dart, hint + auto-complete + hard
└── klondike_board.dart     # Flutter widget + drag-and-drop + timer
```

`klondike_board.dart` calls into `klondike_ai.dart` for hint, undo,
and auto-complete moves. Both `klondike_model.dart` and
`klondike_ai.dart` are Flutter-free.

---

## State pattern

Each game exposes a sealed `*State` hierarchy over bare enums.

```dart
sealed class KlondikeState {}
final class KlondikePlaying extends KlondikeState {
  final KlondikeModel model;
  const KlondikePlaying(this.model);
}
final class KlondikeWon extends KlondikeState {
  final KlondikeModel model;
  final Duration elapsed;
  const KlondikeWon(this.model, this.elapsed);
}
```

**Why sealed classes, not enums?**

- A `KlondikeWon` carries the elapsed time and the final model. An
  enum can't carry data without a parallel map.
- `switch (state)` over a sealed class is exhaustive at compile time
  (the analyzer errors if you miss a case).
- It's easy to add a new state (e.g. `KlondikePaused`) without
  rewriting the screen.

**Immutability.** All state classes are immutable. State transitions
return *new* model instances; never mutate. (The model's `move` method
returns a new `KlondikeModel`, not `this` with fields changed.)

---

## Service pattern

A singleton with `Completer<void> _ready`. The pattern (commit 43):

```dart
class GameStats {
  GameStats._();
  static final GameStats instance = GameStats._();

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  late SharedPreferences _prefs;

  Future<void> init() async {
    if (_ready.isCompleted) return;        // idempotent
    _prefs = await SharedPreferences.getInstance();
    if (!_ready.isCompleted) _ready.complete();
  }

  // All public reads wait for the gate.
  Future<int> getKlondikeWins() async {
    await _ready.future;
    return _prefs.getInt(_klondikeWinsKey) ?? 0;
  }

  // All public writes wait, then read-modify-write.
  Future<void> recordKlondikeWin() async {
    await _ready.future;
    final n = _prefs.getInt(_klondikeWinsKey) ?? 0;
    await _prefs.setInt(_klondikeWinsKey, n + 1);
  }
}
```

**Why the gate?** Without it, a widget that calls
`getKlondikeWins()` before `init()` completes gets a silent `0`. A
widget that calls `recordKlondikeWin()` does an `await
prefs.setInt(0+1)` *over* the prefs that `init()` is about to load.
Both are silent bugs. The gate kills them.

**Widgets never write to SharedPreferences directly.** They go
through `GameStats` or `SettingsService`. The service owns the keys
(private statics, never exposed).

**Worked example: `GameStats`** in `lib/services/game_stats.dart` is
the canonical example. `SettingsService` follows the same pattern.

---

## Screen pattern

A `StatefulWidget` for any screen that loads data asynchronously
(stats, settings, save state). The shape:

```dart
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  int _wins = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadWins();
  }

  Future<void> _loadWins() async {
    final w = await GameStats.instance.getKlondikeWins();
    if (!mounted) return;
    setState(() {
      _wins = w;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loaded
        ? Text('Wins: $_wins')
        : Text('Loading…', style: TextStyle(color: dim)),
    );
  }
}
```

Three rules:

1. **Async load in `initState`**, not `build`. `build` runs on every
   frame; you don't want to re-fetch.
2. **`mounted` guard before `setState`.** A `Future` can complete
   after the widget is unmounted; `setState` on a disposed widget
   throws.
3. **Dimmed placeholder during load.** A `0` rendered immediately
   then updated is a worse UX than a placeholder that resolves. See
   the `_WinsCard` in `klondike_setup_screen.dart` and `_StatsCard`
   in `minesweeper_setup_screen.dart`.

For tests: see `engineering/testing-strategy.md` §"Async patterns".

---

## Error pattern

Typed exceptions, never stringly-typed errors. Example:

```dart
class GameOverException implements Exception {
  final String reason;
  const GameOverException(this.reason);
  @override
  String toString() => 'GameOverException: $reason';
}
```

`assert(...)` at the boundary (public method entry, after a `move`):

```dart
void move(Position to) {
  assert(_isValidMove(to), 'Invalid move to $to from $_last');
  ...
}
```

No `silent catches`. The `silent-failure-hunter` agent is a hard
enforcement; if a `catch` is empty, there's a follow-up question.

---

## Layer boundaries

```
presentation  →  application  →  domain  →  data
     ↑                ↑             ↑
     └────────────────┴─────────────┘
       (one-directional imports only)
```

- `presentation` — widgets, screens. Imports `application` and
  `domain`. May not import `data` directly.
- `application` — services (`GameStats`, `SettingsService`). Imports
  `domain` and `data`. Coordinates.
- `domain` — models, value types, enums. Pure Dart. Imports nothing
  from `package:flutter/`.
- `data` — `SharedPreferences` keys, JSON shape, asset loading. The
  only layer that knows about persistence.

In Board Box today, `lib/services/` and `lib/models/` together fill
the `application` and `domain` layers. `lib/games/<name>/<name>_assets.dart`
is the only `data` layer.

**No back-edges.** A model never imports a widget. A widget never
imports `package:shared_preferences/`.

---

## What we deliberately do NOT do

- **No `freezed`.** Hand-rolled `copyWith`, `==`, `hashCode`. The
  `equatable` package is allowed but not yet adopted.
- **No `riverpod` / `bloc` / `get_it`.** `setState` + `Completer`-
  gated singletons are enough for our scale.
- **No DI container.** Services are singletons, accessed via
  `Service.instance`. Test overrides are done by re-init or by
  parameter injection.
- **No DTO layer.** The model *is* the data type. JSON
  serialization lives next to it (`fromJson` / `toJson` static
  methods on the model class) when needed.
- **No `dart:mirrors`.** Banned by Flutter anyway.

If a future project needs any of these, this is the doc to update
first.

---

## See also

- [`../engineering/testing-strategy.md`](../engineering/testing-strategy.md)
  §"Async patterns" — how to test the service and screen patterns.
- [`../engineering/bug-hunt-process.md`](../engineering/bug-hunt-process.md)
  — how the multi-perspective review tests these rules.
- [`.claude/rules/lib-games.md`](../../.claude/rules/lib-games.md) —
  path-scoped rules auto-loaded when editing `lib/games/`.
- [`.claude/rules/lib-services.md`](../../.claude/rules/lib-services.md) —
  path-scoped rules auto-loaded when editing `lib/services/`.
