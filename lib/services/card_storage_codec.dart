import 'dart:convert';

import 'package:card_box/models/wallet_card.dart';

class CardStorageCodec {
  static const currentSchemaVersion = 3;
  static const storageFormat = 'card_box_storage';
  static const backupFormat = 'card_box_plain_json';

  CardStoragePayload decodeStored(String rawJson) {
    final decoded = jsonDecode(rawJson);
    return _decodePayload(
      decoded,
      allowLegacyList: true,
      defaultFormat: storageFormat,
    );
  }

  CardStoragePayload decodeBackup(String rawJson) {
    final decoded = jsonDecode(rawJson);
    return _decodePayload(
      decoded,
      allowLegacyList: false,
      defaultFormat: backupFormat,
    );
  }

  String encodeStored(List<WalletCard> cards) {
    return jsonEncode(_envelope(cards));
  }

  String encodeBackup(List<WalletCard> cards) {
    return encodeBackupWithImages(cards, imageAttachments: const []);
  }

  String encodeBackupWithImages(
    List<WalletCard> cards, {
    required List<BackupImagePayload> imageAttachments,
  }) {
    final payload = {
      ..._envelope(cards),
      'format': backupFormat,
      'exportedAt': DateTime.now().toIso8601String(),
      if (imageAttachments.isNotEmpty)
        'images': imageAttachments.map((image) => image.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  CardStoragePayload _decodePayload(
    Object? decoded, {
    required bool allowLegacyList,
    required String defaultFormat,
  }) {
    if (decoded is List) {
      if (!allowLegacyList) {
        throw const FormatException('Backup must be a JSON object.');
      }
      final cards = _decodeCardsFromList(decoded, fromVersion: 1);
      return CardStoragePayload(
        cards: cards,
        schemaVersion: currentSchemaVersion,
        needsRewrite: true,
        imageAttachments: const [],
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Saved data must be a JSON object.');
    }

    final format = decoded['format'] as String? ?? defaultFormat;
    if (format != storageFormat && format != backupFormat) {
      throw FormatException('Unsupported data format: $format');
    }

    final rawVersion =
        decoded['schemaVersion'] ?? decoded['version'] ?? decoded['schema'];
    final schemaVersion = switch (rawVersion) {
      int value => value,
      String value => int.tryParse(value) ?? 1,
      _ => 1,
    };

    if (schemaVersion > currentSchemaVersion) {
      throw FormatException(
        'This data uses schema version $schemaVersion, which is newer than this app supports.',
      );
    }

    final cardsValue = decoded['cards'];
    if (cardsValue is! List) {
      throw const FormatException('Data does not contain a cards list.');
    }

    final cards = _decodeCardsFromList(cardsValue, fromVersion: schemaVersion);
    return CardStoragePayload(
      cards: cards,
      schemaVersion: currentSchemaVersion,
      needsRewrite:
          schemaVersion != currentSchemaVersion || format != defaultFormat,
      imageAttachments: _decodeImageAttachments(decoded['images']),
    );
  }

  List<WalletCard> _decodeCardsFromList(
    List<dynamic> cardsValue, {
    required int fromVersion,
  }) {
    var cardMaps = cardsValue
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();

    for (var version = fromVersion; version < currentSchemaVersion; version++) {
      cardMaps = switch (version) {
        1 => cardMaps.map(_migrateCardV1toV2).toList(),
        2 => cardMaps.map(_migrateCardV2toV3).toList(),
        _ => cardMaps,
      };
    }

    return cardMaps
        .map(WalletCard.fromJson)
        .where((card) => card.id.isNotEmpty)
        .toList();
  }

  Map<String, Object?> _migrateCardV1toV2(Map<String, Object?> source) {
    final migrated = Map<String, Object?>.from(source);
    final createdAt = migrated['createdAt'] as String?;
    final legacyFrontPath =
        _nonEmptyString(migrated['frontImagePath']) ??
        _nonEmptyString(migrated['frontPhotoPath']) ??
        '';
    final legacyBackPath =
        _nonEmptyString(migrated['backImagePath']) ??
        _nonEmptyString(migrated['backPhotoPath']) ??
        '';
    migrated['updatedAt'] =
        _nonEmptyString(migrated['updatedAt']) ??
        createdAt ??
        DateTime.now().toIso8601String();
    migrated['frontImagePath'] = _normalizeLegacyImagePath(legacyFrontPath);
    migrated['backImagePath'] = _normalizeLegacyImagePath(legacyBackPath);
    migrated['barcodePayload'] =
        _nonEmptyString(migrated['barcodePayload']) ?? '';
    migrated['barcodeFormat'] =
        _nonEmptyString(migrated['barcodeFormat']) ?? '';
    migrated['nfcTagSummary'] =
        _nonEmptyString(migrated['nfcTagSummary']) ?? '';
    migrated['favorite'] = migrated['favorite'] as bool? ?? false;
    migrated['archived'] = migrated['archived'] as bool? ?? false;
    final customCategory = _nonEmptyString(migrated['customCategory']);
    migrated['customCategory'] = customCategory;
    return migrated;
  }

  Map<String, Object?> _envelope(List<WalletCard> cards) {
    return {
      'format': storageFormat,
      'schemaVersion': currentSchemaVersion,
      'cards': cards.map((card) => card.toJson()).toList(),
    };
  }

  Map<String, Object?> _migrateCardV2toV3(Map<String, Object?> source) {
    final migrated = Map<String, Object?>.from(source);
    migrated['cardType'] = _nonEmptyString(migrated['cardType']) ?? 'standard';
    migrated['rawOcrText'] = _nonEmptyString(migrated['rawOcrText']) ?? '';
    migrated['contactTitle'] = _nonEmptyString(migrated['contactTitle']) ?? '';
    migrated['contactPhones'] = _normalizeStringList(
      migrated['contactPhones'],
      fallback: _splitLegacyLines(migrated['contactPhone']),
    );
    migrated['contactEmails'] = _normalizeStringList(
      migrated['contactEmails'],
      fallback: _splitLegacyLines(migrated['contactEmail']),
    );
    migrated['contactWebsites'] = _normalizeStringList(
      migrated['contactWebsites'],
      fallback: _splitLegacyLines(migrated['contactWebsite']),
    );
    migrated['contactAddress'] =
        _nonEmptyString(migrated['contactAddress']) ?? '';
    return migrated;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeLegacyImagePath(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('file://')) {
      return trimmed.substring('file://'.length);
    }
    return trimmed;
  }

  List<String> _normalizeStringList(Object? value, {List<String>? fallback}) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return fallback ?? const <String>[];
  }

  List<String> _splitLegacyLines(Object? value) {
    if (value is! String) {
      return const <String>[];
    }
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<BackupImagePayload> _decodeImageAttachments(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) =>
              BackupImagePayload.fromJson(Map<String, Object?>.from(item)),
        )
        .where((image) => image.cardId.isNotEmpty && image.side.isNotEmpty)
        .toList();
  }
}

class CardStoragePayload {
  const CardStoragePayload({
    required this.cards,
    required this.schemaVersion,
    required this.needsRewrite,
    required this.imageAttachments,
  });

  final List<WalletCard> cards;
  final int schemaVersion;
  final bool needsRewrite;
  final List<BackupImagePayload> imageAttachments;
}

class BackupImagePayload {
  const BackupImagePayload({
    required this.cardId,
    required this.side,
    required this.extension,
    required this.bytesBase64,
  });

  final String cardId;
  final String side;
  final String extension;
  final String bytesBase64;

  Map<String, Object?> toJson() {
    return {
      'cardId': cardId,
      'side': side,
      'extension': extension,
      'bytesBase64': bytesBase64,
    };
  }

  factory BackupImagePayload.fromJson(Map<String, Object?> json) {
    return BackupImagePayload(
      cardId: json['cardId'] as String? ?? '',
      side: json['side'] as String? ?? '',
      extension: json['extension'] as String? ?? '.jpg',
      bytesBase64: json['bytesBase64'] as String? ?? '',
    );
  }
}
