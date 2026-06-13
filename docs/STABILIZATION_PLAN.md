# Card Box — Stabilization Plan

**Date:** 2026-06-13
**App:** `card_box/` (Flutter 3.12+, Drift SQLite, AES-256-GCM backups)
**Baseline:** `flutter analyze` → no issues. `flutter test` → 108 passing.
**Goal:** Fix the highest-impact runtime bugs that the analyzer and unit tests don't surface.

---

## Scope

Reviewed every `.dart` file under `card_box/lib` (services, models, screens, widgets). Two areas were audited in depth via four parallel review agents (race/async, error handling, lifecycle/resources, data integrity). Findings are deduplicated below.

The repo has good test coverage for the codec and crypto, but the analyzer cannot see:

- Race conditions on shared in-memory state across async boundaries
- Lifecycle / dispose ordering of native resources
- Data-loss risk from non-atomic (in-memory ↔ DB ↔ file-system) operations
- User-facing error message leakage

These are the bugs the plan addresses.

---

## Severity Tally (deduplicated)

| Severity | Count | What it covers |
|----------|-------|----------------|
| **CRITICAL** | 6 | Data loss, permanent lockout, app won't start |
| **HIGH** | 12 | Wrong persisted state, torn writes, leaked native resources, error-leak UX |
| **MEDIUM** | 18 | Partial-failure handling, instrument gaps, defensive hardening |
| **LOW** | 14 | Verified-safe patterns (kept for the record), polish, perf |

---

## Phase Plan

Each phase ends with all green tests + analyzer, and is shipped as one or more atomic commits. The phases are independent enough to land in any order, but are sequenced so that the most user-visible data-loss risk is removed first.

### Phase 1 — Data Loss Stop-Gaps (CRITICAL)

Goal: stop the next user from silently losing their wallet.

| # | Issue | Files | Fix |
|---|-------|-------|-----|
| 1.1 | `loadCards` aborts the whole list on a single corrupt row | `lib/services/card_database.dart:79-82, 141-144` | Per-row try/catch in `loadCards`; defensive cast in `_cardFromRow`. Skip-and-log on parse failure; emit a `corruptCardIds` callback so the UI can surface a banner. |
| 1.2 | `_migrateLegacyStorageIfNeeded` can hang the app on bad JSON | `lib/services/card_repository.dart:67-82` | Wrap `decodeStored` in try/catch. On `FormatException`, move the legacy key out of the way (rename, do not delete) and continue. |
| 1.3 | `deleteCard` deletes images **before** the DB row, leaving the user with a "deleted" card whose images are gone and a backup that has no photos | `lib/services/card_repository.dart:139-148` | Reorder: delete DB row first, then clean up files. On DB error, restore in-memory state and rethrow. |
| 1.4 | `replaceAllCards` (legacy migration / seed) loses legacy data on partial failure because the SharedPreferences key is removed *after* the DB write | `lib/services/card_repository.dart:67-82` | Keep the legacy key on failure. Only remove after `replaceAllCards` succeeds. |
| 1.5 | `MediaRecoveryService.recoverLostPhotoDraft` clears the pending request **before** checking if a file is recoverable, so a dismissed picker wipes the recovery state forever | `lib/services/media_recovery_service.dart:40-61` | Peek, then only clear on `files.isNotEmpty`. Add a max-retry counter (3) to prevent stuck state. |
| 1.6 | `importPlainJsonProtected`'s `cardsToPersist` filter is dead code and the `card.identical()` / `updatedAt` invariant is fragile; risk of clobbering `updatedAt` | `lib/services/card_repository.dart:237-286` | Track the actually-changed set in the loop and persist exactly that. |

**Tests to add (RED → GREEN):**
- `loadCards` returns the valid cards and skips a corrupt row (inject via in-memory DB).
- `init` completes when the legacy `shared_preferences` blob is malformed.
- `deleteCard` rethrows on DB failure and restores in-memory state.
- `replaceAllCards` failure leaves the legacy key intact.
- `recoverLostPhotoDraft` returns null and preserves the pending request when `files` is empty; clears it when non-empty; caps at 3 attempts.
- `importPlainJson` persists exactly the added + updated (and not the skipped-older) cards; the persisted cards keep their imported `updatedAt`.

### Phase 2 — Write-Path Atomicity (CRITICAL → HIGH)

Goal: in-memory list, DB row, and image files move together or not at all.

| # | Issue | Files | Fix |
|---|-------|-------|-----|
| 2.1 | `CardRepository` has no serialization around `_cards`; concurrent `upsert`/`deleteCard`/`import` can interleave and leave memory ↔ DB diverged | `lib/services/card_repository.dart:101-148, 150-196, 237-286` | Single in-flight queue via `_enqueue<T>(...)` (chain a `Completer`). Wrap every mutating method. |
| 2.2 | `upsert` mutates in-memory **before** DB write, then cleans up old images **after**; partial failure loses data and orphans files | `lib/services/card_repository.dart:101-113` | DB write first; on success, mutate in-memory and clean old images. On failure, leave the old state intact and rethrow. |
| 2.3 | `upsert` always bumps `updatedAt` to `DateTime.now()` even for no-op writes | `lib/services/card_repository.dart:103` | Add a content-equality check (compare the JSON minus `updatedAt`); skip the write if unchanged. Allow an optional `updatedAt` override for import. |
| 2.4 | `exportPlainJson` reads `_cards` interleaved with `await`s — torn export when a concurrent write deletes images mid-export | `lib/services/card_repository.dart:198-230` | Snapshot `_cards` under the same `_enqueue` lock. |
| 2.5 | `_cleanupCardImages` and `_cleanupReplacedImages` swallow no exceptions; an `unawaited(...)` delete with a transient I/O error silently orphans the file | `lib/services/card_media_store_io.dart:42-50`, callers in repository + `edit_card_screen.dart` | Make `deleteStoredImage` swallow `FileSystemException` (best-effort). Add `.catchError` to the unawaited call sites in the edit screen. |
| 2.6 | `dispose()` uses `unawaited(_database.close())`; a double-dispose race throws from Drift | `lib/services/card_repository.dart:84-90` | Idempotent close flag. Make `close()` async on the repository and have `main()` call it on `AppLifecycleState.detached`. |

**Tests to add:**
- Two concurrent `upsert` calls for the same card produce a deterministic final state (queue serialization).
- `upsert` with content equal to the current card is a no-op (no `updatedAt` bump, no DB write).
- `upsert` failure rolls back in-memory state and leaves old image files intact.
- `exportPlainJson` snapshot is stable under concurrent `upsert` (use `FakeAsync` / fake clock).
- `deleteStoredImage` does not throw on a missing file or `FileSystemException`.

### Phase 3 — Lock & Lifecycle Hardening (HIGH)

Goal: native resources (camera, NFC, secure storage) are released deterministically; the app lock cannot be bypassed.

| # | Issue | Files | Fix |
|---|-------|-------|-----|
| 3.1 | `MobileScannerController` is disposed after `setState` with no `try/finally`; an exception leaves `_switchingMode = true` permanently and the camera UI is frozen on "Updating the scanner..." | `lib/screens/barcode_scan_screen.dart:334-370` | Wrap dispose in `try/catch`. Always reset `_switchingMode` in a `finally`. Stop the old controller before building the new one. |
| 3.2 | `MobileScanner` lifecycle callbacks (`_suspendScannerForBackground`) can race with `dispose()` and call `stop()` on a dead controller | `lib/screens/barcode_scan_screen.dart:57-91` | Track a `Completer<void>? _controllerDisposed` and `await` it before stopping. |
| 3.3 | `NfcService.scanTag` Completer can race the 20s timeout; `_stopSessionSafely` runs twice and the iOS NFC sheet can persist after the calling widget is gone | `lib/services/nfc_service.dart:83-158` | Use a `stopped` flag guard. Move `_stopSessionSafely` *out* of `completer.complete()` and into the same callback that calls `complete`. Add a public `cancel()` for caller-initiated teardown. |
| 3.4 | `appLockService._trustedExternalFlowCount` can drift if the camera activity is force-killed and a `finally` is bypassed; `deferringBackgroundLock` stays true and the lock is skipped on resume | `lib/services/app_lock_service.dart:131-140`, `lib/screens/app_root.dart` | Add a max-age (60s) on the trust window. Reset to 0 on `AppLifecycleState.detached`. Verify all `begin/end` pairs are still wrapped in `try/finally`. |
| 3.5 | `_obscureContent` lifecycle callback in `app_root.dart` and `barcode_scan_screen.dart` `didChangeAppLifecycleState` can fire after dispose in edge cases | `lib/screens/app_root.dart:52-73`, `lib/screens/barcode_scan_screen.dart:63-91` | `if (!mounted) return;` at the top of every observer method. |
| 3.6 | `BackupFileService._backupDirectory` catches only `UnsupportedError`; iOS can throw `PlatformException` from `getDownloadsDirectory()` and the export crashes | `lib/services/backup_file_service_io.dart:88-99` | Add `PlatformException` and `MissingPluginException` to the catch chain. Fall back to `getApplicationDocumentsDirectory`. |

**Tests to add:**
- `_changeMode` always resets `_switchingMode`, even when `oldController.dispose()` throws.
- `NfcService.scanTag` calls `stopSession` exactly once across the success path.
- `AppLockService` resets `_trustedExternalFlowCount` after the max-age window elapses.
- `app_root.didChangeAppLifecycleState` does not crash on a hot-restart during inactive state.

### Phase 4 — User-Facing Error Hygiene (HIGH)

Goal: no `FormatException: ...` in SnackBars, no silent feature degradation.

| # | Issue | Files | Fix |
|---|-------|-------|-----|
| 4.1 | `Could not extract details: $error` (and vCard, link, NFC detail) leak the raw exception type and message | `lib/screens/edit_card_screen.dart:662-668`, `lib/screens/card_detail_screen.dart:417-423, 459-463`, `lib/services/nfc_service.dart:120-133, 150-157` | Map `FormatException` / `PlatformException` / `FileSystemException` to user-friendly copy. The "NFC summary failed" path returns a fixed status string, not `error.toString()`. |
| 4.2 | `_PasswordPromptSheet` only re-validates "passwords match" when the user taps submit, not when they retype | `lib/screens/export_import_screen.dart:382-395` | Re-validate via `addListener` so the form feedback is live. |
| 4.3 | `BackupCryptoService.encryptJson` trims the password and validates the *trimmed* length; the UI copy "at least 8 characters" misleads the user about effective key strength | `lib/services/backup_crypto_service.dart:22-31`, `lib/screens/export_import_screen.dart` | Validate `password.length` (no trim) ≥ 8 *and* `password.trim().length` ≥ 8. Reject passwords whose content is mostly whitespace with a clear message. Apply the same on the decrypt path. |
| 4.4 | `CardRepository.exportPlainJson` silently drops images whose file is gone (e.g. cache wiped) with no user-visible warning | `lib/services/card_repository.dart:198-230` | Return an `ExportSummary` that includes `missingImages` per card. Surface it in the SnackBar. |
| 4.5 | `CardRepository._cleanupCardImages` and friends have no logging in their silent `catch (_)` blocks | many | Add `if (kDebugMode) debugPrint(...)` for telemetry. |
| 4.6 | `MediaRecoveryService._readPendingRequest` swallows a corrupt pending JSON silently; user is stuck without a recovery banner | `lib/services/media_recovery_service.dart:72-86` | On parse failure, log and remove the key so the next launch starts clean. |
| 4.7 | `MediaRecoveryService` doesn't cap retry count — a permanently denied picker leaves the pending key forever | `lib/services/media_recovery_service.dart:40-61` | Cap at 3 retries. After cap, clear the key and surface a one-time hint. |

**Tests to add:**
- `_extractVisitingCardDetails` shows the friendly text for `FormatException`, `PlatformException`, and an unknown type.
- The password prompt sheet validates live on input, not just on submit.
- `encryptJson` rejects a password that contains 7 non-whitespace chars padded to 15 with spaces.
- `exportPlainJson` returns the correct `missingImages` count when a file is missing.
- `recoverLostPhotoDraft` clears the pending state after 3 failed attempts.

### Phase 5 — UX & Polish (MEDIUM)

Goal: defensive hardening of remaining surfaces; instrument for future telemetry.

| # | Issue | Files | Fix |
|---|-------|-------|-----|
| 5.1 | `CategoryService.renameCategory` does not migrate cards' `customCategory` strings — rename orphans | `lib/services/category_service.dart:38-76`, `lib/services/card_repository.dart:150-196` | Wire `renameCategory` to call `migrateCustomCategory` on the repository. Add a "Rename and update N cards" confirmation in the UI. |
| 5.2 | `WalletCard.fromJson` defaults `id` to `''`; import of malformed JSON with two empty-id cards collides on the PK | `lib/models/wallet_card.dart:209` | Generate `'imported-${micros}-${hash}'` when id is missing/empty. |
| 5.3 | `EditCardScreen` generates new card IDs as `'card-${micros}'`; clock-jump or simulator can collide | `lib/screens/edit_card_screen.dart:574` | Append a 32-bit random suffix (no new dep). |
| 5.4 | `CardDatabase` migration (`_backfillNormalizedColumns`) crashes on a corrupt row, leaving the schema upgrade half-applied | `lib/services/card_database.dart:146-162` | Per-row try/catch in backfill. |
| 5.5 | `CardStorageCodec._decodePayload` throws on any malformed input — all-or-nothing import | `lib/services/card_storage_codec.dart:50-104` | Per-card try/catch in `decodeCardsFromList`; skip and log. |
| 5.6 | `_sortedCards` re-sorts on every getter call (perf, not bug) | `lib/services/card_repository.dart:43-45, 288-299` | Cache the sorted result; invalidate on `notifyListeners`. |
| 5.7 | `findById` is O(n); `importPlainJson`'s inner loop becomes O(n²) on large libraries | `lib/services/card_repository.dart:92-99, 237-286` | Maintain a `Map<String, int>` index alongside `_cards`. |
| 5.8 | `CardPhotoTightener.tighten` and `VisitingCardOcrService._recognizeLinesSafely` are silent on failure | `lib/services/card_photo_tightener.dart:51-105`, `lib/services/visiting_card_ocr_service.dart:217-226` | Return a small `result + reason` so the UI can show a one-time "auto-crop wasn't applied" hint. |
| 5.9 | `AppLockScreen` retry button has no debounce; user can hammer the local_auth API | `lib/screens/app_lock_screen.dart` | 500ms debounce on the retry action. |
| 5.10 | Lifecycle observers correctly removed in `app_root.dart` and `barcode_scan_screen.dart` | (verified safe — no change) | — |

**Tests to add:**
- `renameCategory` migrates the right number of cards and updates `customCategory`.
- `WalletCard.fromJson` generates a unique id when the input id is empty.
- `_backfillNormalizedColumns` skips a corrupt row.
- `decodeBackup` returns the valid cards and skips the corrupt ones.
- `_sortedCards` is stable under no `notifyListeners` (cache hit) and invalidated after one.

### Phase 6 — Documentation & Tooling (LOW)

- Add a top-level `lib/services/card_repository.dart` docstring explaining the in-memory / DB / file-system invariant: "the DB is the source of truth; in-memory is a cache; cleanup is best-effort."
- Add a `CHANGELOG.md` entry for each shipped phase.
- Add a release-build smoke test (integration_test) that exercises: create card → export encrypted → wipe DB → import encrypted → verify cards & images round-trip.
- Add a `MIGRATION.md` documenting the v1 → v2 schema upgrade and the `shared_preferences` → SQLite migration.

---

## Test Strategy

Per the project's TDD rule:

1. **RED:** Write a failing test that pins the bug (or a property-based test for race conditions).
2. **GREEN:** Minimal change to make it pass.
3. **IMPROVE:** Refactor for clarity once green.
4. **Coverage:** Maintain ≥ 80% on the touched files (`card_repository.dart`, `card_database.dart`, `media_recovery_service.dart`, `nfc_service.dart`, `barcode_scan_screen.dart`).

Race-condition tests use `package:fake_async` plus explicit `Completer` ordering. Resource-lifecycle tests use `WidgetTester` to push and pop screens and assert `Future.wait` completion.

For changes that affect the database, the existing schema-version test in `card_database_test.dart` is the regression harness — every Phase 1/5 change keeps it green.

---

## Risk & Rollback

- **Phase 1** changes are in the data-load and import paths; rollback is the previous `_cleanupCardImages` order and the eager `clearPendingPhotoRequest` — both are pure code changes with no schema impact. If the per-row skip breaks a hand-crafted import, the user can re-export.
- **Phase 2** introduces a write-queue; the only observable change is the ordering of `notifyListeners` (now after DB write). If a downstream listener assumes in-memory-first, that listener needs to be re-evaluated. Rollback is removing the `_enqueue` wrapper.
- **Phase 3** lifecycle changes are local to the scanner / NFC / app-lock services. Worst case is a leaked camera/NFC session, which the OS will reclaim in seconds. Rollback is the previous `dispose` body.
- **Phase 4** is UX copy + return-type changes on `exportPlainJson`; safe to ship. Rollback is restoring the prior return value (counts only).
- **Phase 5** adds id-collision resistance and per-row error tolerance; both improve on the current behavior. Rollback is removal of the new helpers.
- **Phase 6** is documentation only.

A failed release can be reverted by `git revert` of the phase commit(s). Each phase ends with a green test run and a single atomic commit.

---

## Out of Scope

- iOS NFC entitlement / provisioning profile (requires an Apple Developer account; surface as a follow-up ticket).
- De-vendoring `mobile_scanner` and `nfc_manager` (separate stabilization stream).
- Android 14 partial-photo-access changes (requires manifest + code changes; not in this plan).
- Migrating from `image_picker.retrieveLostData` to the OS-native restoration flow (depends on the above).
- Performance optimization beyond the cache/index changes in Phase 5.6/5.7 (the test suite is fast enough; not on the critical path).

---

## Commit & PR Cadence

One phase per PR, ordered by severity. Each PR:
- Branch from `main`: `fix/<phase-slug>`.
- One or more atomic commits.
- `flutter analyze` + `flutter test` green in CI.
- Description with: what was found, what was fixed, what was deferred, screenshots if UX changed.

The plan ends when Phases 1–5 are merged and the integration test in Phase 6 is green on a real device (Android + iOS).
