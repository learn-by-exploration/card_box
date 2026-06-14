# Decision Record

## DR-001: MVP Strategy For Card Emulation

Date: 2026-06-03

Decision: The MVP will focus on storage, organization, barcode/QR presentation,
camera capture, and NFC reading/capability detection. It will not depend on
RFID/NFC emulation being available before the app becomes useful.

Reasoning:

- The product vision includes the phone acting like physical RFID/NFC cards.
- Android can support some host-based card emulation scenarios, but not all
  cards can be emulated. Cards depending on fixed UID behavior, secure elements,
  proprietary protocols, or cryptographic challenge-response may not work.
- iOS does not provide broad general-purpose third-party RFID/NFC emulation.
- Many low-frequency RFID cards are outside normal phone NFC hardware support.
- A useful free app can ship sooner by organizing cards and making supported
  cards presentable/readable while labeling unsupported cards honestly.

Implication:

- Emulation becomes a later, platform-specific feature track, starting with
  Android and only for legally controlled, technically compatible cards.
- The app UI should classify capabilities per card:
  - Reference-only
  - Barcode/QR displayable
  - NFC readable
  - NFC writable to blank tag
  - Android HCE candidate
  - Unsupported

## DR-002: Payment Cards

Date: 2026-06-03

Decision: Card Box will not store credit card or debit card data.

Reasoning:

- Payment cards require compliance, issuer approval, security review, and
  potentially regulated infrastructure.
- The user explicitly does not want to include credit or debit cards.

Implication:

- Payment-card cloning, payment-card reading, and payment-card storage remain
  out of scope.
- The app may still support non-payment loyalty, membership, gift, library,
  student, event, identity reference, and access-card inventory use cases where
  legal and technically practical.

## DR-003: Biometric And Passcode Lock

Date: 2026-06-03

Decision: Biometric/passcode lock is not mandatory for the first MVP, but the
architecture should plan for it.

Reasoning:

- Card images, IDs, access card metadata, notes, and barcodes can still be
  sensitive even when bank cards are excluded.
- The user said it is not necessary on day one but is definitely wanted.

Implication:

- Storage and navigation should avoid choices that make later app-lock support
  awkward.
- The first implementation should evaluate secure storage and encrypted local
  data patterns.

## DR-004: Prototype Platform Priority

Date: 2026-06-03

Decision: Use Flutter and prioritize Android for the first real prototype, while
keeping iOS compatibility in the architecture.

Reasoning:

- Android gives the best early path for NFC reading experiments and later HCE
  investigation.
- Flutter still lets the app keep a credible iOS path for organization,
  barcode/QR, photos, export, and supported NFC reading.

Implication:

- Early device tests should focus on Android.
- Package choices should be checked for iOS support before adoption.
- Android-only behavior should be isolated behind capability services.

## DR-005: Backup Strategy

Date: 2026-06-03

Decision: The app will not rely on hosted cloud backup. Users should export
their own data.

Reasoning:

- The project should remain free to run and publish.
- Hosting introduces cost, privacy, maintenance, account, and security burdens.

Implication:

- Export/import becomes a first-class requirement.
- Encrypted export should be evaluated before public release.

## DR-006: Card Photos

Date: 2026-06-03

Decision: Card photos should be included in the first prototype.

Reasoning:

- Photos make the app useful even when barcode, QR, NFC, or RFID behavior is not
  supported.
- Photos help identify cards quickly in a crowded wallet.

Implication:

- The first data model must support front and back image references.
- Storage size and export size should be considered early.

## DR-007: Compatibility Test Flow

Date: 2026-06-03

Decision: The app should include a card compatibility test flow.

Reasoning:

- Users want to know whether a card can be read, displayed, emulated, or only
  stored as a reference.
- This prevents false expectations around RFID/NFC support.

Implication:

- The app should guide users through barcode/QR scan, NFC scan, and manual
  classification.
- The result should be stored on the card record.

## DR-008: Prototype Export Format

Date: 2026-06-03

Decision: The first prototype will export plain JSON. Encrypted export should be
added before public release.

Reasoning:

- Plain JSON is easiest to implement, inspect, and test in the early prototype.
- Export is user-controlled and no hosted service is involved.
- Card data can still be sensitive, so encrypted export remains important for
  release readiness.

Implication:

- v0.1 export/import tests can verify structure and round-trip behavior.
- Release requirements should include encrypted export.

## DR-009: App Name

Date: 2026-06-03

Decision: Use Card Box as the working app name.

Reasoning:

- It is simple, understandable, and matches the existing `board_box` naming
  pattern.
- A simpler or more creative public name can be revisited before release.

Implication:

- The project folder remains `card_box`.
- Product copy can use Card Box unless renamed later.

## DR-010: Permission-First Platform Interfaces

Date: 2026-06-03

Decision: The app should ask permission before using camera, NFC, file
export/import, or other platform interfaces.

Reasoning:

- Users should understand which phone capability is about to be used.
- Compatibility testing depends on card type and platform support.

Implication:

- Workflows should show permission or consent steps before scan/export actions.
- Platform services should expose capability checks and permission outcomes.

## DR-011: Smart-Scan Auto-Tightening Via On-Device Text Recognition

Date: 2026-06-11

Decision: The smart-scan result is post-processed on-device by
`CardPhotoTightener`, which uses ML Kit text recognition (Latin +
Japanese) to find the card's text region, pads and unions the detected
text-line boxes, and expands the result to the ID-1 (1.586:1) card
aspect ratio before re-encoding. The refinement is silent (no new UI)
and fail-safe: on any failure the original scanner output is returned
unchanged.

Reasoning:

- The document scanners on Android (ML Kit `GmsDocumentScanner`) and
  iOS (`VNDocumentCameraViewController`) return a "document" bounding
  box that typically includes 10-20% of background around the card,
  which is bad for OCR and for human-readable presentation.
- ML Kit text recognition is already in the project for the
  visiting-card OCR step, so the data path is free; no new
  permissions, no network, and the latency is hidden behind the
  scanner's existing progress UI.
- A custom TFLite card-detection model was rejected as out of scope
  (training data, model hosting, platform bindings). OpenCV-style
  contour detection was rejected because the `image` package has no
  Canny/contour API and the user-visible win is small relative to
  the implementation cost.
- The ID-1 aspect ratio is the same constant that the manual
  fallback cropper is locked to (see `cardAspectRatio`), so the
  output of any smart-scan path is predictably card-shaped.

Implication:

- All smart-scan paths (Android ML Kit, iOS VisionKit, and the
  Android camera + ID-1 fallback) benefit from the refinement; manual
  `capturePhoto`, `selectPhoto`, and `editPhoto` are not affected.
- The `CardPhotoTightener` is a constructor-injected service so the
  pipeline can be replaced in tests; the geometry is a pure function
  (`computeCardCrop`) that is unit-tested without spinning up ML Kit.
- If a future platform integration needs the scanner's unrefined
  output (e.g. multi-page documents), the `photoTightener` argument
  can be swapped for a pass-through implementation at the call site.

## DR-012: v0.1 Stabilization Pass (2026-06-13)

Date: 2026-06-13

Decision: The v0.1 prototype enters a stabilization pass that (a) removes
the now-unused `expiryDate` field, the `generateNewId` "wallet-" prefix,
and the denormalized DB columns introduced for the deferred features;
(b) splits `home_screen.dart` and `edit_card_screen.dart` into smaller
widgets so the next round of feature work is reviewable; and (c) lands
six user-facing features: duplicate a card, sort options, favorites
filter, scan-time duplicate detection, wakelock on the presentation
screens, and per-card `lastUsedAt`/`useCount` tracking.

Reasoning:

- The drift schema is at v3 with `(id, payloadJson, createdAtMillis,
  updatedAtMillis)` as the storage of record. The `expiryDate`, the
  `androidHceCandidate` boolean, and several other denormalized columns
  were introduced for capabilities that did not ship; keeping them
  required either carrying dead code or running empty migrations on
  every install.
- The two largest screens had crossed 1500 lines each. Adding more
  features on top of them was a poor trade between reviewability and
  velocity.
- The six landed features are all small, well-scoped, and round-trip
  through the existing JSON payload. They do not require a schema bump
  and they each have unit or widget tests.

Implication:

- `WalletCard.expiryDate` is gone. The acceptance-locations and
  expiry-reminders features that originally motivated the field are
  now deferred (see DR-013) and will be re-introduced deliberately
  when they are built.
- Card ids are now prefixed `card-…` (previously `wallet-…`). Existing
  backups still load because the id is read from the payload, not
  derived from the prefix.
- The presentation screens are now `StatefulWidget`s so they can hold a
  wakelock for their lifetime and fire an `onShown` callback. Callers
  that need to record usage pass `onShown: () => repository.markUsed(id)`.
- New tests cover the new behavior; the full suite (151 tests) is
  green on the stabilization branch.

## DR-013: Deferring Expiry Reminders And Acceptance Locations

Date: 2026-06-13

Decision: Expiry reminders and acceptance locations are explicitly
deferred to a later pass. They are not on the v0.1 path.

Reasoning:

- Expiry reminders need a notification permission, a scheduled
  notification service (`flutter_local_notifications` or equivalent),
  a timezone-aware scheduling strategy, and an "expiring soon" UX on
  top of the existing list. None of that is on the v0.1 critical path
  and each piece adds platform surface that warrants its own
  stabilization pass.
- Acceptance locations need a geolocation permission, a background or
  foreground location service, a per-card "where this card is
  accepted" model, and a proximity search. The privacy story for a
  local-first app that wants to do "which of my cards works here"
  without sending coordinates anywhere is non-trivial and deserves a
  dedicated decision record when it is designed.
- Both features have clear "if we do it, do it well" requirements.
  Building them as thin slivers now would lock the data model into a
  shape that the better version would have to refactor.

Implication:

- The data model and Drift schema do not need to reserve space for
  these features. The dead `expiryDate` field and the denormalized
  columns it implied have been removed; they will be re-introduced,
  if at all, by the feature that needs them.
- The home list does not need an "expiring soon" filter, and the card
  detail screen does not need a locations section. Their absence is
  intentional, not a bug.
- A future pass that picks up these features should write its own
  decision record and update `implementation_status.md` and
  `conops.md` in the same change.

## DR-014: Accessibility Widget Initiative (2026-06-14)

Date: 2026-06-14

Decision: The card_box app will adopt a 4-tier accessibility widget
initiative, starting with the cashier-facing barcode-presentation
flow. The first deliverable is the `AnnounceableBarcode` widget
(DR-014.a), followed by `CardDetailVoiceSummary` (DR-014.b) and
`LargePrintBarcodeOverlay` (DR-014.c). A `TtsService` interface is
introduced in `lib/services/tts_service.dart` so the TTS call is
dependency-injected and unit-testable.

Reasoning:

- The central user flow ("open the app, show the cashier my member
  number") is unusable by non-sighted users today. The barcode
  image is visual-only; the `SelectableText` payload is not
  wrapped in `Semantics`; no TTS path exists.
- The failure is high-stakes: the user is standing at a cashier
  with another person waiting, often with poor lighting and
  background noise. Audio is the only reliable channel.
- WCAG 2.2 SC 1.3.1 (Info and Relationships) and SC 4.1.2 (Name,
  Role, Value) require the payload to be programmatically
  determinable. The existing `BarcodeWidget` does not provide
  this.
- Google Play's "Accessibility" badge for an app that passes its
  accessibility audit is a Play Store listing signal that
  aligns with the existing COPPA / Families Policy positioning.

Implication:

- A new `lib/services/tts_service.dart` interface with a default
  on-device implementation. Test environments and CI use a
  no-op or fake TTS service.
- The "Read aloud" feature is opt-in via a Settings toggle
  (mirroring the existing `AppLockService` toggle pattern).
  The `Semantics` label and 44 dp hit target are always
  present.
- The widget infrastructure (DR-014.a) is reusable: the
  `Semantics` + TTS utility becomes the foundation for
  `CardDetailVoiceSummary` (b) and `CardListWithAudioCues`
  (tier-2 follow-up). Avoids per-screen roll-your-own.
- A new section in `docs/v_model/plan.md` records the 12-widget
  brainstorm so the work is preserved even if we ship only
  the first 3 in v0.2.
- All new widgets must satisfy: `Semantics(label:)` on every
  interactive widget; 44 dp minimum hit target; WCAG 4.5:1
  contrast (3:1 for large text); 200% text scale does not
  break the layout. These are already in
  `lib-screens.md §6`; the new widgets have explicit
  widget tests for the hit-target and 200% scale contracts.

Risks:

- On-device TTS engines differ across Android vendors. The
  default `flutter_tts` plugin hides most of this, but voice
  quality and latency vary. Mitigation: provide a
  "test voice" entry point in Settings so the user can
  verify TTS works on their device before they need it at
  the cashier.
- `flutter_tts` is a plugin; it cannot run in a Flutter
  `flutter test` environment. The widget tests must
  therefore test the `Semantics` contract and the TTS
  call argument via the injected fake, not the TTS output.

Out of scope (deferred to a later accessibility pass):

- Braille display output (already provided by Flutter's
  `Semantics` for free).
- A master "Accessible mode" toggle. The four individual
  toggles (announce, haptics, contrast, voice-PIN) trade
  off against each other; a single master switch would
  be a footgun.
- Custom gesture vocabulary. Build on TalkBack / VoiceOver
  / switch control / external keyboard; do not invent a
  new layer.
