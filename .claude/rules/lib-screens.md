> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# Path-scoped rules — `lib/screens/`

Auto-loaded by Claude Code when you open a file in
`lib/screens/`. Read these rules before writing code in this
area.

For the long form, see
[`../docs/design/02-architecture.md`](../docs/design/02-architecture.md)
§"Screen pattern".

---

## 1. StatefulWidget for async

Any screen that loads data asynchronously (stats, settings,
save state) is a `StatefulWidget`, not a `StatelessWidget`.
The async load happens in `initState`, not in `build`.

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
  ...
}
```

Three rules: async in `initState` (not `build`); `mounted`
guard before `setState`; dimmed placeholder during load.

---

## 2. Dimmed placeholder during load

A `0` rendered immediately and updated a frame later is worse
UX than a placeholder that resolves. The placeholder uses a
`dim: true` parameter on the relevant widget (see `_WinsCard`
in `klondike_setup_screen.dart` and `_StatsCard` in
`minesweeper_setup_screen.dart`).

The `dim` parameter is a `bool`. When `true`, the widget
renders in `colorScheme.onSurface.withOpacity(0.4)` with the
"Loading…" text. When `false`, it renders at full opacity with
the real value.

---

## 3. Navigation

- `Navigator.push(MaterialPageRoute(builder: (_) => const
  GameScreen()))` for forward navigation.
- `Navigator.pop()` to go back; don't use a custom back
  button (the system back gesture / AppBar back is enough).
- For awaitable navigation, `await Navigator.push<...>(...)`
  to receive a return value (e.g. the result of a setup
  screen is a `GameMode`).

---

## 4. Keys on stateful widgets

`const MyWidget({super.key})` — every stateful widget has a
`super.key` in its constructor. The `use_key_in_widget_constructors`
lint catches this.

Tests use keys to find widgets by `find.byKey(const
Key('my_widget'))`. Use `ValueKey('snake_case_id')` (const-
compatible). `UniqueKey` is not const — only use it when you
need a new key on every build (rare).

---

## 5. Don't write to SharedPreferences

Widgets never write gameplay settings or stats to
`SharedPreferences` directly. They go through `GameStats` or
`SettingsService`. The services own the keys (private statics).

If a screen needs a setting that no service exposes, add a
method to the relevant service first; do not read/write
`SharedPreferences` from a widget.

---

## 6. A11y

- 48dp / 44pt touch targets (Android / iOS).
- 4.5:1 contrast for text (3:1 for large text or UI
  components).
- `Semantics(label: ...)` on every interactive widget.
  `tooltip` on every `IconButton`.
- All 4 states (empty / loading / error / success) on every
  list or state-driven screen.
- `prefers-reduced-motion` respected — animations collapse
  when the system asks.
- 200% text scaling doesn't break the layout.
- Test with TalkBack / VoiceOver before merging.
