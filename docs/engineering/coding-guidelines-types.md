> **Imported from board_box.** This doc was authored for board_box; the file references and worked-example commits in the body (e.g. KlondikeModel, GameStats, Minesweeper, the b71bd0a / 135eb69..256aa71 commits) are board_box-specific. The *rules* and *patterns* are universal Flutter/Dart practice and apply here. Swap in card_box-local examples (e.g. card_repository, tag_resolver, the project's own v_model/ trace) in follow-up edits — the structure does not need to change.

---

# Coding Guidelines — Models, Services, Widgets, Errors, Tests, Dart 3

> **Companion to [`coding-guidelines.md`](coding-guidelines.md).** That
> doc covers the cross-cutting rules every file in Board Box follows:
> naming, file organization, imports, comments, constants. This doc
> covers the rules specific to each kind of file: pure-Dart models,
> services with the `Completer<void> _ready` gate, Flutter widgets,
> error handling, tests, and idiomatic Dart 3. Read the main doc
> first; reach for this one when you're about to write a model,
> service, widget, or test, or when you want a worked example of a
> pattern.

---

## 7. Models (pure Dart)

`lib/games/<name>/<name>_model.dart` is the model file. The
**model-purity rule** is the single most-enforced architectural
invariant in Board Box.

> **Verifiable:**
> ```bash
> grep -l "import 'package:flutter/" lib/games/*/[a-z]*_model.dart
> # Must print nothing.
> ```

If it prints, the model is importing Flutter and is now
un-unit-testable. Move the widget code to `*_board.dart`.

### 7.1 The shape

- **`sealed class *State`** at the top, with the playing
  variant as a `final class *Playing extends *State` and the
  won/lost variants as siblings. Not bare enums.

  ```dart
  sealed class KlondikeState { const KlondikeState(); }
  final class KlondikePlaying extends KlondikeState { const KlondikePlaying(); }
  final class KlondikeWon extends KlondikeState { const KlondikeWon(); }
  ```

  Why sealed: `switch (state)` over a sealed class is
  exhaustive at compile time. A new state variant added later
  breaks the build at every existing `switch`, not at runtime.

- **Public state is read-only `final`.** Mutations go through
  methods that push history and update internal mutable
  lists. (Yes, the model is internally mutable. The contract
  is "the public surface is read-only; transitions go through
  the public methods.")

  ```dart
  final List<Pile> tableau;   // read-only reference
  // ...
  void flipStock() {          // the only way to mutate stock
    _pushHistory();
    stock.removeLast();
    waste.add(PileCard(card: card.card, faceUp: true));
  }
  ```

- **`const` constructors on value classes.** `PileCard` has
  `const PileCard({required this.card, required this.faceUp})`
  — every instance is a const literal at the call site.

- **`toJson` / `fromJson` with a versioned envelope.** Every
  saveable model has `toJson()` returning a map with a
  `'version': 1` field, and a `fromJson` factory that
  validates the version and throws on mismatch. See
  `klondike_model.dart` §"Save / restore".

- **`copyWith` is hand-rolled** (we don't use the `equatable`
  package). Optional fields, default to existing value.

  ```dart
  MinesweeperCell copyWith({bool? isMine, bool? revealed, bool? flagged}) =>
      MinesweeperCell(
        isMine: isMine ?? this.isMine,
        revealed: revealed ?? this.revealed,
        flagged: flagged ?? this.flagged,
      );
  ```

### 7.2 Test-only helpers

When a test needs to construct a state that's hard to reach
through public moves, expose a `debugXxxForTest` method. The
naming makes the intent explicit and lets a code reviewer
flag them with one grep:

```dart
// GOOD
void debugPushForTest(int foundationIndex, PlayingCard card) { ... }
void debugSetTableauForTest(int col, List<PileCard> cards) { ... }

// BAD — same name as a public method, just hidden in the body
void push(int foundationIndex, PlayingCard card) { ... }
```

`grep -n "ForTest" lib/games/*/[a-z]*_model.dart` is the
"is this safe?" check. The `flutter-expert` agent and the
PR reviewer both use it.

---

## 8. Services

Singletons. Every service in `lib/services/` follows the same
shape. The full architectural pattern is in
[`../design/02-architecture.md`](../design/02-architecture.md) §"Service pattern"
and the path-scoped rule
[`.claude/rules/lib-services.md`](../../.claude/rules/lib-services.md).
This section is the day-to-day version.

```dart
class MyService {
  MyService._();                                    // private ctor
  static final MyService instance = MyService._();  // public singleton

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  late SharedPreferences _prefs;

  static const String _someKey = 'some_key';        // private static key

  Future<void> init() async {
    if (_ready.isCompleted) return;                 // idempotent
    _prefs = await SharedPreferences.getInstance();
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<int> getSomeStat() async {
    await _ready.future;                            // every public read waits
    return _prefs.getInt(_someKey) ?? 0;
  }

  Future<void> recordSomeStat() async {
    await _ready.future;                            // every public write waits
    final n = _prefs.getInt(_someKey) ?? 0;
    await _prefs.setInt(_someKey, n + 1);
  }
}
```

The four rules, in order of importance:

1. **Private constructor + `static final instance`.** No
   `factory MyService()`, no `MyService()` from outside. The
   singleton is the only entry point. Tests don't get to
   construct a second instance.
2. **`Completer<void> _ready` gate.** Every public read and
   write `await`s it. Without the gate, a widget that calls
   `getWins()` before `init()` completes returns a silent `0`
   — the bug that `b71bd0a fix(stats): block reads and writes
   until GameStats.init() completes` (commit 43) fixed.
3. **`init()` is idempotent.** `main()` calls it before
   `runApp()`; tests call it in `setUp()`. Both must be safe.
4. **Keys are private statics.** `_karuroWinsKey`, not
   `'karuro_wins'` inlined at every call site. The grep
   "where is this key used?" is then trivial.

`SettingsService` is a slightly different shape (it's a
`ChangeNotifier`, not a pure async service). The
`preferences` getter is the `await` gate. The same rules
apply.

---

## 9. Widgets

### 9.1 `const` everywhere possible

The `prefer_const_constructors`, `prefer_const_declarations`,
and `prefer_const_literals_to_create_immutables` lints are
on. If a widget is `const`-constructible, build it as a const
literal. The performance benefit (avoid rebuild allocation)
is real; the readability benefit (visually-distinct const
literals) is bigger.

```dart
// GOOD
const SizedBox(height: 8),
Text('Loading…', style: Theme.of(context).textTheme.bodyMedium),
const Icon(Icons.refresh),

// BAD
SizedBox(height: 8),
```

### 9.2 `super.key` in every constructor

The `use_key_in_widget_constructors` lint catches this, but
the rule is more nuanced: **every stateful widget has a
`super.key`, even when the lint doesn't catch it.** Tests use
`find.byKey(const Key('my_widget'))` to pump, and you can't
add a key later without breaking the test.

```dart
class MyWidget extends StatefulWidget {
  const MyWidget({super.key, required this.title});
  final String title;
  // ...
}
```

### 9.3 Key types

- **`ValueKey('snake_case_id')`** — preferred, `const`-compatible.
- **`UniqueKey()`** — use only when you actually need a new
  key on every build (rare; usually wrong).
- **`GlobalKey<State>()`** — avoid. It pins the widget's
  State across rebuilds, which is usually a sign that the
  tree is in the wrong place. If you find yourself reaching
  for one, refactor first.

### 9.4 Extracting private widgets

If a `build()` method is past ~80 lines, or has a clear
"this is one widget inside another" sub-section, extract a
private widget. The pattern is `class _Foo extends StatelessWidget`
or `StatefulWidget` defined in the same file. Keep it
private (leading underscore) — it's an implementation detail.

```dart
class GameScreen extends StatefulWidget {
  // ...
}

class _GameScreenState extends State<GameScreen> {
  // ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Klondike')),
      body: Column(children: [
        _StatusBar(moves: _moves, time: _elapsed),
        const _Board(),
        _ActionBar(onUndo: _undo, onHint: _hint),
      ]),
    );
  }
}

class _StatusBar extends StatelessWidget { ... }
class _Board extends StatelessWidget { ... }
class _ActionBar extends StatelessWidget { ... }
```

The line count rule of thumb comes from
[`../design/02-architecture.md`](../design/02-architecture.md) §"Screen
pattern" — the screen is `StatefulWidget` for async, the
private widgets are `StatelessWidget` for static views.

---

## 10. Errors

### 10.1 Throw typed exceptions; catch typed exceptions

```dart
// GOOD
if (version != 1) {
  throw const FormatException('Unsupported Klondike save version');
}

// BAD
if (version != 1) {
  throw 'wrong version';
}
```

The `unawaited_futures` and `unnecessary_lambdas` lints
together with `avoid_redundant_argument_values` keep the
"what kind of error is this?" question from being
unanswerable.

### 10.2 `assert` at the boundary

Use `assert` for preconditions the caller is responsible for
(e.g. "this column index is in range"). The asserts are
stripped in release, so they don't ship to production. They
*do* run in `flutter test` and in debug builds, which is
exactly when you want them.

```dart
void _assertEntryCell(int row, int col) {
  if (puzzle.cells[row][col] is! KaruroEntryCell) {
    throw ArgumentError('($row, $col) is not an entry cell');
  }
}
```

### 10.3 `throw` vs `return Result`

- **Throw** for unrecoverable / programmer error: invalid
  save format, illegal move, null where a value is required.
- **Return a bool** for "did this transition do anything?":

  ```dart
  bool enterValue(int row, int col, String value) {
    if (state is KaruroWon) return false;  // not an error, just a no-op
    // ...
  }
  ```

  Caller checks the return value, doesn't catch. The
  `karuro_model.dart` `enterValue` is the reference example.

### 10.4 No empty `catch`

`catch (_)` (or `catch (e)`) with no rethrow or logging is a
silent failure. The `silent-failure-hunter` agent exists
specifically to find these.

```dart
// BAD
try {
  await prefs.setInt(key, value);
} catch (_) {}

// GOOD — log and rethrow, or log and return a Result
try {
  await prefs.setInt(key, value);
} on Exception catch (e, st) {
  // Log, surface, or rethrow. Never swallow.
}
```

---

## 11. Tests

Full rules in
[`.claude/rules/test.md`](../../.claude/rules/test.md) and
[`testing-strategy.md`](testing-strategy.md). The
short version:

- **AAA** (Arrange / Act / Assert). One blank line between.
- **Test name = behavior under test.** `'recordKaruroWin
  increments and round-trips through prefs'`, not `'test 1'`.
- **One `expect` per logical assertion.** A `containsAll`
  with N items is one expect; two `contains` are two
  expects.
- **`setUp` (not `setUpAll`)** for shared state. `setUpAll`
  is for genuinely-shared, immutable state. Tests share a
  process-global singleton (`GameStats.instance`), so we
  *can't* reset between cases — that constraint is
  documented in the test file itself.
- **No skipped tests.** `skip:` requires an issue link.
  `@Tags(['flaky'])` is the right escape hatch for an
  intermittent test, but the tag requires an issue link and
  a fix-within-one-sprint promise.
- **Coverage on changed files, not whole repo.** ≥80% on
  the diff.
- **Async patterns.** `tester.runAsync` for real `Future`s;
  `pump` (not `pumpAndSettle`) after a drag. These are
  easy to get wrong; the reference is
  [`testing-strategy.md`](testing-strategy.md) §"Async
  patterns".

---

## 12. Idiomatic Dart 3

Dart 3 (we're on `^3.12.0`) has patterns, records, sealed
classes, and switch expressions. We use them where they
clarify, not where they show off.

### 12.1 Switch expressions for mapping enums to values

```dart
// GOOD — switch expression
String get label => switch (this) {
  MinesweeperDifficulty.beginner => 'Beginner',
  MinesweeperDifficulty.intermediate => 'Intermediate',
  MinesweeperDifficulty.expert => 'Expert',
};

// BAD — full switch statement for a one-line mapping
String get label {
  switch (this) {
    case MinesweeperDifficulty.beginner:
      return 'Beginner';
    case MinesweeperDifficulty.intermediate:
      return 'Intermediate';
    case MinesweeperDifficulty.expert:
      return 'Expert';
  }
}
```

### 12.2 Sealed classes for state

(See §7.1.) `sealed class *State` + `final class *Playing` is
the established pattern. The exhaustive `switch` is the
"is this the right type?" check.

### 12.3 Records for transient tuples

`(int, int)` for a row/col, `('Beginner', 9, 9, 10)` for
difficulty metadata. Records are not for *public* data
structures — those should be named classes for IDE
auto-complete and `dart doc` to work.

```dart
// GOOD — tuple from a private method
final (int, int)? triggeredAt;

// BAD — record as a public value type
typedef CellCoord = ({int row, int col});  // should be a class
```

### 12.4 Pattern matching for shape

```dart
// GOOD — pattern in if
if (json.containsKey('card')) {
  final s = json['card'] as String;
  // ...
}
```

Pattern *matching* in `switch case` (`case Foo(:var x)`) is
fine but rarely needed in our models; the `switch` is
usually on an enum.

### 12.5 `if` and `case` patterns

The Dart 3.0 patterns we use the most: `if (x is T)` (null
checks) and `if (json is Map<String, dynamic>)`. Avoid the
newer `case` patterns until you're sure the reader knows
them — they make the code shorter but harder to skim.

---

## 13. When to deviate

The doc is a guideline, not a law. The lint set is the law.
A guideline is a hint.

**When to deviate:**

- The guideline makes the code longer without making it
  clearer.
- The codebase has a long-standing local convention that
  the guideline would break (e.g. `lib/games/cards/` uses
  a different file layout for the card types).
- The code is the natural exception (e.g. a singleton's
  `_()` private ctor is fine even though private
  constructors are usually suspicious).

**When you deviate, leave a one-line `// why:` comment.**
A reviewer should see the deviation and the reason in the
same screen:

```dart
// why: this is the test seam; see bug-hunt-process.md §"Test seam"
Future<void> debugSetTableauForTest(int col, List<PileCard> cards) {
  // ...
}
```

If you find yourself deviating more than once, the
guideline is probably wrong — file an issue or update
this doc.

---

## 14. See also

- [`coding-guidelines.md`](coding-guidelines.md) — the
  cross-cutting rules (naming, file organization, imports,
  comments, constants).
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
