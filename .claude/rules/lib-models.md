# Path-scoped rules — `lib/models/`

Auto-loaded by Claude Code when you open a file in
`lib/models/`. Read these rules before writing code in this area.

For the long form, see
[`../docs/design/02-architecture.md`](../docs/design/02-architecture.md).

> **Imported from board_box.** This file is a card_box adaptation
> of `board_box/.claude/rules/lib-games.md`. The structure and
> rules are universal Flutter/Dart practice; the path (`lib/games/`
> in board_box, `lib/models/` in card_box) and the example file
> names are card_box-specific.

---

## 1. Model purity

Files in `lib/models/` MUST be pure Dart — no
`package:flutter/*` imports. The model layer must be unit-testable
without a widget tree.

**Sole exception:** if a model needs a `rootBundle` read (rare in
card_box), the asset loader is its own file (e.g. `*_assets.dart`)
and may import `package:flutter/services.dart`. Returned types are
still pure-Dart value objects.

**Verifiable:**
```bash
grep -l "import 'package:flutter/" lib/models/[a-z]*_model.dart
# Must print nothing.
```

If it prints, the model is importing Flutter and is now
un-unit-testable. Move the widget code to `lib/widgets/`.

---

## 2. File shape

The minimum for a new model:

- `<name>_model.dart` — pure Dart. State, transitions, validation,
  save/load, toJson / fromJson.
- A `lib/services/` companion if the model has any side effects
  (DB writes, platform calls).

Models never own timers, sensors, or `BuildContext`.

---

## 3. State pattern

State-bearing models use a sealed `*State` hierarchy where it
adds value. Not bare enums.

```dart
sealed class CardImportState {}
final class CardImportIdle extends CardImportState { ... }
final class CardImportScanning extends CardImportState { ... }
final class CardImportFailed extends CardImportState { ... }
```

All state classes are immutable. State transitions return *new*
model instances; never mutate. `switch (state)` over a sealed
class is exhaustive at compile time.

---

## 4. Test mirror

Every `lib/models/<name>_model.dart` has a corresponding
`test/models/<name>_model_test.dart` covering:

- Initial state
- Valid transitions (one happy path)
- Failure path (e.g. invalid input, missing field, encoding error)
- Round-trip for `toJson` / `fromJson` (extending the existing
  test, not a new file)

---

## 5. Lint set

The 18 lints in [`analysis_options.yaml`](../../analysis_options.yaml)
apply. Most relevant to this area:

- `unawaited_futures` — every `Future` is `await`ed or wrapped
  in `unawaited(...)`. The card_database writes are an
  asynchronous critical path; missing an `await` is the easiest
  way to ship a dropped write.
- `prefer_final_locals` — `final` for locals; `var` only when
  reassigned.
- `always_use_package_imports` — `package:common_games/...`
  only.
