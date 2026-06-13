> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Testing Strategy

The "how we test" playbook. Covers the test pyramid, async
patterns, coverage rules, regression policy, and CI integration.

---

## 1. The pyramid

```
        ╱╲
       ╱  ╲         Golden tests (rare, layout-pinned)
      ╱────╲        Integration tests (none today; future)
     ╱      ╲
    ╱────────╲      Widget tests (some)
   ╱          ╲
  ╱────────────╲    Unit tests (most)
```

**Distribution rule of thumb.**

- **Unit tests:** ~80% of test count. Fast (<1ms each). Pure
  Dart. No widget tree.
- **Widget tests:** ~15%. Slower (10-100ms). `testWidgets`,
  pump + tap + verify.
- **Integration tests:** ~5% (none today). Slow (seconds).
  Real device or emulator. End-to-end user flow.
- **Golden tests:** rare. Pin the rendered tree to a
  reference image. Useful for layout-sensitive screens.

Reference: [Flutter testing overview](https://docs.flutter.dev/testing/overview).

---

## 2. Unit tests

- Location: `test/`.
- Naming: `<feature>_test.dart` (e.g. `klondike_model_test.dart`).
- Structure: AAA (Arrange / Act / Assert). One assertion per
  `expect` (where possible).
- No widget tree. No `testWidgets`. No `pumpWidget`.
- Fast: <1ms per test, no `setUp` that hits disk or network.

```dart
test('Gomoku 6-in-a-row wins', () {
  // Arrange
  final model = GomokuModel.empty()
    ..place(0, 0, Player.black)
    ..place(1, 0, Player.black)
    ..place(2, 0, Player.black)
    ..place(3, 0, Player.black)
    ..place(4, 0, Player.black)
    ..place(5, 0, Player.black);

  // Act
  final result = model.place(0, 1, Player.white); // doesn't matter

  // Assert
  expect(result, isA<GomokuWon>());
  expect((result as GomokuWon).winner, Player.black);
});
```

---

## 3. Widget tests

- Location: `test/`.
- Naming: `<feature>_widget_test.dart` (e.g.
  `klondike_widget_test.dart`).
- Wrap in `MaterialApp(home: ...)` so M3, theme, and
  navigation work.
- `tester.pumpWidget(widget)` mounts the tree.
- `tester.pump()` advances one frame.
- `tester.pumpAndSettle()` pumps until the tree is idle —
  **but never after a drag** (scroll physics loops).
- `tester.tap(find.byKey(...))` taps a widget.
- Find by `Key`, by `Semantics`, by text, by type. Keys are the
  most robust.

```dart
testWidgets('Klondike stock tap moves top card to waste', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: KlondikeGameScreen()));
  await tester.pumpAndSettle();

  // The stock pile is in the top-right.
  await tester.tap(find.byKey(const Key('klondike_stock')));
  await tester.pumpAndSettle();

  // The waste pile now has the top card.
  expect(find.byKey(const Key('klondike_waste_top')), findsOneWidget);
});
```

---

## 4. Integration tests

- Location: `integration_test/`.
- Real device or emulator.
- Slow; tag with `@Tags(['integration'])` so they don't run on
  every PR.

**Board Box has no `integration_test/` today.** This section
documents the *future* plan. When we add it (likely for
multi-player handoff, deep-link handling, or Android
backgrounding), the test package and the
`integration_test` Flutter package are the entry point.

Reference: [Flutter integration tests](https://docs.flutter.dev/testing/integration-tests).

---

## 5. Golden tests

- `matchesGoldenFile('goldens/<name>.png')` compares the
  rendered tree to a reference image.
- Tag with `@Tags(['golden'])` so they run on a dedicated CI
  job (golden tests are pixel-sensitive; a slight font or
  rendering change requires a `flutter test --update-goldens`).
- Pin `TextScaler` and `devicePixelRatio` in the test
  `setUp`. Don't let the system font size affect goldens.

```dart
testWidgets('home screen golden', (tester) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 1.0, textScaler: TextScaler.linear(1.0)),
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/home.png'));
});
```

Reference: `flutter_test`'s `matchesGoldenFile`.

---

## 6. Coverage

- `flutter test --coverage` produces `coverage/lcov.info`.
- `genhtml coverage/lcov.info -o coverage/html` renders the
  HTML report.
- **Threshold gate at 80% on changed files** (not the whole
  repo). The CI job reports coverage on the diff; PRs that
  drop coverage on a changed file are flagged.
- Exclude `*.g.dart` / `*.freezed.dart` from coverage (we
  don't use codegen today; this rule is preemptive).

The "on changed files" rule is enforced in the PR review
checklist, not the test runner — `flutter test --coverage`
itself is whole-repo.

---

## 7. Test isolation patterns

### `SharedPreferences.setMockInitialValues({})`

In `setUp`, before every test that touches a service:

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({});
  await GameStats.instance.init();
});
```

`setMockInitialValues` must be called *before* the first
`SharedPreferences.getInstance()`. The `await
GameStats.instance.init()` ensures the singleton's `_ready`
gate is completed.

### `tester.runAsync` for real `Future`s

The `testWidgets` framework runs in a fake-async zone where
`Future.delayed(Duration(seconds: 1))` resolves
immediately. Real `Future`s from `SharedPreferences` (which
hit a platform channel) don't resolve in the fake zone.

```dart
testWidgets('Minesweeper setup shows the per-difficulty record', (tester) async {
  await tester.runAsync(() async {
    await GameStats.instance.recordMinesweeperWin(MinesweeperDifficulty.beginner);
  });

  await tester.pumpWidget(const MaterialApp(home: MinesweeperSetupScreen()));
  await tester.runAsync(() async {
    final state = tester.state<StatsCardStateAccess>(
      find.byKey(StatsCardAccess.widgetKey),
    );
    await state.loadFuture();
  });
  await tester.pump();

  expect(find.text('1'), findsOneWidget);
});
```

### `FakeAsync` for debounce / timer tests

For testing code that uses `Timer` and `Future.delayed`, use
the `fake_async` package. `tester.runAsync` is the Flutter-
testing equivalent; use whichever the test framework needs.

### Mocks with `mocktail`

For interfaces that have many methods, use `mocktail` (no
codegen, unlike `mockito`). We don't have heavy mocking today;
the singletons + a real `SharedPreferences` mock cover the
cases.

---

## 8. Async patterns

The async patterns Board Box uses, and the test rules for each.

### `await GameStats.instance.init()` in `setUp`

Every test that touches `GameStats` (or any other
`_ready`-gated service) must `await` `init()` first. The
`setUp` callback is the right place.

### `await _ready.future` everywhere

`GameStats` getters are `Future<int>`. Tests that read them
`await` the result.

```dart
test('recordKlondikeWin increments the count', () async {
  await GameStats.instance.init();
  expect(await GameStats.instance.getKlondikeWins(), 0);
  await GameStats.instance.recordKlondikeWin();
  expect(await GameStats.instance.getKlondikeWins(), 1);
});
```

### `tester.pump()` after `runAsync`

`runAsync` runs real `Future`s. The widget tree, however, is
in the fake-async zone and needs an explicit `pump()` to
render the new state.

### **Never** `pumpAndSettle` after a drag

Scroll physics animations never settle (they keep simulating
friction). `pumpAndSettle` after a drag will time out the
test in 10 minutes. Use:

```dart
await tester.drag(find.byType(ListView), const Offset(0, -200));
await tester.pump();             // settle the drag
await tester.pump(const Duration(milliseconds: 300)); // settle the inertia
```

---

## 9. Regression test policy

Every bug fix lands with a **failing-then-passing** test in
the same PR.

1. **Write the regression test first.** It should fail on
   `main` (the bug is present).
2. **Apply the fix.** The test passes.
3. **Verify the test would have caught the bug.** Revert
   the fix, run the test — it should fail with the bug
   present. Restore the fix.
4. **Commit.** "fix(scope): description" with the test in
   the same diff.

If a bug recurs (same class, different instance), add it to
a "regression" suite. We don't have a separate suite today;
the per-game `_test.dart` is the home for them.

---

## 10. Flaky test policy

A test is *flaky* if it passes and fails intermittently on
the same commit.

1. **Quarantine with `@Tags(['flaky'])` + an issue link.**
   The test still runs, but a CI job can be configured to
   skip flaky tests on a green-up.
2. **Fix within one sprint.** Flaky tests erode trust in the
   green build. Treat the quarantine as a TODO with a
   deadline.
3. **Never `skip:` without an issue link.** A skipped test
   is a hidden debt; the lint catches it (or a code review
   does).

---

## 11. CI integration

The CI pipeline runs all three gates + coverage upload. See
[`ci-cd.md`](ci-cd.md) §"CI workflow" for the job-by-job
breakdown.

The local loop:

```bash
# Edit a test, edit the code.
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

Run all three. **All must pass with zero failures before
declaring a task done.**

For coverage locally:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# open coverage/html/index.html
```

---

## See also

- [`flutter-dart-style.md`](flutter-dart-style.md) — the lint
  set and rationale.
- [`../design/02-architecture.md`](../design/02-architecture.md) —
  the service pattern (the `_ready` gate) that the async
  patterns test.
- [`ci-cd.md`](ci-cd.md) — the CI pipeline that runs the
  3-gate.
- [`bug-hunt-process.md`](bug-hunt-process.md) — the
  adversarial review that finds the bugs the regression
  tests catch.
