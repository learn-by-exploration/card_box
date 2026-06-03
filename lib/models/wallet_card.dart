import 'package:card_box/models/card_category.dart';
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
    this.nfcTagSummary = '',
    this.compatibilityStatus = CompatibilityStatus.untested,
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
  final String nfcTagSummary;
  final CompatibilityStatus compatibilityStatus;
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
  bool get hasPhotos =>
      frontImagePath.trim().isNotEmpty || backImagePath.trim().isNotEmpty;

  WalletCard copyWith({
    String? id,
    String? name,
    String? issuer,
    CardCategory? category,
    String? customCategory,
    String? notes,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    bool? favorite,
    bool? archived,
    String? frontImagePath,
    String? backImagePath,
    String? barcodePayload,
    String? barcodeFormat,
    String? nfcTagSummary,
    CompatibilityStatus? compatibilityStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletCard(
      id: id ?? this.id,
      name: name ?? this.name,
      issuer: issuer ?? this.issuer,
      category: category ?? this.category,
      customCategory: customCategory ?? this.customCategory,
      notes: notes ?? this.notes,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      frontImagePath: frontImagePath ?? this.frontImagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      barcodePayload: barcodePayload ?? this.barcodePayload,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      nfcTagSummary: nfcTagSummary ?? this.nfcTagSummary,
      compatibilityStatus: compatibilityStatus ?? this.compatibilityStatus,
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
      'nfcTagSummary': nfcTagSummary,
      'compatibilityStatus': compatibilityStatus.name,
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
      nfcTagSummary: json['nfcTagSummary'] as String? ?? '',
      compatibilityStatus: CompatibilityStatus.fromName(
        json['compatibilityStatus'] as String? ?? '',
      ),
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
}
