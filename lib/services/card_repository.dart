// ignore_for_file: prefer_initializing_formals

/// Storage of record for the user's card library.
///
/// Invariants
/// ----------
/// 1. **The SQLite database is the source of truth.** Every public
///    write method commits to the database *before* mutating the
///    in-memory list and *before* notifying listeners. A
///    mid-operation failure must leave the DB unchanged and the
///    in-memory list in sync with it. Listeners therefore never
///    observe a state that has not been committed.
/// 2. **The in-memory list is a cache, not a source of truth.**
///    It is rebuilt from the database on `init()` and is kept in
///    sync with the database by the in-flight write queue. Reads
///    are lock-free; they may be eventually consistent across
///    rapid concurrent writes but always reflect a state that
///    was committed to the database.
/// 3. **Image cleanup is best-effort.** Card images live on the
///    file system; orphaned images are tolerable and recoverable
///    from a backup. Missing image files in the database row
///    surface as a "missing image" warning at export time, not
///    as a fatal error.
/// 4. **Writes are serialized.** A single future-chained queue
///    ensures that no two write operations can interleave. Public
///    methods that need to compose other writes must call the
///    private `_*Impl` helpers directly to avoid re-entering the
///    queue and deadlocking.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/card_database.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_storage_codec.dart';

class CardRepository extends ChangeNotifier {
  static const _legacyStorageKey = 'card_box.cards.v1';

  CardRepository({
    CardDatabase? database,
    CardStorageCodec? storageCodec,
    CardMediaManager? mediaManager,
    SharedPreferences? legacyPreferences,
    this.seedDemoCards = false,
  }) : _database = database ?? CardDatabase.defaults(),
       _storageCodec = storageCodec ?? CardStorageCodec(),
       _mediaManager = mediaManager ?? const DefaultCardMediaManager(),
       _legacyPreferences = legacyPreferences,
       _ownsDatabase = database == null;

  final List<WalletCard> _cards = [];
  final CardDatabase _database;
  final CardStorageCodec _storageCodec;
  final CardMediaManager _mediaManager;
  final SharedPreferences? _legacyPreferences;
  final bool _ownsDatabase;
  final bool seedDemoCards;
  bool _disposed = false;

  /// Cached sorted view of `_cards` (active only). Invalidated
  /// every time `notifyListeners` runs. The list is immutable
  /// from the caller's perspective — `List.unmodifiable` enforces
  /// that. Storing a single field rather than recomputing on every
  /// getter keeps the home screen snappy as the library grows.
  List<WalletCard>? _activeCache;

  /// Same as [_activeCache] but for the archive screen.
  List<WalletCard>? _archivedCache;

  /// Map from card id to its index in [_cards]. Lets [findById]
  /// run in O(1) without scanning the full list. Maintained
  /// alongside the list — every insert / update / remove updates
  /// the index in lockstep. Invalidated with the sort cache.
  Map<String, int>? _idIndex;

  /// Serializes write-path operations (upsert/delete/import/export) so
  /// that concurrent callers do not interleave DB writes, in-memory
  /// mutations, or filesystem cleanups. Each call awaits the previous
  /// one before starting — a tear-off queued last still observes the
  /// fully-committed state of every earlier call. Reads (`cards`,
  /// `findById`) stay lock-free and are eventually consistent.
  ///
  /// The queue is strictly for the public API. Public methods that
  /// need to compose other write methods (e.g., `archive` → `upsert`)
  /// must call the private `_*Impl` helpers — not the public
  /// `_enqueue`-wrapped methods — to avoid a deadlock where the
  /// inner .then chain waits for its own outer .then to complete.
  Future<void> _serial = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() body) {
    final completer = Completer<T>();
    final previous = _serial;
    _serial = previous.then((_) async {
      try {
        completer.complete(await body());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  List<WalletCard> get cards {
    return _sortedCards(includeArchived: false);
  }

  List<WalletCard> get archivedCards {
    return _sortedCards(includeArchived: true);
  }

  Future<void> init() async {
    _cards
      ..clear()
      ..addAll(await _database.loadCards());
    if (_cards.isNotEmpty) {
      return;
    }
    final migrated = await _migrateLegacyStorageIfNeeded();
    if (migrated) {
      _cards
        ..clear()
        ..addAll(await _database.loadCards());
      return;
    }
    if (seedDemoCards) {
      _cards.addAll(_demoCards());
      await _database.replaceAllCards(_cards);
    }
  }

  Future<bool> _migrateLegacyStorageIfNeeded() async {
    final preferences =
        _legacyPreferences ?? await SharedPreferences.getInstance();
    final stored = preferences.getString(_legacyStorageKey);
    if (stored == null || stored.isEmpty) {
      return false;
    }
    final CardStoragePayload payload;
    try {
      payload = _storageCodec.decodeStored(stored);
    } on FormatException catch (error) {
      // A corrupt blob must not hang init() — move the unreadable
      // payload aside (preserved for forensic recovery) and continue.
      debugPrint('Legacy migration decode failed: ${error.message}');
      await preferences.setString('$_legacyStorageKey.corrupt', stored);
      await preferences.remove(_legacyStorageKey);
      return false;
    }
    if (payload.cards.isEmpty) {
      await preferences.remove(_legacyStorageKey);
      return false;
    }
    try {
      await _database.replaceAllCards(payload.cards);
    } catch (error) {
      // DB write failed — keep the legacy key so the next launch
      // can retry. The transactional replaceAllCards is idempotent.
      debugPrint('Legacy migration DB write failed: $error');
      return false;
    }
    await preferences.remove(_legacyStorageKey);
    return true;
  }

  @override
  void dispose() {
    if (_disposed) {
      // Idempotent: a second dispose() (e.g., from a hot-reload
      // followed by an explicit teardown) must not try to close the
      // database again — Drift's close() throws on a closed
      // connection and the resulting unhandled future would crash
      // the isolate.
      return;
    }
    _disposed = true;
    if (_ownsDatabase) {
      unawaited(_database.close());
    }
    super.dispose();
  }

  WalletCard? findById(String id) {
    final index = _idIndex?[id];
    if (index != null && index < _cards.length && _cards[index].id == id) {
      return _cards[index];
    }
    for (var i = 0; i < _cards.length; i++) {
      if (_cards[i].id == id) {
        _idIndex?[id] = i;
        return _cards[i];
      }
    }
    return null;
  }

  /// Returns the first non-archived card whose barcode payload
  /// matches [payload] exactly (case-insensitive, whitespace-trimmed).
  /// Returns null if no match. Used for scan-time duplicate detection.
  WalletCard? findByBarcodePayload(String payload) {
    final needle = payload.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final card in _cards) {
      if (card.archived) continue;
      if (card.barcodePayload.trim().toLowerCase() == needle) {
        return card;
      }
    }
    return null;
  }

  /// Records that a card was just used (presented for scanning or
  /// shown to a cashier). Bumps [WalletCard.useCount] and stamps
  /// [WalletCard.lastUsedAt] with the current time. No-op if the card
  /// is unknown.
  Future<void> markUsed(String id, {DateTime? at}) {
    return _enqueue(() => _markUsedImpl(id, at: at));
  }

  Future<void> _markUsedImpl(String id, {DateTime? at}) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    final stamp = at ?? DateTime.now();
    await _upsertImpl(
      card.copyWith(
        lastUsedAt: stamp,
        useCount: card.useCount + 1,
        updatedAt: stamp,
      ),
    );
  }

  Future<void> upsert(WalletCard card, {DateTime? updatedAt}) {
    return _enqueue(() => _upsertImpl(card, updatedAt: updatedAt));
  }

  /// Internal upsert. Called by `upsert` (via the queue) and by other
  /// internal methods (`archive`, `import`, `migrateCustomCategory`)
  /// that already hold the queue. Must NOT be wrapped in `_enqueue`
  /// at the call site — doing so would deadlock.
  Future<void> _upsertImpl(WalletCard card, {DateTime? updatedAt}) async {
    final index = _cards.indexWhere((existing) => existing.id == card.id);
    if (index == -1) {
      // Fresh insert: trust the caller's updatedAt (preserved by import)
      // unless an explicit override is provided.
      final stamped = card.copyWith(updatedAt: updatedAt ?? card.updatedAt);
      // DB write first; on failure, in-memory state is unchanged.
      await _database.upsertCard(stamped);
      _cards.add(stamped);
    } else {
      final previous = _cards[index];
      if (_cardsContentEqual(previous, card)) {
        // No-op: content is identical (same id, same fields). Do not
        // bump updatedAt and do not touch the database — a re-save
        // must not appear to have changed the card.
        return;
      }
      final stamped = card.copyWith(updatedAt: updatedAt ?? DateTime.now());
      // DB write first; only mutate in-memory and clean up old
      // images after a successful write. This avoids leaving the
      // on-disk image orphaned by a stale DB row on partial failure.
      await _database.upsertCard(stamped);
      _cards[index] = stamped;
      try {
        await _cleanupReplacedImages(previous: previous, next: stamped);
      } catch (error) {
        debugPrint('Card image cleanup failed for $stamped.id: $error');
      }
    }
    _invalidateSortCache();
    notifyListeners();
  }

  /// Returns true when two cards have the same persistent content,
  /// ignoring `updatedAt`. Used to short-circuit no-op upserts that
  /// would otherwise look like a change to the database.
  bool _cardsContentEqual(WalletCard a, WalletCard b) {
    final aJson = a.toJson()..remove('updatedAt');
    final bJson = b.toJson()..remove('updatedAt');
    return _jsonDeepEquals(aJson, bJson);
  }

  bool _jsonDeepEquals(Object? a, Object? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) {
        return false;
      }
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_jsonDeepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (!_jsonDeepEquals(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  Future<void> toggleFavorite(String id) {
    return _enqueue(() => _toggleFavoriteImpl(id));
  }

  Future<void> _toggleFavoriteImpl(String id) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    await _upsertImpl(card.copyWith(favorite: !card.favorite));
  }

  Future<void> archive(String id) {
    return _enqueue(() => _archiveImpl(id));
  }

  Future<void> _archiveImpl(String id) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    await _upsertImpl(card.copyWith(archived: true));
  }

  Future<void> unarchive(String id) {
    return _enqueue(() => _unarchiveImpl(id));
  }

  Future<void> _unarchiveImpl(String id) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    await _upsertImpl(card.copyWith(archived: false));
  }

  Future<void> deleteCard(String id) {
    return _enqueue(() => _deleteCardImpl(id));
  }

  /// Duplicates an existing card with a fresh id and a `(copy)` suffix
  /// on the name. The copy shares the original's media file paths
  /// (we never read or write images here), starts un-archived and
  /// un-favorited regardless of the source, and timestamps it as a
  /// new just-created card. Returns null if [id] is not in the repo.
  Future<WalletCard?> duplicateCard(String id) {
    return _enqueue(() => _duplicateCardImpl(id));
  }

  Future<WalletCard?> _duplicateCardImpl(String id) async {
    final original = findById(id);
    if (original == null) {
      return null;
    }
    final now = DateTime.now();
    final copy = original.copyWith(
      id: WalletCard.generateNewId(),
      name: '${original.name} (copy)',
      createdAt: now,
      updatedAt: now,
      archived: false,
      favorite: false,
      // Reset usage telemetry so the duplicate is a fresh variant,
      // not a re-skinned history of the original.
      lastUsedAt: null,
      clearLastUsedAt: true,
      useCount: 0,
    );
    await _upsertImpl(copy);
    return copy;
  }

  Future<void> _deleteCardImpl(String id) async {
    final index = _cards.indexWhere((card) => card.id == id);
    if (index == -1) {
      return;
    }
    final removed = _cards.removeAt(index);
    try {
      await _database.deleteCardById(id);
    } catch (error) {
      // DB is the source of truth — restore the in-memory row so the
      // user can retry, then propagate so the UI can surface the error.
      _cards.insert(index, removed);
      rethrow;
    }
    _invalidateSortCache();
    notifyListeners();
    // Best-effort image cleanup after the DB row is gone. Image
    // orphans are tolerable; missing DB rows are not.
    try {
      await _cleanupCardImages(removed);
    } catch (error) {
      debugPrint('Card image cleanup failed for $id: $error');
    }
  }

  Future<int> migrateCustomCategory({
    required String fromLabel,
    required CardCategory toCategory,
    String? toCustomCategory,
  }) {
    return _enqueue(() async {
      final source = fromLabel.trim();
      final targetCustom = toCustomCategory?.trim() ?? '';
      if (source.isEmpty) {
        return 0;
      }
      if (toCategory == CardCategory.other && targetCustom.isEmpty) {
        throw ArgumentError(
          'A target custom category is required when migrating to Other.',
        );
      }
      final migratingToSameCustom =
          toCategory == CardCategory.other &&
          source.toLowerCase() == targetCustom.toLowerCase();
      if (migratingToSameCustom) {
        return 0;
      }

      final now = DateTime.now();
      final updatedCards = <WalletCard>[];
      for (var index = 0; index < _cards.length; index++) {
        final card = _cards[index];
        if (card.category != CardCategory.other ||
            card.customCategory?.trim().toLowerCase() != source.toLowerCase()) {
          continue;
        }
        final updated = card.copyWith(
          category: toCategory,
          customCategory: toCategory == CardCategory.other
              ? targetCustom
              : null,
          clearCustomCategory: toCategory != CardCategory.other,
          updatedAt: now,
        );
        _cards[index] = updated;
        updatedCards.add(updated);
      }

      if (updatedCards.isEmpty) {
        return 0;
      }
      await _database.upsertCards(updatedCards);
      _invalidateSortCache();
      notifyListeners();
      return updatedCards.length;
    });
  }

  Future<CardExportSummary> exportPlainJson() {
    // Take a snapshot of cards under the queue so that a concurrent
    // write cannot mutate the in-memory list while image bytes are
    // being streamed into the export payload.
    return _enqueue(() async {
      final snapshot = List<WalletCard>.unmodifiable(_cards);
      final images = <BackupImagePayload>[];
      final missing = <MissingCardImage>[];
      for (final card in snapshot) {
        final frontImage = await _imageAttachmentFor(
          path: card.frontImagePath,
          cardId: card.id,
          side: 'front',
        );
        if (frontImage != null) {
          images.add(frontImage);
        } else if (card.frontImagePath.trim().isNotEmpty) {
          missing.add(MissingCardImage(cardId: card.id, side: 'front'));
        }
        final backImage = await _imageAttachmentFor(
          path: card.backImagePath,
          cardId: card.id,
          side: 'back',
        );
        if (backImage != null) {
          images.add(backImage);
        } else if (card.backImagePath.trim().isNotEmpty) {
          missing.add(MissingCardImage(cardId: card.id, side: 'back'));
        }
        final barcodeImage = await _imageAttachmentFor(
          path: card.barcodeImagePath,
          cardId: card.id,
          side: 'barcode',
        );
        if (barcodeImage != null) {
          images.add(barcodeImage);
        } else if (card.barcodeImagePath.trim().isNotEmpty) {
          missing.add(MissingCardImage(cardId: card.id, side: 'barcode'));
        }
      }
      final rawJson = _storageCodec.encodeBackupWithImages(
        snapshot,
        imageAttachments: images,
      );
      return CardExportSummary(rawJson: rawJson, missingImages: missing);
    });
  }

  Future<int> importPlainJson(String rawJson) async {
    final result = await importPlainJsonProtected(rawJson);
    return result.importedCount;
  }

  Future<ImportCardsResult> importPlainJsonProtected(String rawJson) {
    return _enqueue(() async {
      final payload = _storageCodec.decodeBackup(rawJson);
      final importedCards = <WalletCard>[];
      var addedCount = 0;
      var updatedCount = 0;
      var skippedOlderCount = 0;
      for (final card in payload.cards) {
        importedCards.add(
          await _hydrateImportedCard(
            card,
            attachments: payload.imageAttachments,
          ),
        );
      }
      // Track the cards that actually changed during the import so the
      // persist filter is driven by the merge outcome, not by timestamp
      // equality that the dead-code filter relied on previously.
      final changedCards = <WalletCard>[];
      for (final card in importedCards) {
        final index = _cards.indexWhere((existing) => existing.id == card.id);
        if (index == -1) {
          _cards.add(card);
          addedCount += 1;
          changedCards.add(card);
        } else {
          final previous = _cards[index];
          if (previous.updatedAt.isAfter(card.updatedAt)) {
            skippedOlderCount += 1;
            continue;
          }
          if (previous == card) {
            // No-op: identical content (same id, same updatedAt, same fields).
            continue;
          }
          _cards[index] = card;
          await _cleanupReplacedImages(previous: previous, next: card);
          updatedCount += 1;
          changedCards.add(card);
        }
      }
      if (changedCards.isNotEmpty) {
        await _database.upsertCards(changedCards);
      }
      _invalidateSortCache();
      notifyListeners();
      return ImportCardsResult(
        importedCount: addedCount + updatedCount,
        addedCount: addedCount,
        updatedCount: updatedCount,
        skippedOlderCount: skippedOlderCount,
      );
    });
  }

  List<WalletCard> _sortedCards({required bool includeArchived}) {
    if (includeArchived) {
      final cached = _archivedCache;
      if (cached != null) {
        return cached;
      }
      final result = _computeSortedCards(includeArchived: true);
      _archivedCache = result;
      return result;
    }
    final cached = _activeCache;
    if (cached != null) {
      return cached;
    }
    final result = _computeSortedCards(includeArchived: false);
    _activeCache = result;
    return result;
  }

  List<WalletCard> _computeSortedCards({required bool includeArchived}) {
    final filtered = _cards
        .where((card) => includeArchived ? card.archived : !card.archived)
        .toList();
    filtered.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    // Build the id index from the underlying (unsorted) list, not
    // the filtered view, so the index can answer any id regardless
    // of archive state.
    final index = <String, int>{};
    for (var i = 0; i < _cards.length; i++) {
      index[_cards[i].id] = i;
    }
    _idIndex = index;
    return List.unmodifiable(filtered);
  }

  void _invalidateSortCache() {
    _activeCache = null;
    _archivedCache = null;
    _idIndex = null;
  }

  Future<BackupImagePayload?> _imageAttachmentFor({
    required String path,
    required String cardId,
    required String side,
  }) async {
    if (path.trim().isEmpty) {
      return null;
    }
    final image = await _mediaManager.readImageForBackup(path);
    if (image == null) {
      return null;
    }
    return BackupImagePayload(
      cardId: cardId,
      side: side,
      extension: image.extension,
      bytesBase64: base64Encode(image.bytes),
    );
  }

  Future<WalletCard> _hydrateImportedCard(
    WalletCard card, {
    required List<BackupImagePayload> attachments,
  }) async {
    final frontPath = await _importOrResolveImagePath(
      cardId: card.id,
      side: 'front',
      fallbackPath: card.frontImagePath,
      attachments: attachments,
    );
    final backPath = await _importOrResolveImagePath(
      cardId: card.id,
      side: 'back',
      fallbackPath: card.backImagePath,
      attachments: attachments,
    );
    final barcodeImagePath = await _importOrResolveImagePath(
      cardId: card.id,
      side: 'barcode',
      fallbackPath: card.barcodeImagePath,
      attachments: attachments,
    );
    return card.copyWith(
      frontImagePath: frontPath,
      backImagePath: backPath,
      barcodeImagePath: barcodeImagePath,
    );
  }

  Future<String> _importOrResolveImagePath({
    required String cardId,
    required String side,
    required String fallbackPath,
    required List<BackupImagePayload> attachments,
  }) async {
    BackupImagePayload? attachment;
    for (final candidate in attachments) {
      if (candidate.cardId == cardId && candidate.side == side) {
        attachment = candidate;
        break;
      }
    }
    if (attachment != null && attachment.bytesBase64.isNotEmpty) {
      final bytes = Uint8List.fromList(base64Decode(attachment.bytesBase64));
      return _mediaManager.storeImportedImage(
        cardId: cardId,
        side: side,
        bytes: bytes,
        extension: attachment.extension,
      );
    }
    if (fallbackPath.trim().isNotEmpty &&
        await _mediaManager.exists(fallbackPath)) {
      return fallbackPath;
    }
    return '';
  }

  Future<void> _cleanupReplacedImages({
    required WalletCard previous,
    required WalletCard next,
  }) async {
    if (previous.frontImagePath.isNotEmpty &&
        previous.frontImagePath != next.frontImagePath) {
      await _mediaManager.deleteImage(previous.frontImagePath);
    }
    if (previous.backImagePath.isNotEmpty &&
        previous.backImagePath != next.backImagePath) {
      await _mediaManager.deleteImage(previous.backImagePath);
    }
    if (previous.barcodeImagePath.isNotEmpty &&
        previous.barcodeImagePath != next.barcodeImagePath) {
      await _mediaManager.deleteImage(previous.barcodeImagePath);
    }
  }

  Future<void> _cleanupCardImages(WalletCard card) async {
    await _mediaManager.deleteImage(card.frontImagePath);
    await _mediaManager.deleteImage(card.backImagePath);
    await _mediaManager.deleteImage(card.barcodeImagePath);
  }

  List<WalletCard> _demoCards() {
    final now = DateTime.now();
    return [
      WalletCard(
        id: 'demo-office-access',
        name: 'Office access card',
        issuer: 'Workplace',
        category: CardCategory.access,
        notes: 'Acceptance test card. No private number stored.',
        compatibilityStatus: CompatibilityStatus.untested,
        createdAt: now,
        updatedAt: now,
      ),
      WalletCard(
        id: 'demo-supermarket-loyalty',
        name: 'Supermarket loyalty',
        issuer: 'Local grocery',
        category: CardCategory.loyalty,
        barcodePayload: 'DEMO-LOYALTY-0001',
        barcodeFormat: 'Code 128',
        compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
        favorite: true,
        createdAt: now,
        updatedAt: now,
      ),
      WalletCard(
        id: 'demo-metro-transit',
        name: 'Metro transit card',
        issuer: 'City transit',
        category: CardCategory.transit,
        notes: 'NFC behavior depends on city and issuer systems.',
        compatibilityStatus: CompatibilityStatus.referenceOnly,
        createdAt: now,
        updatedAt: now,
      ),
      WalletCard(
        id: 'demo-library',
        name: 'Library card',
        issuer: 'Public library',
        category: CardCategory.library,
        barcodePayload: 'DEMO-LIBRARY-0001',
        barcodeFormat: 'Code 39',
        compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class ImportCardsResult {
  const ImportCardsResult({
    required this.importedCount,
    required this.addedCount,
    required this.updatedCount,
    required this.skippedOlderCount,
  });

  final int importedCount;
  final int addedCount;
  final int updatedCount;
  final int skippedOlderCount;
}
