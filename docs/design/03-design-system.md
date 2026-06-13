> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 03 — Design System

The visual + interaction contract. Sole source of truth for tokens
in Board Box. The Material 3 dynamic color scheme is the foundation;
the tokens below are how we name and use it.

---

## What is a token

A token is a named design decision. Three layers:

1. **Primitive.** Raw values. `#5C35CC`, `16`, `200ms`. Never used
   directly in code.
2. **Semantic.** Purpose-bound aliases. `colorScheme.primary`,
   `spacing.lg`, `motion.normal`. Used in widgets.
3. **Module.** Game-specific accents. `theme.gomoku`,
   `theme.klondike`, `theme.minesweeper`. One per game, optional.

This three-layer model is the W3C Design Tokens spec
([W3C Design Tokens](https://www.w3.org/TR/design-tokens/)). We
follow the shape but keep the file count down — Board Box has
`lib/theme/app_theme.dart` and `Theme.of(context).colorScheme` /
`textTheme` from M3, and that's it.

---

## Color tokens

**Source of truth:** `lib/theme/app_theme.dart` and the M3 dynamic
scheme derived from the seed.

| Token | Value | Used for |
|---|---|---|
| **seed** | `0xFF5C35CC` | M3 seed; drives the dynamic palette |
| `colorScheme.primary` | seed-derived | Primary actions, focus rings |
| `colorScheme.onPrimary` | contrast on `primary` | Text/icon on primary surfaces |
| `colorScheme.secondary` | seed-derived, less saturated | Secondary actions, accents |
| `colorScheme.surface` | white (light) / near-black (dark) | App background |
| `colorScheme.onSurface` | high-contrast text | Body text on `surface` |
| `colorScheme.surfaceContainerHigh` | M3 surface tint | Cards, dialogs |
| `colorScheme.outline` | dividers, borders | 1px dividers, input borders |
| `colorScheme.error` | M3 default red | Destructive actions, error states |
| `colorScheme.onError` | contrast on `error` | Text on error surfaces |
| `colorScheme.tertiary` | seed-derived | Success, completion states |

**Module accents.** Per-game accents are derived from
`colorScheme.tertiary` with an M3 `Color.lerp` to shift hue. Today
this is done ad-hoc in the per-game `*_board.dart` files. If we
add a 4th game, extract a `gameAccent(GameType)` helper into
`app_theme.dart`.

**Dark theme.** `colorScheme.brightness` follows the system. The
`SettingsService` allows a manual override (`light` / `dark` /
`system`). When overridden, wrap `MaterialApp` in a `Theme` whose
`colorScheme` is built with `Brightness.dark`.

**Verifiable.**

```bash
# No hardcoded Color(0xFF...) outside lib/theme/app_theme.dart.
grep -rn "Color(0x" lib/ | grep -v "lib/theme/app_theme.dart"
```

If that command ever prints a file, that file should switch to a
`colorScheme.*` token.

---

## Typography tokens

**Source of truth:** `Theme.of(context).textTheme` from M3, which
gives us the 5-step scale.

| Token | Default size | Default weight | Used for |
|---|---|---|---|
| `displayLarge` | 57 | 400 | Hero numbers (score, timer) |
| `displayMedium` | 45 | 400 | Game-end banners |
| `displaySmall` | 36 | 400 | (Reserved) |
| `headlineLarge` | 32 | 400 | Screen titles |
| `headlineMedium` | 28 | 400 | Section titles |
| `headlineSmall` | 24 | 400 | Card titles |
| `titleLarge` | 22 | 500 | List-tile primary text |
| `titleMedium` | 16 | 500 | Dialog titles |
| `titleSmall` | 14 | 500 | (Reserved) |
| `bodyLarge` | 16 | 400 | Body text |
| `bodyMedium` | 14 | 400 | Secondary body |
| `bodySmall` | 12 | 400 | Captions, hints |
| `labelLarge` | 14 | 500 | Button labels |
| `labelMedium` | 12 | 500 | Tab labels |
| `labelSmall` | 11 | 500 | Overline |

**Rules.**

- Use `Theme.of(context).textTheme.*` — never `TextStyle(fontSize:
  ...)` inline.
- `const Text('...')` does not need a style. Default style is
  `bodyMedium`, which is correct.
- For custom text styles, derive from the M3 scale (don't invent
  new sizes): `Theme.of(context).textTheme.bodyLarge!.copyWith(
  fontWeight: FontWeight.w700)`.

---

## Spacing tokens

**4dp grid.** All padding, margin, and gap values come from this
scale. Never use raw `SizedBox(height: 13)`.

| Token | Value | Used for |
|---|---|---|
| `xs` | 4 | Tight icon-text gap |
| `sm` | 8 | List-item padding |
| `md` | 12 | Section gap |
| `lg` | 16 | Screen edge padding |
| `xl` | 24 | Card padding |
| `2xl` | 32 | Hero spacing |
| `3xl` | 48 | Empty-state vertical centering |
| `4xl` | 64 | Splash centering |

**Verifiable.**

```bash
# No raw padding/margin values not in the scale.
grep -rE "(padding|margin): EdgeInsets\.(all|symmetric|fromLTRB)\([^)]*[0-9]+" lib/ \
  | grep -vE "(0|4|8|12|16|24|32|48|64)"
```

If that prints anything, replace with a token.

---

## Elevation tokens

| Token | Value | Used for |
|---|---|---|
| `level0` | 0 | Flat surfaces (game board) |
| `level1` | 1 | Subtle lift (chips, list items) |
| `level2` | 3 | Cards |
| `level3` | 6 | Floating action button, snackbar |
| `level4` | 8 | Dialog |
| `level5` | 12 | Modal sheet (top of stack) |

Use M3's `Card(elevation: ...)`, `Material(elevation: ...)` —
never a `Container` with a `BoxShadow` that mimics elevation.

**Why no custom shadows?** M3 elevation is tonal in light mode
(surface tint) and shadow in dark mode. Mimicking it with
`BoxShadow` breaks dark mode.

---

## Motion tokens

| Token | Value | Used for |
|---|---|---|
| `fast` | 100ms | Tap feedback, hover, focus ring |
| `normal` | 200ms | Card expand, list reorder |
| `slow` | 300ms | Page transition, dialog open |
| `emphasizedDecelerate` | M3 default | Element entering the screen |
| `emphasizedAccelerate` | M3 default | Element leaving the screen |
| `standard` | M3 default | State change (color, opacity) |

**Rule.** Respect `prefers-reduced-motion`. If the user has
reduced motion on, the system has already collapsed our animation
durations — verify with a manual test (Settings → Accessibility →
Reduce Motion).

**Verifiable.** Wrap animations in a check:

```dart
final reduced = MediaQuery.of(context).enableAccessibleAnimations;
// Or for older code:
final reduced = MediaQuery.of(context).disableAnimations;
```

---

## Component state matrix

Every stateful component must define the look for every state.
The 8 states × every component is in the component catalog
([`05-component-library.md`](05-component-library.md)). The
minimum required states are:

- **default** — at rest
- **hover** — pointer over (desktop, web)
- **pressed** — tap down
- **focus** — keyboard focus ring (must be visible, not removed)
- **disabled** — non-interactive (lower contrast, no hover)
- **loading** — async work in progress
- **error** — operation failed
- **success** — operation completed (where applicable)

For each, the doc lists the exact color, text, icon, and animation.

**Rule.** Never show a stale state. If the data is loading, show
the loading state. If it errored, show the error state with a
retry action. If it succeeded, show the success state. A button
that says "Save" and stays gray forever is a bug.

---

## Iconography

`Icons.*` from `package:flutter/material.dart`. No custom icon
font in v1. Sizes:

- `Icons.size_18` — inline with body text
- `Icons.size_24` — default
- `Icons.size_32` — list-tile leading
- `Icons.size_48` — empty-state icon
- `Icons.size_96` — splash / error

**Rule.** Use the same icon for the same meaning everywhere.
`Icons.refresh` is "restart", `Icons.undo` is "undo", `Icons.home`
is "back to home". Don't mix `Icons.refresh` and `Icons.replay` for
the same action.

---

## Dark mode

`colorScheme.brightness` follows the system by default.
`SettingsService` allows `light` / `dark` / `system`. When
overridden:

```dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: settings.themeMode, // ThemeMode.system / light / dark
)
```

**Test rule.** Every screen must be manually checked in both
light and dark before merge. The home screen, every game board,
and the setup cards are the high-traffic ones.

**Color rule.** Never use `Theme.of(context).brightness ==
Brightness.light` in a widget. Use the appropriate `colorScheme.*`
token; the scheme flips automatically.

---

## Token version policy

- **Additive changes** (new token, new module accent) — OK in a
  minor version, no deprecation path needed.
- **Renames or removals** — mark `@Deprecated('Use <new>')` for one
  release, then remove. Document the deprecation in `CHANGELOG.md`.
- **Value changes** (e.g. `lg` from 16 to 20) — a breaking change.
  Discuss in an issue first. Touches every screen that uses `lg`.

---

## See also

- [`lib/theme/app_theme.dart`](../../theme/app_theme.dart) — the
  source of truth for `ThemeData`.
- [`04-ui-ux-principles.md`](04-ui-ux-principles.md) — the
  principles the tokens implement.
- [`05-component-library.md`](05-component-library.md) — the
  state-matrix per component.
