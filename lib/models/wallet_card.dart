import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';

class WalletCard {
  const WalletCard({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.issuer = '',
    this.notes = '',
    this.expiryDate,
    this.favorite = false,
    this.archived = false,
    this.frontImagePath = '',
    this.backImagePath = '',
    this.barcodePayload = '',
    this.barcodeFormat = '',
    this.barcodeImagePath = '',
    this.barcodeDisplayValue = '',
    this.barcodeValueType = '',
    this.barcodeStructuredData = '',
    this.barcodeRawBytesHex = '',
    this.barcodeCapturedAt,
    this.nfcTagSummary = '',
    this.compatibilityStatus = CompatibilityStatus.untested,
    this.cardType = CardType.standard,
    this.rawOcrText = '',
    this.contactTitle = '',
    this.contactPhones = const <String>[],
    this.contactEmails = const <String>[],
    this.contactWebsites = const <String>[],
    this.contactAddress = '',
    this.customCategory,
  });

  final String id;
  final String name;
  final String issuer;
  final CardCategory category;
  final String? customCategory;
  final String notes;
  final DateTime? expiryDate;
  final bool favorite;
  final bool archived;
  final String frontImagePath;
  final String backImagePath;
  final String barcodePayload;
  final String barcodeFormat;
  final String barcodeImagePath;
  final String barcodeDisplayValue;
  final String barcodeValueType;
  final String barcodeStructuredData;
  final String barcodeRawBytesHex;
  final DateTime? barcodeCapturedAt;
  final String nfcTagSummary;
  final CompatibilityStatus compatibilityStatus;
  final CardType cardType;
  final String rawOcrText;
  final String contactTitle;
  final List<String> contactPhones;
  final List<String> contactEmails;
  final List<String> contactWebsites;
  final String contactAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get categoryLabel {
    if (category == CardCategory.other &&
        customCategory?.trim().isNotEmpty == true) {
      return customCategory!.trim();
    }
    return category.label;
  }

  bool get hasBarcode => barcodePayload.trim().isNotEmpty;
  bool get hasBarcodeDetails =>
      barcodeDisplayValue.trim().isNotEmpty ||
      barcodeValueType.trim().isNotEmpty ||
      barcodeStructuredData.trim().isNotEmpty ||
      barcodeRawBytesHex.trim().isNotEmpty ||
      barcodeCapturedAt != null;
  bool get hasBarcodeImage => barcodeImagePath.trim().isNotEmpty;
  bool get hasPhotos =>
      frontImagePath.trim().isNotEmpty || backImagePath.trim().isNotEmpty;
  bool get isVisitingCard => cardType == CardType.visitingCard;
  bool get hasContactDetails =>
      isVisitingCard &&
      (contactTitle.trim().isNotEmpty ||
          contactPhones.isNotEmpty ||
          contactEmails.isNotEmpty ||
          contactWebsites.isNotEmpty ||
          contactAddress.trim().isNotEmpty ||
          rawOcrText.trim().isNotEmpty);

  WalletCard copyWith({
    String? id,
    String? name,
    String? issuer,
    CardCategory? category,
    String? customCategory,
    bool clearCustomCategory = false,
    String? notes,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    bool? favorite,
    bool? archived,
    String? frontImagePath,
    String? backImagePath,
    String? barcodePayload,
    String? barcodeFormat,
    String? barcodeImagePath,
    String? barcodeDisplayValue,
    String? barcodeValueType,
    String? barcodeStructuredData,
    String? barcodeRawBytesHex,
    DateTime? barcodeCapturedAt,
    bool clearBarcodeCapturedAt = false,
    String? nfcTagSummary,
    CompatibilityStatus? compatibilityStatus,
    CardType? cardType,
    String? rawOcrText,
    String? contactTitle,
    List<String>? contactPhones,
    List<String>? contactEmails,
    List<String>? contactWebsites,
    String? contactAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletCard(
      id: id ?? this.id,
      name: name ?? this.name,
      issuer: issuer ?? this.issuer,
      category: category ?? this.category,
      customCategory: clearCustomCategory
          ? null
          : customCategory ?? this.customCategory,
      notes: notes ?? this.notes,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      barcodePayload: barcodePayload ?? this.barcodePayload,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      barcodeImagePath: barcodeImagePath ?? this.barcodeImagePath,
      barcodeDisplayValue: barcodeDisplayValue ?? this.barcodeDisplayValue,
      barcodeValueType: barcodeValueType ?? this.barcodeValueType,
      barcodeStructuredData:
          barcodeStructuredData ?? this.barcodeStructuredData,
      barcodeRawBytesHex: barcodeRawBytesHex ?? this.barcodeRawBytesHex,
      barcodeCapturedAt: clearBarcodeCapturedAt
          ? null
          : barcodeCapturedAt ?? this.barcodeCapturedAt,
      nfcTagSummary: nfcTagSummary ?? this.nfcTagSummary,
      compatibilityStatus: compatibilityStatus ?? this.compatibilityStatus,
      cardType: cardType ?? this.cardType,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      contactTitle: contactTitle ?? this.contactTitle,
      contactPhones: contactPhones ?? this.contactPhones,
      contactEmails: contactEmails ?? this.contactEmails,
      contactWebsites: contactWebsites ?? this.contactWebsites,
      contactAddress: contactAddress ?? this.contactAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'issuer': issuer,
      'category': category.name,
      'customCategory': customCategory,
      'notes': notes,
      'expiryDate': expiryDate?.toIso8601String(),
      'favorite': favorite,
      'archived': archived,
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'barcodePayload': barcodePayload,
      'barcodeFormat': barcodeFormat,
      'barcodeImagePath': barcodeImagePath,
      'barcodeDisplayValue': barcodeDisplayValue,
      'barcodeValueType': barcodeValueType,
      'barcodeStructuredData': barcodeStructuredData,
      'barcodeRawBytesHex': barcodeRawBytesHex,
      'barcodeCapturedAt': barcodeCapturedAt?.toIso8601String(),
      'nfcTagSummary': nfcTagSummary,
      'compatibilityStatus': compatibilityStatus.name,
      'cardType': cardType.name,
      'rawOcrText': rawOcrText,
      'contactTitle': contactTitle,
      'contactPhones': contactPhones,
      'contactEmails': contactEmails,
      'contactWebsites': contactWebsites,
      'contactAddress': contactAddress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WalletCard.fromJson(Map<String, Object?> json) {
    return WalletCard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled card',
      issuer: json['issuer'] as String? ?? '',
      category: CardCategory.fromName(json['category'] as String? ?? ''),
      customCategory: json['customCategory'] as String?,
      notes: json['notes'] as String? ?? '',
      expiryDate: _parseDate(json['expiryDate']),
      favorite: json['favorite'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      frontImagePath: json['frontImagePath'] as String? ?? '',
      backImagePath: json['backImagePath'] as String? ?? '',
      barcodePayload: json['barcodePayload'] as String? ?? '',
      barcodeFormat: json['barcodeFormat'] as String? ?? '',
      barcodeImagePath: json['barcodeImagePath'] as String? ?? '',
      barcodeDisplayValue: json['barcodeDisplayValue'] as String? ?? '',
      barcodeValueType: json['barcodeValueType'] as String? ?? '',
      barcodeStructuredData: json['barcodeStructuredData'] as String? ?? '',
      barcodeRawBytesHex: json['barcodeRawBytesHex'] as String? ?? '',
      barcodeCapturedAt: _parseDate(json['barcodeCapturedAt']),
      nfcTagSummary: json['nfcTagSummary'] as String? ?? '',
      compatibilityStatus: CompatibilityStatus.fromName(
        json['compatibilityStatus'] as String? ?? '',
      ),
      cardType: CardType.fromName(json['cardType'] as String? ?? ''),
      rawOcrText: json['rawOcrText'] as String? ?? '',
      contactTitle: json['contactTitle'] as String? ?? '',
      contactPhones: _parseStringList(json['contactPhones']),
      contactEmails: _parseStringList(json['contactEmails']),
      contactWebsites: _parseStringList(json['contactWebsites']),
      contactAddress: json['contactAddress'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
