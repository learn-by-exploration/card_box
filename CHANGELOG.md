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
