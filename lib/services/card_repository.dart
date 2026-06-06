// ignore_for_file: prefer_initializing_formals

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

  List<WalletCard> get cards {
    return List.unmodifiable(_sortedCards(includeArchived: false));
  }

  List<WalletCard> get archivedCards {
    return List.unmodifiable(_sortedCards(includeArchived: true));
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
    final payload = _storageCodec.decodeStored(stored);
    if (payload.cards.isEmpty) {
      await preferences.remove(_legacyStorageKey);
      return false;
    }
    await _database.replaceAllCards(payload.cards);
    await preferences.remove(_legacyStorageKey);
    return true;
  }

  @override
  void dispose() {
    if (_ownsDatabase) {
      unawaited(_database.close());
    }
    super.dispose();
  }

  WalletCard? findById(String id) {
    for (final card in _cards) {
      if (card.id == id) {
        return card;
      }
    }
    return null;
  }

  Future<void> upsert(WalletCard card) async {
    final index = _cards.indexWhere((existing) => existing.id == card.id);
    final updatedCard = card.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      _cards.add(updatedCard);
    } else {
      final previous = _cards[index];
      _cards[index] = updatedCard;
      await _cleanupReplacedImages(previous: previous, next: updatedCard);
    }
    await _database.upsertCard(updatedCard);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    await upsert(card.copyWith(favorite: !card.favorite));
  }

  Future<void> archive(String id) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    await upsert(card.copyWith(archived: true));
  }

  Future<void> unarchive(String id) async {
    final card = findById(id);
    if (card == null) {
      return;
    }
    await upsert(card.copyWith(archived: false));
  }

  Future<void> deleteCard(String id) async {
    final index = _cards.indexWhere((card) => card.id == id);
    if (index == -1) {
      return;
    }
    final removed = _cards.removeAt(index);
    await _cleanupCardImages(removed);
    await _database.deleteCardById(id);
    notifyListeners();
  }

  Future<int> migrateCustomCategory({
    required String fromLabel,
    required CardCategory toCategory,
    String? toCustomCategory,
  }) async {
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
        customCategory: toCategory == CardCategory.other ? targetCustom : null,
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
    notifyListeners();
    return updatedCards.length;
  }

  Future<String> exportPlainJson() async {
    final images = <BackupImagePayload>[];
    for (final card in _cards) {
      final frontImage = await _imageAttachmentFor(
        path: card.frontImagePath,
        cardId: card.id,
        side: 'front',
      );
      if (frontImage != null) {
        images.add(frontImage);
      }
      final backImage = await _imageAttachmentFor(
        path: card.backImagePath,
        cardId: card.id,
        side: 'back',
      );
      if (backImage != null) {
        images.add(backImage);
      }
      final barcodeImage = await _imageAttachmentFor(
        path: card.barcodeImagePath,
        cardId: card.id,
        side: 'barcode',
      );
      if (barcodeImage != null) {
        images.add(barcodeImage);
      }
    }
    return _storageCodec.encodeBackupWithImages(
      _cards,
      imageAttachments: images,
    );
  }

  Future<int> importPlainJson(String rawJson) async {
    final result = await importPlainJsonProtected(rawJson);
    return result.importedCount;
  }

  Future<ImportCardsResult> importPlainJsonProtected(String rawJson) async {
    final payload = _storageCodec.decodeBackup(rawJson);
    final importedCards = <WalletCard>[];
    var addedCount = 0;
    var updatedCount = 0;
    var skippedOlderCount = 0;
    for (final card in payload.cards) {
      importedCards.add(
        await _hydrateImportedCard(card, attachments: payload.imageAttachments),
      );
    }
    for (final card in importedCards) {
      final index = _cards.indexWhere((existing) => existing.id == card.id);
      if (index == -1) {
        _cards.add(card);
        addedCount += 1;
      } else {
        final previous = _cards[index];
        if (previous.updatedAt.isAfter(card.updatedAt)) {
          skippedOlderCount += 1;
          continue;
        }
        _cards[index] = card;
        await _cleanupReplacedImages(previous: previous, next: card);
        updatedCount += 1;
      }
    }
    if (importedCards.isNotEmpty) {
      final cardsToPersist = <WalletCard>[];
      for (final card in importedCards) {
        final current = findById(card.id);
        if (current == null) {
          continue;
        }
        if (identical(current, card) || current.updatedAt == card.updatedAt) {
          cardsToPersist.add(current);
        }
      }
      if (cardsToPersist.isNotEmpty) {
        await _database.upsertCards(cardsToPersist);
      }
    }
    notifyListeners();
    return ImportCardsResult(
      importedCount: addedCount + updatedCount,
      addedCount: addedCount,
      updatedCount: updatedCount,
      skippedOlderCount: skippedOlderCount,
    );
  }

  List<WalletCard> _sortedCards({required bool includeArchived}) {
    final filtered = _cards
        .where((card) => includeArchived ? card.archived : !card.archived)
        .toList();
    filtered.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered;
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
