> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# 04 — UI/UX Principles

The "why" behind the design system. The operational rulebook. This
doc links principles to the design system tokens in
[`03-design-system.md`](03-design-system.md); for citations, see
[`../engineering/ui-ux-reference.md`](../engineering/ui-ux-reference.md).

---

## Foundations

**Nielsen's 10 usability heuristics** (Jakob Nielsen, NN/g).
The TL;DR — every UI in Board Box must satisfy:

1. **Visibility of system status.** Loading? Show it. Saved? Show
   it. (See "Empty / loading / error / offline states" below.)
2. **Match between system and the real world.** "Stock pile" not
   "discard array". "Deal" not "distribute". Minesweeper uses
   "flag" not "mark".
3. **User control and freedom.** Back button always works. Undo
   is available in games that allow it.
4. **Consistency and standards.** Same icon, same word, same
   action. See "Iconography" in `03-design-system.md`.
5. **Error prevention.** Confirm destructive actions. Disable
   invalid moves before the user tries them.
6. **Recognition rather than recall.** Show the move history, the
   score, the timer. Don't make the user remember.
7. **Flexibility and efficiency.** Power users: keyboard shortcuts.
   Klondike has `Ctrl+Z` for undo, `H` for hint, `A` for
   auto-complete.
8. **Aesthetic and minimalist design.** No decoration. The board
   is the board.
9. **Help users recognize, diagnose, recover from errors.** "You
   can't move there because…" not "Invalid move."
10. **Help and documentation.** Onboarding is the help.

**Don Norman's 7 design principles** (The Design of Everyday
Things). The TL;DR:

1. **Discoverability.** Can the user see what actions are
   available? Visible buttons, not hidden gestures.
2. **Feedback.** Every action gets a result in <100ms. Snackbar
   on save, haptics on tap.
3. **Conceptual model.** The user knows what the app is doing.
   "Stock pile → waste pile" is a mental model; expose it.
4. **Affordances.** Buttons look pressable. Cards look tappable.
   Sliders look draggable.
5. **Signifiers.** A "+" button is a sign for "add". A "…" button
   is a sign for "more".
6. **Mappings.** The relationship between control and effect is
   clear. The drag direction matches the drop direction.
7. **Constraints.** You can't move a King like a pawn. The model
   enforces it; the UI shows it.

**Material 3 foundations.** M3 is the base design language;
[`03-design-system.md`](03-design-system.md) is the implementation.
We use the M3 dynamic color scheme and component set without
customization except for game-specific accents.

**Apple Human Interface Guidelines.** We follow HIG for
iOS-specific behaviors (44pt minimum touch target, safe-area
insets, system back-gesture) even though the primary target is
Android. Reason: many Board Box players use an iPad.

---

## Mobile-first rules

- **48dp / 44pt touch targets.** Material 3 says 48dp. HIG says
  44pt. Use 48dp on Android, 44pt on iOS. Wrap in `Material(
  color: Colors.transparent, child: InkWell(borderRadius: ...,
  child: SizedBox(width: 48, height: 48, ...)))`.
- **Safe area.** `SafeArea` wraps every `Scaffold` body. Notch,
  home indicator, status bar.
- **Thumb zones.** Primary actions in the bottom third of the
  screen. Secondary actions (back, settings) in the top
  corners. Reference: Hoober's thumb-zone research.
- **One-handed use.** The most common interaction (move, reveal)
  must be reachable with one hand. The "back" gesture is
  the system back, not a UI button.
- **Gesture conflicts to avoid.** No edge-swipes that conflict
  with the system back gesture. No two-finger gestures. No
  long-press as the only way to access a feature (must also be
  in a menu).

---

## Accessibility (WCAG 2.2 AA)

- **Contrast.** Text: 4.5:1 minimum. Large text (≥18pt or
  ≥14pt-bold): 3:1. UI components and graphics: 3:1.
  Verifiable: WebAIM Contrast Checker on the
  `colorScheme.onPrimary` / `colorScheme.primary` pair, etc.
- **Text scaling.** Layouts must survive 200% text scaling.
  Wrap `MaterialApp` in:
  ```dart
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
    child: child!,
  ),
  ```
  and run through every screen.
- **Focus order.** Logical, top-to-bottom, left-to-right. Test
  with keyboard nav (web) and TalkBack (Android) / VoiceOver
  (iOS).
- **Semantic labels.** Every `IconButton` has a `tooltip` or is
  wrapped in `Semantics(label: '...')`. Every `Image` has a
  `semanticLabel`. Every interactive cell in a game board has
  a `Semantics(label: 'Row 3, column 2, X')`.
- **Touch target spacing.** 8dp gap between adjacent touch
  targets, even when the targets themselves are 48dp.
- **Motion reduction.** See [`03-design-system.md`](03-design-system.md) §"Motion". When `prefers-reduced-motion` is
  on, transitions collapse; verify in Settings → Accessibility
  → Reduce Motion.
- **Don't rely on color alone.** Minesweeper flags are red, but
  also have a 🚩 shape / icon. Mines are not just red dots; they
  are `Icons.bug_report` or a different cell state.

---

## Empty / loading / error / offline states

Every list and state-driven screen must define all four.

- **Empty.** A descriptive message + a primary action. "No
  saved games yet. Start a new one?" with a "New Game" button.
- **Loading.** A skeleton or a dimmed placeholder. *Never* a
  blank screen. Never a flash of empty content. The placeholder
  uses a `dim: true` parameter on the relevant widget (see
  `_WinsCard` in `klondike_setup_screen.dart`).
- **Error.** Inline error with a retry action. "Couldn't load
  stats. [Retry]". Use `colorScheme.error` for the message.
- **Offline.** "No internet connection" with a note. (Board Box
  is local-only; "offline" is the default state, not an error.
  The "offline" pattern is for future online features.)

**Patterns.**

- **Skeleton vs spinner** (NN/g research). Skeleton for lists
  with predictable shape. Spinner for "wait, this is taking a
  second". Spinner is *never* infinite without a timeout or
  retry.
- **Snackbar undo.** "Game reset. [Undo]". 4-second timeout.
- **Optimistic UI.** Update the UI immediately, reconcile with
  the server. Board Box has no server; the analog is
  "update the model immediately, persist asynchronously with
  the `GameStats._ready` gate."
- **Error banner vs blocking dialog.** Banner for "we couldn't
  save your move, but the game continues". Blocking dialog
  only for "we cannot continue without your input".

---

## Forms & input

- **Inline validation.** Validate on blur, not on every
  keystroke. Show the error below the field in
  `colorScheme.error`.
- **IME action.** `TextInputAction.done` for single-field, `.next`
  for multi-field, `.submit` for the final field. `onSubmitted`
  on the final field triggers the primary action.
- **Autofill hints.** `AutofillHints.email`, `AutofillHints.name`,
  etc. iOS and Android offer the user their stored data.
- **Error tone.** "Email is required", not "Invalid input". Tell
  the user what's wrong and how to fix it.
- **No surprise keyboard.** Use `keyboardType:` explicitly
  (`TextInputType.emailAddress`, `TextInputType.number`).

---

## Feedback & microinteractions

- **Haptics.** Tap on game cells: light. Win: success. Loss:
  error. Use `HapticService` (a singleton in
  `lib/services/haptic_service.dart`).
- **Sound.** Off by default. Toggleable in settings. If on,
  one short tone per game-event, no loops.
- **Visual feedback for every state change.** Tap → ripple.
  Move → cell briefly highlights. Save → snackbar.
- **Delight without delay.** A 200ms win animation is fine. A
  2000ms win animation is a bug.

---

## Information architecture

- **Flat top-level.** Max 2 levels deep. Home → Game → Setup.
  No "Settings → Display → Advanced → Theme". Fold the
  advanced into the simple, or hide behind a "Show advanced"
  toggle.
- **Primary action visible without scroll.** The "Play" button
  must be above the fold. Always.
- **Search prominent on >5-item lists.** The home screen has
  9 games; search-by-name is in the app bar. Setup screens
  have 3-5 difficulty cards; no search needed.

---

## Onboarding & first-run

- **Sample data on first run.** Klondike has a "Try a deal"
  tutorial overlay the first time the user opens the game.
  Dismissable, never blocking.
- **Progressive disclosure.** Show the basic controls first.
  Hint, auto-complete, undo are in a "more" menu.
- **Skip always available.** Onboarding is skippable. Tutors
  are dismissable.
- **No forced login.** Board Box has no accounts. No
  "sign in to continue" dialogs.

---

## Localization & RTL

- **`package:intl`** for date/number formatting.
  **`flutter gen-l10n`** for the message catalog.
- **No hard-coded strings** in widgets. Every visible string
  lives in `lib/l10n/app_en.arb` (and other locales).
  Verifiable: `grep -rn "'[A-Z][a-z]" lib/screens/ lib/games/
  | grep -v ".arb"` should return nothing.
- **RTL mirroring.** `EdgeInsetsDirectional.fromSTEB(...)` not
  `EdgeInsets.fromLTRB(...)`. `Row` children order is
  reversed automatically in RTL.
- **Plurals (CLDR).** "1 win" / "2 wins". Use the ICU
  `plural` rule, not string interpolation.
- **Text expansion.** German strings are ~30% longer than
  English. Test with a German locale; the layout must not
  truncate.

---

## Heuristic evaluation checklist

The reviewer runs this before approving a UI PR. 10 points,
pass = all 10.

- [ ] **Status visible.** Loading / saving / error are shown.
- [ ] **Real-world language.** "Stock pile", not "discard
      array".
- [ ] **User control.** Back works. Undo works.
- [ ] **Consistency.** Same icon, same word, same action.
- [ ] **Error prevention.** Destructive actions confirm.
      Invalid moves are disabled, not just rejected.
- [ ] **Recognition over recall.** Score / time / history are
      shown.
- [ ] **Efficiency.** Keyboard shortcuts exist for power users.
- [ ] **Aesthetic.** No decoration. The board is the board.
- [ ] **Errors are helpful.** "You can't move there because…"
      not "Invalid move."
- [ ] **Help exists.** Onboarding is dismissable but reachable.

---

## See also

- [`03-design-system.md`](03-design-system.md) — the tokens the
  principles implement.
- [`07-pr-review-checklist.md`](07-pr-review-checklist.md) §"UI/UX
  review" — what to check at PR review time.
- [`../engineering/ui-ux-reference.md`](../engineering/ui-ux-reference.md)
  — citations and source URLs.
