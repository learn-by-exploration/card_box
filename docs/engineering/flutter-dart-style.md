> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Flutter / Dart Style

Idiomatic Dart 3 + Flutter, with rationale for each rule in
[`analysis_options.yaml`](../../analysis_options.yaml). This is the
*why*; the lint catches the *what*.

---

## 1. The 18 enabled lints

Every lint below is enabled in `analysis_options.yaml`. For each:
the rule, the rationale, and a before/after example.

### `avoid_print`

**Why.** `print()` goes to the system console in production, where
it's invisible, unfilterable, and (in release builds) gets
stripped inconsistently. Worse, it's a vector for logging PII.

**Before:**
```dart
print('user logged in: $email');
```

**After:**
```dart
if (kDebugMode) {
  debugPrint('user logged in: ${user.id}'); // no PII
}
```

### `prefer_const_constructors`

**Why.** `const` constructors are evaluated at compile time — no
runtime allocation. For a tree of 100 widgets, this saves real
milliseconds on first frame.

**Before:**
```dart
return Padding(padding: EdgeInsets.all(16), child: Text('hi'));
```

**After:**
```dart
return const Padding(padding: EdgeInsets.all(16), child: Text('hi'));
```

### `prefer_const_declarations`

**Why.** Same as above for `final` locals that could be `const`.

**Before:**
```dart
final radius = 16.0;
```

**After:**
```dart
const radius = 16.0;
```

### `prefer_const_literals_to_create_immutables`

**Why.** `const` lists/sets/maps skip the allocation. For static
content (a list of game modes, a map of difficulty names), this
is a free win.

**Before:**
```dart
final modes = [GameMode.gomoku, GameMode.othello];
```

**After:**
```dart
const modes = [GameMode.gomoku, GameMode.othello];
```

### `prefer_final_locals`

**Why.** `final` for locals signals "this doesn't change after
construction." It's a hint to the reader, and it enables some
compiler optimizations. `var` is for variables that are
reassigned.

**Before:**
```dart
var name = 'Klondike';
```

**After:**
```dart
final name = 'Klondike';
```

### `prefer_single_quotes`

**Why.** Single quotes are the Dart community convention; double
quotes are reserved for strings that contain single quotes
(without escaping). Consistency.

**Before:**
```dart
return Text("Hello, world.");
```

**After:**
```dart
return Text('Hello, world.');
```

### `use_key_in_widget_constructors`

**Why.** Keys let Flutter match a widget in a new tree to a
widget in the old tree. Without a key, the framework matches by
runtime type and position — fine for static trees, broken for
reorderable lists, dialogs, and async-loaded children. Tests
need keys to find widgets by `find.byKey(...)`.

**Before:**
```dart
class _Card extends StatefulWidget {
  const _Card();
  ...
}
```

**After:**
```dart
class _Card extends StatefulWidget {
  const _Card({super.key});
  ...
}
```

### `always_use_package_imports`

**Why.** Relative imports (`import '../models/foo.dart';`) make
refactoring painful — moving a file breaks every relative import.
Package imports (`import 'package:common_games/models/foo.dart';`)
survive moves.

**Before:**
```dart
import '../models/game_mode.dart';
```

**After:**
```dart
import 'package:common_games/models/game_mode.dart';
```

### `prefer_is_empty` / `prefer_is_not_empty`

**Why.** `isEmpty` and `isNotEmpty` are O(1) on `String`, `List`,
`Map`, `Set`. `length > 0` and `length == 0` work but are
stylistically worse.

**Before:**
```dart
if (moves.length > 0) ...
```

**After:**
```dart
if (moves.isNotEmpty) ...
```

### `unnecessary_this`

**Why.** `this` is implicit in Dart. Explicit `this.` adds noise
without information. The lint is opinionated and good.

**Before:**
```dart
class Foo {
  int x;
  Foo(this.x);
  int get x2 => this.x * 2;
}
```

**After:**
```dart
class Foo {
  int x;
  Foo(this.x);
  int get x2 => x * 2;
}
```

### `avoid_unnecessary_containers`

**Why.** `Container` is a `StatelessWidget` that pads, decorates,
and sizes its child. If you only need one of those, use the
specific widget (`Padding`, `DecoratedBox`, `SizedBox`).

**Before:**
```dart
return Container(padding: EdgeInsets.all(16), child: Text('hi'));
```

**After:**
```dart
return Padding(padding: EdgeInsets.all(16), child: Text('hi'));
```

### `sized_box_for_whitespace`

**Why.** Whitespace in a `Row`/`Column` is a `SizedBox`, not a
`Container` or `Padding`. Forces the framework to skip a layout
pass for the gap.

**Before:**
```dart
return Column(children: [Text('a'), Container(height: 16), Text('b')]);
```

**After:**
```dart
return Column(children: [Text('a'), SizedBox(height: 16), Text('b')]);
```

### `use_colored_box`

**Why.** A solid-color background is `ColoredBox`, not
`Container(color: ...)`. `ColoredBox` is a `RenderObjectWidget`
that skips the `Container` overhead.

**Before:**
```dart
return Container(color: Colors.red, child: Text('hi'));
```

**After:**
```dart
return ColoredBox(color: Colors.red, child: Text('hi'));
```

### `sort_child_properties_last`

**Why.** Flutter convention: `child:` is the last property in a
widget constructor. Improves readability when a constructor
spans multiple lines.

**Before:**
```dart
return Padding(child: Text('hi'), padding: EdgeInsets.all(16));
```

**After:**
```dart
return Padding(padding: EdgeInsets.all(16), child: Text('hi'));
```

### `unawaited_futures`

**Why.** A `Future` that completes with an error is *silently*
swallowed if unawaited. The lint catches it. The GameStats
async-gate (commit 43) is the reason this lint is loud: every
read and write returns a `Future`, and the lint forces the
caller to think about it.

**Before:**
```dart
void onWin() {
  GameStats.instance.recordKlondikeWin(); // lint error
}
```

**After:**
```dart
void onWin() {
  unawaited(GameStats.instance.recordKlondikeWin());
}
```

Or:

```dart
Future<void> onWin() async {
  await GameStats.instance.recordKlondikeWin();
}
```

### `unnecessary_lambdas`

**Why.** `() => fn` is `fn` with extra syntax when `fn` is a
tear-off. Use the tear-off.

**Before:**
```dart
onPressed: () => _handleTap(),
```

**After:**
```dart
onPressed: _handleTap,
```

### `avoid_redundant_argument_values`

**Why.** Passing a default value explicitly is noise.

**Before:**
```dart
return Container(color: Colors.red, child: child, width: double.infinity);
```

**After:**
```dart
return Container(color: Colors.red, child: child);
```

(The `width: double.infinity` is the default for `Container`.)

### `strict-casts` / `strict-inference` / `strict-raw-types`

**Why.** These are `analyzer` options, not lints. They force
explicit type annotations and disallow `dynamic` and raw
`List`/`Map`. Catches a class of bugs at compile time that
would otherwise be runtime crashes.

---

## 2. Type system

- `dynamic` is banned except at the boundary with JSON.
- `Object?` for "any value, possibly null"; `T?` for "T or
  null."
- `List<T>` not `List`; `Map<K, V>` not `Map`. The
  `strict-raw-types` rule enforces it.
- Type promotion: `if (x is String) { ... x.length ... }`
  works because `x` is promoted to `String` in the branch.
  Don't cast manually.

---

## 3. Null safety

- The `?` and `!` operators are the only null-safety ops.
  `!` asserts non-null; using it on a nullable value throws at
  runtime. Use `?` or null-aware checks instead.
- `assert` at boundaries. After parsing JSON, `assert(parsed is
  Map<String, Object?>)` to fail fast on bad input.
- `late` for fields that are initialized in `initState` or
  lazy-initialized. The lifecycle must guarantee the
  initialization happens before any read. **Avoid `late` for
  service singletons** — use the `Completer<void> _ready` gate
  instead.

---

## 4. Async

- Every `Future` is `await`ed or wrapped in `unawaited(...)`.
  The lint is on; the analyzer errors on a bare unawaited
  future.
- `Stream` cancellation: `await for` cancels the subscription
  on break; explicit `.cancel()` for manual subscription.
- `Completer<T>` for the init-gate pattern:
  ```dart
  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_ready.isCompleted) _ready.complete();
  }
  ```
  Worked example: `GameStats._ready` in
  [`lib/services/game_stats.dart`](../../services/game_stats.dart).

---

## 5. Collections

- `List<T>.unmodifiable` for read-only returns. `Map.unmodifiable`
  for read-only maps.
- `Iterable<T>` (not `List<T>`) for read-only returns that
  don't need indexing. More flexible.
- Spread + collection-if:
  ```dart
  final all = [
    ...standardModes,
    if (kDebugMode) DebugMode.cheat,
  ];
  ```

---

## 6. Classes

- **Immutable by default.** `const` constructor + `final` fields.
- **`copyWith` for transitions.**
  ```dart
  class KlondikeModel {
    final List<Column> columns;
    const KlondikeModel({required this.columns});
    KlondikeModel copyWith({List<Column>? columns}) =>
      KlondikeModel(columns: columns ?? this.columns);
  }
  ```
- **`==` and `hashCode`.** Hand-roll for value types; use
  `equatable` if the boilerplate gets tedious. We don't use
  `equatable` today; the model classes have hand-rolled `==`.
- **Sealed classes for state.** See
  [`../design/02-architecture.md`](../design/02-architecture.md)
  §"State pattern".

---

## 7. Functions

- **Top-level > static > instance.** A function that doesn't
  need `this` should be top-level (or static in a class).
- **`typedef` for complex signatures.**
  ```dart
  typedef WinCheck = bool Function(Board board, Player p);
  ```
- **Tear-offs over lambdas.** `unnecessary_lambdas` lint.

---

## 8. Strings

- Single quotes (`prefer_single_quotes`).
- Raw strings for paths/regex: `r'^\d+$'` instead of `'^\\d+$'`.
- Interpolation: `'hello, $name'` not `'hello, ' + name`. The
  `+` form calls `.toString()` and concatenates; interpolation
  is faster and reads better.

---

## 9. Error handling

- **Typed exceptions.** `class GameOverException implements
  Exception` — not `throw 'game over'`.
- **No string errors.** `throw StateError('...')` is the
  minimum; a custom typed exception is better.
- **No silent catches.** An empty `catch` is a bug. If you
  must catch and ignore, leave a comment explaining why and
  link to an issue.
- **Rethrow with stack.** `throw StateError('...')` keeps the
  original stack via `Error.throwWithStackTrace`. The
  `silent-failure-hunter` agent flags swallowed errors.

---

## 10. Common pitfalls

- **`tester.runAsync` is not re-entrant.** Don't nest `runAsync`
  calls. Inside `runAsync`, await real `Future`s.
- **`setState` after `dispose`.** A `Future` that completes
  after the widget is unmounted will throw on `setState`.
  Check `mounted` first.
- **`BuildContext` across async gaps.** After `await`, the
  widget may have been unmounted. Check `mounted` before
  using `context`. Better: capture `context`-dependent values
  (e.g. `Theme.of(context)`) before the `await`.
- **`MediaQuery.of(context)` vs `MediaQuery.sizeOf(context)`.**
  The former rebuilds the widget on every MediaQuery change;
  the latter only on the specific property. Use
  `MediaQuery.sizeOf(context)` when you only need size.
- **Final fields in `StatefulWidget`.** A `State` object's
  `build` is called many times; fields that change during
  build must be in `State`, not in the widget.
- **ListView vs Column with `SingleChildScrollView`.** If the
  list is short and known-size, `Column` is fine. For long
  lists, `ListView` (or `ListView.builder` for very long).

---

## See also

- [`../design/02-architecture.md`](../design/02-architecture.md) —
  the model-purity, state, and service patterns.
- [`testing-strategy.md`](testing-strategy.md) — the async test
  patterns.
- [`analysis_options.yaml`](../../analysis_options.yaml) — the
  source of truth for which lints are on.
