> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Path-scoped rules — `test/`

Auto-loaded by Claude Code when you open a file in `test/`.
Read these rules before writing tests.

For the long form, see
[`../docs/engineering/testing-strategy.md`](../docs/engineering/testing-strategy.md).

---

## 1. Naming

- **Unit tests:** `test/<feature>_test.dart` (e.g.
  `klondike_model_test.dart`). One file per game model.
- **Widget tests:** `test/<feature>_widget_test.dart` (e.g.
  `klondike_widget_test.dart`). One file per widget / screen.
- **Service tests:** `test/<service>_test.dart` (e.g.
  `game_stats_test.dart`).

Test names describe the behavior under test, not the
implementation:

```dart
// GOOD
test('returns empty array when no markets match query', () {});
// BAD
test('test 1', () {});
```

---

## 2. Coverage

- **≥80% on changed files.** Not the whole repo; the diff.
  `flutter test --coverage` → `genhtml coverage/lcov.info -o
  coverage/html`.
- A new model field that changes save/load round-trip
  behavior extends the existing round-trip test in that
  game's `_model_test.dart`. Do not create a new test file
  just for the round-trip.
- A new widget has at minimum a pump-and-tap golden-path
  test.
- A new service has at minimum a `init()` test, a read test,
  a write test, and a "before init" test that verifies the
  gate (the read returns the default; the write awaits the
  gate).

---

## 3. Async patterns

- **Always `await Service.instance.init()` in `setUp`** for
  tests that touch the service. `setMockInitialValues({})`
  must be called *before* the first
  `SharedPreferences.getInstance()`.

  ```dart
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameStats.instance.init();
  });
  ```

- **`tester.runAsync` for real `Future`s.** The
  `testWidgets` framework runs in a fake-async zone. Real
  `Future`s from `SharedPreferences` (which hit a platform
  channel) don't resolve in the fake zone. Wrap them:

  ```dart
  await tester.runAsync(() async {
    await GameStats.instance.recordKlondikeWin();
  });
  ```

- **`pump()` after `runAsync`,** not `pumpAndSettle()`. The
  widget tree is in the fake-async zone; an explicit
  `pump()` is what renders the new state.

- **Never `pumpAndSettle()` after a drag.** Scroll physics
  never settle (they keep simulating friction). Use:

  ```dart
  await tester.drag(find.byType(ListView), const Offset(0, -200));
  await tester.pump();                          // settle the drag
  await tester.pump(const Duration(milliseconds: 300)); // settle the inertia
  ```

---

## 4. AAA structure

Prefer Arrange-Act-Assert:

```dart
test('calculates similarity correctly', () {
  // Arrange
  final vector1 = [1, 0, 0];
  final vector2 = [0, 1, 0];

  // Act
  final similarity = calculateCosineSimilarity(vector1, vector2);

  // Assert
  expect(similarity, 0);
});
```

One `expect` per logical assertion (a `containsAll` is one
expect; two separate `contains` are two expects).

---

## 5. Regression test policy

Every bug fix lands with a **failing-then-passing** test in
the same PR.

1. Write the regression test first. It fails on `main`.
2. Apply the fix. The test passes.
3. Verify: revert the fix, run the test — it should fail
   with the bug present. Restore the fix.
4. Commit. "fix(scope): description" with the test in the
   same diff.

If a bug recurs (same class, different instance), add it to
the per-game `_test.dart`. We don't have a separate regression
suite today.

---

## 6. No skipped tests

`skip:` requires an issue link. A skipped test is hidden
debt; the lint or the code review catches it.

`@Tags(['flaky'])` is the right escape hatch for an
intermittent test: the test still runs, but a CI job can be
configured to skip flaky tests on a green-up. The tag
*requires* an issue link and a fix-within-one-sprint promise.

---

## 7. Test discovery

- `find.byKey(const Key('my_widget'))` — most robust. Use
  `ValueKey('snake_case_id')` (const-compatible).
- `find.bySemanticsLabel('...')` — for widgets wrapped in
  `Semantics`.
- `find.byType(MyWidget)` — for type-based lookup; works for
  the widget itself, not children.
- `find.text('Hello')` — last resort; brittle to i18n and
  copy changes.
