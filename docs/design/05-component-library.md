> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 05 — Component Library

Catalog of in-repo widgets. Single place to look up "does this
exist?" — and the file path / props / state matrix for each.

The list is alphabetical within each section. When you add a new
component, add it here, add a `<name>_test.dart`, and add a row to
the component state matrix in
[`03-design-system.md`](03-design-system.md) §"Component state
matrix".

---

## Layouts

### `Scaffold`

File: `package:flutter/material.dart` (built-in).
Used in: every screen.
Props: `appBar`, `body`, `floatingActionButton`, `drawer`,
`bottomNavigationBar`, `backgroundColor`.
Rule: `body` is wrapped in `SafeArea`. Use the M3 default for
`backgroundColor` (don't override).

### `SafeArea`

File: built-in.
Used in: every `Scaffold.body`.
Props: `top`, `bottom`, `left`, `right`, `minimum`,
`child`.
Default: `SafeArea(child: ...)` — all edges.

### `Padding` / `SizedBox`

Padding for inline, `SizedBox` for between-widgets gaps.
Use the spacing tokens from `03-design-system.md` (4dp grid).
See the "Spacing tokens" section for the values.

---

## Game widgets

### `TicTacToeBoard`

File: `lib/games/tictactoe/tictactoe_board.dart`.
Props: `model` (TicTacToeModel), `onTap` (cell index),
`aiEnabled`, `aiDifficulty`.
State machine: `TicTacToePlaying` → `TicTacToeWon` / `TicTacToeDraw`.
A11y: each cell has a `Semantics(label: 'Row $r, column $c,
$X')`.

### `GomokuBoard`

File: `lib/games/gomoku/gomoku_board.dart`.
Props: `model`, `onTap`, `aiEnabled`, `aiDifficulty`.
State: `GomokuPlaying` / `GomokuWon` (with the winning line).
A11y: each intersection is a 48dp target with
`Semantics(label: 'Intersection $i,$j, empty')`.

### `CheckersBoard`

File: `lib/games/checkers/checkers_board.dart`.
Props: `model`, `onTap`, `onDrag` (multi-jump uses drag, not
tap).
State: `CheckersPlaying` / `CheckersWon`.
A11y: pieces have `Semantics(label: 'Red king on row 3,
column 4')`.

### `DotsBoard`

File: `lib/games/dots_and_boxes/dots_board.dart`.
Props: `model`, `onLineTap`.
State: `DotsPlaying` / `DotsWon` (box count).
A11y: lines are 48dp, boxes show "claimed by red, claimed by
blue" labels.

### `KlondikeBoard`

File: `lib/games/klondike/klondike_board.dart`.
Props: `model`, `onMove` (drag-and-drop, foundation tap, stock
tap).
State: `KlondikePlaying` / `KlondikeWon`.
A11y: every card has `Semantics(label: 'Seven of hearts,
red, face up, in column 3')`. Drag handles have spoken-form
hints.

### `KaruroBoard`

File: `lib/games/karuro/karuro_board.dart`.
Props: `puzzle`, `onCellEdit`, `onCheck`, `onReveal`.
State: `KaruroPlaying` / `KaruroWon`.
A11y: each cell has `Semantics(label: 'Numeric run, clue 12,
empty')` or `Semantics(label: 'Word run, _ _ _ _, filled A')`.

### `MinesweeperBoard`

File: `lib/games/minesweeper/minesweeper_board.dart`.
Props: `model`, `onReveal`, `onFlag`, `onChord`.
State: `MinesweeperPlaying` / `MinesweeperWon` /
`MinesweeperLost`.
A11y: each cell has `Semantics(label: 'Row 3, column 4, 2
adjacent mines, revealed')` or `'flagged'` or `'unrevealed,
long-press to flag'`. Long-press is the only way to flag; the
screen-level a11y hint says "long-press to flag, double-tap to
reveal".

### `OthelloBoard`

File: `lib/games/othello/othello_board.dart`.
Props: `model`, `onTap`, `validMoves` (highlighted cells).
State: `OthelloPlaying` / `OthelloWon` / `OthelloPass`.
A11y: each cell has `Semantics(label: 'Row 2, column 3,
empty, valid move, would flip 3 pieces')`.

### `SudokuBoard`

File: `lib/games/sudoku/sudoku_board.dart`.
Props: `model`, `onCellTap`, `onNumberTap`, `onErase`.
State: `SudokuPlaying` / `SudokuWon` / `SudokuLost`
(mistake limit hit).
A11y: each cell has `Semantics(label: 'Row 1, column 5,
value 7, given')` or `'value 3, user-entered'`. Selected
cell + peer row/column/box have visible highlights.

---

## Shared widgets

### `GameStatusBar`

File: `lib/widgets/game_status_bar.dart`.
Props: `leftLabel`, `centerLabel`, `rightLabel`,
`onLeftTap`, `onCenterTap`, `onRightTap`.
Used in: every game screen (timer, mine counter, score,
etc.).
States: default / hover / pressed / disabled.
A11y: each label is a 48dp `InkWell` with `Semantics`.

### `CardView`

File: `lib/widgets/card_view.dart`.
Props: `rank`, `suit`, `faceUp`, `width`, `height`.
Used in: Klondike.
States: face-up / face-down (flips with an animation).
A11y: `Semantics(label: 'Seven of hearts, red, face up')` or
`'face down'`.

### `DifficultyCard`

File: `lib/widgets/difficulty_card.dart`.
Props: `title`, `subtitle`, `bestTime`, `wins`, `losses`,
`onTap`, `dim` (loading).
Used in: Minesweeper, Sudoku setup screens.
States: default / hover / pressed / focus / disabled /
loading / dim.
A11y: `Semantics(label: 'Beginner, best 00:42, 3 wins, 0
losses')`.

### `StatsCard`

File: `lib/widgets/stats_card.dart`.
Props: `wins`, `losses`, `draws`, `dim`.
Used in: Klondike setup screen, others.
States: default / loading (dim).
A11y: `Semantics(label: '3 wins, 1 loss, 0 draws')`.

### `AppLockOverlay`

File: `lib/widgets/app_lock_overlay.dart`.
Props: `child` (the gated widget), `isLocked`, `onUnlock`.
Used in: the home screen during a backgrounded-app lock
(future feature).
States: locked / unlocked.

---

## Theming entry points

### `app_theme.dart`

File: `lib/theme/app_theme.dart`.
Exports: `AppTheme.light()` and `AppTheme.dark()`,
both returning `ThemeData` with the M3 dynamic color scheme
seeded from `0xFF5C35CC`.
Use: `MaterialApp(theme: AppTheme.light(), darkTheme:
AppTheme.dark(), themeMode: ...)`.
The full token list is in
[`03-design-system.md`](03-design-system.md).

### `Theme.of(context)`

Use everywhere. `Theme.of(context).colorScheme.primary`,
`Theme.of(context).textTheme.bodyLarge`, etc. Never hardcode
colors or sizes inline.

---

## Form widgets

### Text fields

- `TextField` with `decoration: InputDecoration(labelText:
  ..., border: OutlineInputBorder())`.
- `decoration: InputDecoration(hintText: ...)` for
  placeholders.
- `decoration: InputDecoration(errorText: ...)` for
  validation errors.
- `keyboardType:` and `textInputAction:` always explicit.
- `autofillHints:` always explicit.
- `validator:` always defined; the form's `autovalidateMode`
  is `AutovalidateMode.onUserInteraction`.

### Validation display

- Inline below the field, in `colorScheme.error`.
- `decoration: InputDecoration(errorText: ...)` is the
  M3-correct way.
- No popovers, no dialogs for inline errors.

---

## Feedback widgets

### `SnackBar`

- Use `ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text(...), duration: Duration(seconds: 4),
  action: SnackBarAction(label: 'Undo', onPressed: ...)))`.
- Max one visible at a time (queue the rest).
- 4-second default. 8-second for "Undo" actions.
- Never a critical-error carrier (use a dialog for that).

### `AlertDialog`

- For blocking decisions: "Delete saved game?" with Cancel
  and Delete.
- For errors that prevent continuing: "Storage full. Free up
  space and try again." with an OK button only.
- Title is `titleLarge`, body is `bodyMedium`.
- `actions:` always on the right (or bottom in RTL).

### Error banner

- Inline at the top of the affected screen.
- `Container` with `colorScheme.errorContainer` background.
- Dismissable, but not auto-dismissed (the user needs to
  read it).

---

## How to add a new component

1. **Implement.** Create the widget in `lib/widgets/`
   (shared) or `lib/games/<name>/` (game-specific).
2. **Catalog.** Add a row above, with file path, props,
   state machine, and a11y notes.
3. **Test.** Create `test/<name>_test.dart`. Pump, tap, and
   verify the state matrix (every state, not just default).
4. **State matrix.** Add a row to
   [`03-design-system.md`](03-design-system.md) §"Component
   state matrix".
5. **Screenshot.** Take a screenshot (light + dark) and
   add it to the catalog (or to a `docs/screenshots/`
   directory if we add one).
6. **Golden test.** If the component is layout-sensitive,
   add a golden test pinned to `devicePixelRatio: 1.0` and
   `textScaler: 1.0`.

---

## See also

- [`02-architecture.md`](02-architecture.md) — where these
  components fit in the layer model.
- [`03-design-system.md`](03-design-system.md) — the tokens
  these components use.
- [`04-ui-ux-principles.md`](04-ui-ux-principles.md) §"Forms
  & input" / §"Feedback & microinteractions" — the rules the
  form + feedback widgets implement.
