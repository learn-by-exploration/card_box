import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_storage_codec.dart';

class CardRepository extends ChangeNotifier {
  static const _storageKey = 'card_box.cards.v1';

  CardRepository({
    CardStorageCodec? storageCodec,
    CardMediaManager? mediaManager,
    this.seedDemoCards = false,
  }) : _storageCodec = storageCodec ?? CardStorageCodec(),
       _mediaManager = mediaManager ?? const DefaultCardMediaManager();

  final List<WalletCard> _cards = [];
  final CardStorageCodec _storageCodec;
  final CardMediaManager _mediaManager;
  final bool seedDemoCards;
  late SharedPreferences _preferences;

  List<WalletCard> get cards {
    return List.unmodifiable(_sortedCards(includeArchived: false));
  }

  List<WalletCard> get archivedCards {
    return List.unmodifiable(_sortedCards(includeArchived: true));
  }

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    final stored = _preferences.getString(_storageKey);
    if (stored == null || stored.isEmpty) {
      if (seedDemoCards) {
        _cards.addAll(_demoCards());
      }
      await _save();
      return;
    }
    final payload = _storageCodec.decodeStored(stored);
    _cards
      ..clear()
      ..addAll(payload.cards);
    if (payload.needsRewrite) {
      await _save();
    }
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
    await _save();
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
    await _save();
    notifyListeners();
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
    }
    return _storageCodec.encodeBackupWithImages(
      _cards,
      imageAttachments: images,
    );
  }

  Future<int> importPlainJson(String rawJson) async {
    final payload = _storageCodec.decodeBackup(rawJson);
    final importedCards = <WalletCard>[];
    for (final card in payload.cards) {
      importedCards.add(
        await _hydrateImportedCard(card, attachments: payload.imageAttachments),
      );
    }
    for (final card in importedCards) {
      final index = _cards.indexWhere((existing) => existing.id == card.id);
      if (index == -1) {
        _cards.add(card);
      } else {
        final previous = _cards[index];
        _cards[index] = card;
        await _cleanupReplacedImages(previous: previous, next: card);
      }
    }
    await _save();
    notifyListeners();
    return importedCards.length;
  }

  Future<void> _save() async {
    final encoded = _storageCodec.encodeStored(_cards);
    await _preferences.setString(_storageKey, encoded);
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
    return card.copyWith(frontImagePath: frontPath, backImagePath: backPath);
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
  }

  Future<void> _cleanupCardImages(WalletCard card) async {
    await _mediaManager.deleteImage(card.frontImagePath);
    await _mediaManager.deleteImage(card.backImagePath);
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
