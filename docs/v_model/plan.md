# V-Model Development Plan

## Purpose

Use the V-model to keep the app honest: user needs and system requirements on
the left side, implementation at the bottom, and explicit verification on the
right side.

## V-Model Stages

| Left side artifact | Development activity | Right side verification |
| --- | --- | --- |
| User needs | Stakeholder interviews, app-store/GitHub research | User acceptance tests |
| Concept of operations | Define actors, modes, scenarios, constraints | Operational scenario validation |
| Operational workflows | Define end-to-end user flows and edge cases | Workflow acceptance tests |
| System requirements | Functional, safety, privacy, platform constraints | System tests |
| Architecture | Flutter app, storage, scanner, security design | Integration tests |
| Module design | Card model, vault, scanner, search, import/export | Unit/widget tests |
| Implementation | Flutter code and platform configuration | Static analysis, tests, builds |

## Initial Milestones

1. Requirements baseline
   - Define target card types.
   - Separate "store and present" features from "read/write/emulate" features.
   - Capture Android/iOS limits early.
2. Feasibility prototype
   - Flutter app shell.
   - Local encrypted card database.
   - Camera import for card photos and barcode/QR.
   - NFC tag read experiment on Android and iOS.
3. MVP
   - Add, edit, search, group, and archive cards.
   - Store front/back images.
   - Store barcode/QR payloads.
   - Store NFC metadata when readable.
   - Export/backup data safely.
4. Validation
   - Test with real card categories.
   - Verify privacy behavior.
   - Publish as free/open-source app if the MVP is useful and safe.

## Working Assumptions

- We will use Flutter because `board_box` already uses it across Android and
  iOS.
- The first release should be offline-first and should not require a paid cloud
  service.
- Any NFC/RFID functionality must be described by capability, not wishful
  product language.

## Accessibility Widget Initiative (DR-014)

Initiative: 4 tiers of accessibility widgets, ordered by
"highest stakes use case first." The central problem is the
cashier-facing barcode-presentation flow, which is unusable
by non-sighted users today. The widgets below attack that
failure mode directly. Reference: DR-014.

### Tier 1 — direct fixes for the "tell me my member number" flow

1. **`AnnounceableBarcode`** (DR-014.a — first deliverable).
   Wraps `BarcodeWidget` in `Semantics` whose label chunks
   the payload the way a sighted user sees it (groups of 4
   for EAN/Code 128, sentence-paused for alphanumeric). A
   44 dp `IconButton` with `tooltip: 'Read aloud'` triggers
   the injected `TtsService`. Always renders the read-aloud
   button; the TTS *call* is gated by a Settings toggle.
2. **`CardDetailVoiceSummary`** (DR-014.b). A single
   `Semantics` block at the top of `CardDetailScreen` that
   reads: "Loyalty card. Supermarket X. Member number 4844
   4123 4. Expires December 2027. Favorite." No "image" or
   "container" — just the facts in a single spoken
   sentence. A long-press anywhere on the card triggers it.
3. **`LargePrintBarcodeOverlay`** (DR-014.c). A fullscreen
   modal that takes the current card's barcode, scales it
   4× by default, and offers 6× / 8× / 12× steps. A single
   `IconButton` with `tooltip: 'Larger'`; screen-reader
   announces the size step.

### Tier 2 — finding the right card without seeing the list

4. **`CardSearchWithVoice`**. A `TextField` with a
   `tooltip: 'Search by name'` and a mic `IconButton` that
   uses `speech_to_text`. Search must be the *first*
   focusable element on the home screen.
5. **`CardQuickSwitcher`**. A two-finger swipe / hardware-
   volume-key shortcut that cycles through `favorites` in
   order, announcing each. Backed by `Shortcuts` + `Actions`.
6. **`CardListWithAudioCues`**. A `ListView` variant that
   plays a 200 ms tone whose pitch encodes the category
   (loyalty = C4, transit = E4, etc.) on `focusChange`.
   Optional — must be a setting, never on by default.

### Tier 3 — operating the app without aiming

7. **`ScanWithHaptic`**. NFC-first, camera-fallback scan
   flow. Haptic feedback fires the instant a valid barcode
   is in view. Voice cue announces the decoded value.
8. **`AppLockScreenWithVoice`**. Voice-PIN entry via
   `speech_to_text` with a strict 4-digit grammar, on-device
   only (no `INTERNET` permission). Opt-in toggle; the
   keypad is the default; the voice is the default for
   blind users.
9. **`ReadOutLoudToggle`**. A Settings switch that wraps
   every screen in an `AccessibilityAnnouncer` reading
   the new screen's primary headline on push. Defaults to
   off.

### Tier 4 — composition and code infrastructure

10. **`AccessibilityAnnouncer` mixin.** A single class
    every screen can mix in that takes a `BuildContext` +
    a string and pipes it through `Semantics(liveRegion:
    true)` + an optional `flutter_tts` call. Avoids the
    "every screen rolls its own announce" pattern.
11. **`HighContrastTheme` widget.** A `Theme` wrapper with
    WCAG AAA contrast (7:1). Settings toggle; tested in
    the colour-blindness simulators.
12. **`DynamicTypeCardListTile` widget.** A `ListTile`
    variant that scales with the system font scale, always
    shows the subtitle, and respects 44 dp minimum at 200%.

### What we are NOT building (yet)

- Braille display output (provided by Flutter's `Semantics`
  for free; we get it via the `Semantics` work in items
  1–3).
- A master "Accessible mode" toggle. The four individual
  toggles trade off; a single master switch would be a
  footgun.
- Custom gesture vocabulary. Build on TalkBack / VoiceOver
  / switch control / external keyboard.

### Build order (recommended)

1. **DR-014.a — `AnnounceableBarcode`** (now). Single
   widget, single new file, no architectural change.
2. **DR-014.b — `CardDetailVoiceSummary`** (next). Uses
   the `AccessibilityAnnouncer` from tier 4 — promote that
   mixin to `lib/services/accessibility_announcer.dart`
   before this widget.
3. **DR-014.c — `LargePrintBarcodeOverlay`**. One new
   screen. Pure widget, no DB.
4. Tier 2 widgets in priority order: 4 (search) → 5
   (quick-switcher) → 6 (audio cues, only if tier-2
   work shows a real navigation gap).
5. Tier 3 widgets in priority order: 8 (voice-PIN) → 7
   (scan haptic) → 9 (read-out-loud toggle).
6. Tier 4 composition utilities, after tier 1 widgets
   have proved the contract.

### Open question (tied to DR-014)

**Should the voice-PIN entry in #8 be opt-in, or hidden
behind a Settings toggle labelled "Allow voice PIN entry"
with the same shape as the existing biometric toggle?**
Recommendation: opt-in toggle, off by default, paired
with a clear "PIN only" fallback so a sighted-but-speech-
impaired user can still unlock. Mirrors how the biometric
toggle works today. (Tracked but not blocking DR-014.a.)
