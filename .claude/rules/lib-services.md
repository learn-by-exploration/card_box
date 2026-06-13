> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Path-scoped rules — `lib/services/`

Auto-loaded by Claude Code when you open a file in
`lib/services/`. Read these rules before writing code in this
area.

For the long form, see
[`../docs/design/02-architecture.md`](../docs/design/02-architecture.md)
§"Service pattern".

---

## 1. Singleton pattern

Every service is a singleton with a private constructor and a
static `instance` field:

```dart
class MyService {
  MyService._();
  static final MyService instance = MyService._();
}
```

No factory constructors, no `MyService()` from outside. The
singleton is the only entry point.

---

## 2. Init gate (Completer<void> _ready)

Every service that needs async init has a `Completer<void>
_ready` gate. The pattern (commit 43):

```dart
class MyService {
  MyService._();
  static final MyService instance = MyService._();

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
`getKlondikeWins()` before `init()` completes gets a silent
`0`. A widget that calls `recordKlondikeWin()` does an `await
prefs.setInt(0+1)` *over* the prefs that `init()` is about to
load. Both are silent bugs. The gate kills them.

---

## 3. Idempotent init

`init()` must be safe to call multiple times. The `_ready`
gate is the mechanism: the first call completes the gate; all
subsequent calls are no-ops.

`main.dart` calls `await Service.instance.init()` before
`runApp()`. Tests also call `init()` in `setUp`. Both are
safe.

---

## 4. No widgets in services

`lib/services/` is pure Dart. No `package:flutter/material.dart`,
no `BuildContext`, no `Navigator`. Services expose `Future`-returning
methods; the UI awaits them.

If a service needs to surface a result to the UI, it does so
via the method's return value (a `Future<T>`), not via a
`Stream<T>` or a callback. The screen awaits the future.

---

## 5. Test seam

- `SharedPreferences.setMockInitialValues({})` in test `setUp`
  *before* the first `SharedPreferences.getInstance()`. The
  `await MyService.instance.init()` follows.
- For tests that need to read the service's state, expose
  read-only getters. Don't expose the `Completer` or the
  `SharedPreferences` instance.
- For tests that need to mock the service, prefer a
  re-init with `setMockInitialValues({...})` over mocking
  the type. We don't use `mocktail` for services today.

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({});
  await GameStats.instance.init();
});
```
