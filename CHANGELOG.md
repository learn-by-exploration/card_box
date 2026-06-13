# Card Box — Changelog

All notable changes to the Card Box app are documented here.
Stabilization work followed the plan in `docs/STABILIZATION_PLAN.md`.

## [Unreleased] — Stabilization

### Phase 1 — Data-loss stop-gaps (CRITICAL)

- `CardDatabase.loadCards` now skips rows with a corrupt payload
  instead of failing the entire load.
- `CardRepository.init` is guarded so two concurrent `init()`
  calls do not double-load.
- `CardRepository.deleteCard` reorders the in-memory remove
  *after* the DB delete so a DB failure cannot leave the
  in-memory list missing a row that the database still has.
- The `v1 → v2` migration is wrapped per-row, so one corrupt
  row does not abort the schema upgrade.
- `MediaRecoveryService` no longer eagerly clears the pending
  request on every launch — only when a recoverable file is
  actually produced.
- The plaintext import flow filters out cards with an empty id
  before they can collide on the primary key.

### Phase 2 — Write-path atomicity (CRITICAL → HIGH)

- A new in-flight queue serializes every public write method
  on a single `Future` chain, eliminating the race where two
  concurrent `upsert` calls could observe each other's
  in-memory mutations before either committed to the database.
- The database is now written first, the in-memory list
  second, and listeners are notified last. A mid-operation
  failure rolls back the in-memory state.
- No-op upserts (content identical, ignoring `updatedAt`) skip
  both the DB write and the listener notification.
- `exportPlainJson` runs under the queue, so the snapshot of
  cards and the streaming of image bytes cannot be torn by a
  concurrent write.
- `CardMediaManager.deleteImage` is idempotent for missing
  files; concurrent deletes are safe.
- `CardRepository.dispose` is idempotent.

### Phase 3 — Lock & lifecycle hardening (HIGH)

- `BarcodeScanScreen` no longer leaves a dangling
  `MobileScannerController` when the scanner mode switches
  mid-frame.
- `NfcService.scanTag` funnels every completion path (success,
  iOS session error, timeout, caller cancel) through a single
  `tearDown` closure so the iOS NFC sheet always dismisses.
- `AppLockService` caps the "trusted external flow" counter at
  a 60-second max-age; an outer observer cannot pin the app
  open forever.
- `AppRoot` and `BarcodeScanScreen` mounted-guard their
  `didChangeAppLifecycleState` callbacks before touching
  state.
- `BackupFileService` falls back to the application documents
  directory when `getDownloadsPath` throws a `PlatformException`
  or a `MissingPluginException` (iOS sim quirk).

### Phase 4 — User-facing error hygiene (HIGH)

- `BackupCryptoService` validates the trimmed length of a
  password, so a password of mostly whitespace is rejected
  with a clear message instead of producing a weak AES key.
- `CardRepository.exportPlainJson` now returns a
  `CardExportSummary` that includes the count and identity of
  images that could not be included (cache wiped, file deleted
  out-of-band). The export screen surfaces a "N images could
  not be included" hint.
- All silent `catch (_)` blocks in the photo, OCR, and media
  services now emit a `debugPrint` so future regressions are
  visible in the debug log.
- `MediaRecoveryService` logs and clears a corrupt pending
  payload on parse failure so the user is not stuck without a
  recovery banner. The retry counter is capped at 3 empty
  attempts; once exhausted the key is cleared automatically.

### Phase 5 — UX & polish (MEDIUM)

- `CategoryService.renameCategory` invokes a migration hook so
  the repository can rewrite every card whose
  `customCategory` matched the old label. The hook is wired up
  in `main.dart`.
- `WalletCard.fromJson` generates a unique id
  (`imported-<micros>-<hash>`) when the input id is empty, so
  malformed exports no longer collapse onto the same primary
  key.
- `WalletCard.generateNewId` adds a 32-bit random suffix to the
  microsecond timestamp. New cards and draft ids can no longer
  collide on a frozen clock or a tight loop.
- The v1 → v2 backfill wraps each row in its own try/catch; a
  single corrupt row no longer leaves every other card with
  empty normalized columns.
- `CardStorageCodec._decodeCardsFromList` wraps each card in
  its own try/catch; one corrupt card no longer aborts the
  whole import.
- `CardRepository.cards` and `archivedCards` cache the sorted
  view and invalidate the cache on every `notifyListeners` so
  the home screen does not re-sort on every rebuild.
- `CardRepository.findById` uses an eagerly-built
  `Map<String, int>` index for O(1) lookup.
- `CardPhotoTightener.tighten` now returns a `TightenResult`
  whose `reason` field tells the UI *why* no improvement was
  made (decode failed, no text detected, internal error,
  no change, tightened).
- `VisitingCardExtraction.hadRecognizerFailure` lets the UI
  show a one-time "OCR didn't return anything" hint when every
  recognizer threw.
- `AppLockScreen` debounces the biometric retry button with a
  500ms window so a frantic user cannot hammer the local_auth
  API and cause the OS prompt queue to fall out of sync.

### Phase 6 — Documentation & tooling (LOW)

- The top of `lib/services/card_repository.dart` now states
  the storage-of-record invariants: the database is the source
  of truth, the in-memory list is a cache, image cleanup is
  best-effort, and writes are serialized.
- This changelog.
- `MIGRATION.md` documents the v1 → v2 schema upgrade and the
  legacy `shared_preferences` → SQLite migration.

### Phase 7 — Dead-code purge

- `WalletCard.expiryDate` is removed. The field was introduced for
  expiry reminders, which are deferred to a later pass (see
  `docs/v_model/decision_record.md` DR-013).
- `WalletCard.generateNewId` no longer uses the `wallet-` prefix;
  new ids are `card-<micros>-<hex>`. Existing backups still load
  because the id is stored in the JSON payload.
- The denormalized DB columns introduced for the deferred features
  (including the unused `androidHceCandidate` field, which is
  active today) have been removed from the Drift schema. The
  storage of record is `(id, payloadJson, createdAtMillis,
  updatedAtMillis)`.

### Phase 8 — Screen refactor

- `home_screen.dart` is split into `_HomeAppBar`,
  `_CategoryFilterBar`, `_CategoryPickerSheet`, `_HelpSheetContent`,
  and `_CardActionsSheet` so further feature work lands in
  reviewable chunks.
- `edit_card_screen.dart` is split into `_CardIdentityFields`,
  `_VisitingCardFields`, `_BarcodeFields`, `_AddHelpSheetContent`,
  `_InterfaceConfirmDialog`, `_ConfirmDeleteDialog`, and a
  `_ScanDuplicateDialog` (used by the new scan-time duplicate
  detection).

### Phase 9 — User-facing features

- **Duplicate card.** A new "Duplicate" action on the more-options
  sheet creates a peer card with a fresh id, the name suffixed with
  "(copy)", and new `createdAt`/`updatedAt` timestamps.
- **Sort options.** The home list can be sorted by name (A→Z,
  default), name (Z→A), most recently updated, or most recently
  added. The selection persists in `SharedPreferences`.
- **Favorites filter.** A one-tap chip on the home list hides every
  non-favorited card and composes with the category and free-text
  filters.
- **Scan-time duplicate detection.** Scanning a barcode whose
  payload already exists on a different card surfaces a one-tap
  prompt to jump to the existing card or keep scanning. Re-scanning
  the same card's own payload does not self-prompt.
- **Wakelock on presentation screens.** The present-code and
  present-card screens now hold a `WakelockPlus` enable for their
  lifetime and release it in `dispose`, so the phone does not dim
  mid-scan.
- **Last-used and use count.** The presentation screens fire an
  `onShown` callback that the caller wires to
  `CardRepository.markUsed`. The card's `lastUsedAt` and
  `useCount` are persisted through the JSON payload (no schema
  migration) and round-trip cleanly through export/import.

### Deferred to a later pass

- Expiry reminders and acceptance locations are formally deferred
  to a later pass (DR-013 in `docs/v_model/decision_record.md`).
  The data model and Drift schema do not reserve space for these
  features.

### Phase 10 — Review fixes

- The present-code and present-card screens now type their
  `onShown` prop as `Future<void> Function()?` instead of
  `VoidCallback?`, so a thrown error in `markUsed` is observed
  by the caller rather than silently swallowed.
- The same screens now use `_wakelockAcquired` and `_onShownFired`
  guards so a hot-reload re-entry into `initState` does not
  double-acquire the wakelock or double-bump `useCount`. Errors
  from the wakelock plugin and from the `onShown` callback are
  logged via `debugPrint` instead of being dropped.
- `duplicateCard` now resets `archived`, `favorite`, `lastUsedAt`,
  and `useCount` on the copy. A duplicate of an archived card is
  an active, un-favorited, un-used variant of the original.
- The `markUsed is a no-op for an unknown card id` test now
  asserts that the visible card list is unchanged, so a future
  regression that synthesized a card for an unknown id would be
  caught.
