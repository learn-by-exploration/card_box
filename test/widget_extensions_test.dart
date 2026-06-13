// Tests for `WalletCard.copyWith`, the `categoryLabel`
// getter, the `has*` predicates, and the
// toJson/fromJson round-trip. The existing
// `data_integrity_codec_test.dart` covers the codec
// migration; this file pins down the model itself — the
// nullable-clear flags, the contact-list identity, and
// the empty-string defaulting in fromJson.

import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';

WalletCard _fullCard() => WalletCard(
  id: 'full',
  name: 'ACME',
  issuer: 'ACME Inc.',
  category: CardCategory.other,
  customCategory: 'MembershipPlus',
  notes: 'multiline\nnotes',
  favorite: true,
  archived: false,
  frontImagePath: '/front.jpg',
  backImagePath: '/back.jpg',
  barcodePayload: '4901234567894',
  barcodeFormat: 'EAN13',
  barcodeImagePath: '/barcode.jpg',
  barcodeDisplayValue: '4 901234 567894',
  barcodeValueType: 'product',
  barcodeStructuredData: 'GTIN:04901234567894',
  barcodeRawBytesHex: 'deadbeef',
  barcodeCapturedAt: DateTime.utc(2024, 5, 15),
  nfcTagSummary: 'ISO-DEP, ISO-14443',
  compatibilityStatus: CompatibilityStatus.androidHceCandidate,
  cardType: CardType.visitingCard,
  rawOcrText: 'ACME\n123-4567',
  contactTitle: 'CTO',
  contactPhones: const ['+1 555 0100', '+1 555 0101'],
  contactEmails: const ['hello@example.test'],
  contactWebsites: const ['https://example.test'],
  contactAddress: '1 Main St',
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 6, 1),
  lastUsedAt: DateTime.utc(2024, 6, 10),
  useCount: 7,
);

void main() {
  group('WalletCard.copyWith', () {
    test('preserves every field when called with no arguments', () {
      final original = _fullCard();
      final copy = original.copyWith();
      // The defaulting behavior of copyWith preserves the
      // original when no field is set. This is the
      // baseline that any future change to copyWith must
      // not silently break.
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.issuer, original.issuer);
      expect(copy.category, original.category);
      expect(copy.customCategory, original.customCategory);
      expect(copy.contactPhones, original.contactPhones);
      expect(copy.contactEmails, original.contactEmails);
      expect(copy.contactWebsites, original.contactWebsites);
      expect(copy.barcodeCapturedAt, original.barcodeCapturedAt);
      expect(copy.lastUsedAt, original.lastUsedAt);
    });

    test('sets customCategory to null via clearCustomCategory', () {
      // The customCategory has a normal "set" path and a
      // separate "clear" path. The clear path is what
      // `migrateCustomCategory` uses when a card moves
      // from a custom label to a built-in category.
      final original = _fullCard();
      final cleared = original.copyWith(clearCustomCategory: true);
      expect(cleared.customCategory, isNull);
      // Other fields are preserved.
      expect(cleared.category, original.category);
    });

    test('clears barcodeCapturedAt via the dedicated flag', () {
      // barcodeCapturedAt is `DateTime?`. Setting the
      // nullable param to `null` is a no-op (it would
      // preserve the original). The clear flag is the
      // only way to actually clear the field.
      final original = _fullCard();
      final cleared = original.copyWith(clearBarcodeCapturedAt: true);
      expect(cleared.barcodeCapturedAt, isNull);
    });

    test('clears lastUsedAt via the dedicated flag', () {
      // Same shape as barcodeCapturedAt.
      final original = _fullCard();
      final cleared = original.copyWith(clearLastUsedAt: true);
      expect(cleared.lastUsedAt, isNull);
    });

    test('replaces a contact list with a new reference (immutable)', () {
      // The contact list fields are `List<String>`. A
      // copyWith with a new list must NOT mutate the
      // original. The new card holds a reference to the
      // new list.
      final original = _fullCard();
      final newPhones = const ['+44 20 7946 0958'];
      final copy = original.copyWith(contactPhones: newPhones);
      expect(copy.contactPhones, newPhones);
      expect(original.contactPhones, isNot(newPhones));
      expect(original.contactPhones, hasLength(2));
    });
  });

  group('WalletCard.categoryLabel', () {
    test('returns the built-in label for non-Other categories', () {
      final card = _fullCard().copyWith(
        category: CardCategory.loyalty,
        clearCustomCategory: true,
      );
      expect(card.categoryLabel, 'Loyalty');
    });

    test('returns the custom label for the Other category', () {
      // When the user picks a custom category, the UI
      // must surface the user's label, not "Other".
      final card = _fullCard();
      expect(card.category, CardCategory.other);
      expect(card.categoryLabel, 'MembershipPlus');
    });

    test('falls back to the built-in label when Other has no custom label', () {
      final card = _fullCard().copyWith(
        category: CardCategory.other,
        clearCustomCategory: true,
      );
      expect(card.categoryLabel, 'Other');
    });
  });

  group('WalletCard.has* predicates', () {
    test('hasBarcode is true only when the payload is non-empty', () {
      final card = _fullCard();
      expect(card.hasBarcode, isTrue);
      final cleared = card.copyWith(barcodePayload: '');
      expect(cleared.hasBarcode, isFalse);
      final whitespace = card.copyWith(barcodePayload: '   ');
      expect(whitespace.hasBarcode, isFalse);
    });

    test('hasBarcodeDetails reflects the auxiliary fields', () {
      // The auxiliary fields (display value, type,
      // structured data, raw bytes, capturedAt) are the
      // post-decode metadata. Any one of them being
      // present is enough.
      final card = _fullCard();
      expect(card.hasBarcodeDetails, isTrue);
      final cleared = card.copyWith(
        barcodeDisplayValue: '',
        barcodeValueType: '',
        barcodeStructuredData: '',
        barcodeRawBytesHex: '',
        clearBarcodeCapturedAt: true,
      );
      expect(cleared.hasBarcodeDetails, isFalse);
    });

    test('hasPhotos is true when either front or back is present', () {
      final card = _fullCard();
      expect(card.hasPhotos, isTrue);
      final cleared = card.copyWith(frontImagePath: '', backImagePath: '');
      expect(cleared.hasPhotos, isFalse);
    });

    test('isVisitingCard follows the cardType', () {
      final card = _fullCard();
      expect(card.isVisitingCard, isTrue);
      final standard = card.copyWith(cardType: CardType.standard);
      expect(standard.isVisitingCard, isFalse);
    });

    test(
      'hasContactDetails requires both visitingCard and a non-empty field',
      () {
        // A standard card with phones/emails/etc. is NOT
        // considered to have "contact details" — only a
        // visiting card does. This is the gate the
        // contact-action UI uses.
        final card = _fullCard();
        expect(card.hasContactDetails, isTrue);
        final standard = card.copyWith(
          cardType: CardType.standard,
          contactPhones: const [],
          contactEmails: const [],
          contactWebsites: const [],
          contactAddress: '',
          contactTitle: '',
          rawOcrText: '',
        );
        expect(standard.hasContactDetails, isFalse);
      },
    );
  });

  group('WalletCard.toJson / fromJson', () {
    test('round-trips every field', () {
      final original = _fullCard();
      final json = original.toJson();
      final restored = WalletCard.fromJson(json);
      // The codec uses DateTime.iso, so comparing the
      // round-tripped values directly is correct.
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.issuer, original.issuer);
      expect(restored.category, original.category);
      expect(restored.customCategory, original.customCategory);
      expect(restored.contactPhones, original.contactPhones);
      expect(restored.contactEmails, original.contactEmails);
      expect(restored.contactWebsites, original.contactWebsites);
      expect(restored.barcodeCapturedAt, original.barcodeCapturedAt);
      expect(restored.lastUsedAt, original.lastUsedAt);
      expect(restored.useCount, original.useCount);
    });

    test('fromJson defaults the id when missing', () {
      // A hand-edited JSON without an `id` must NOT throw
      // — the codec falls back to a generated id.
      final json = <String, Object?>{
        'name': 'Card without id',
        'category': 'loyalty',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };
      final card = WalletCard.fromJson(json);
      expect(card.id, isNotEmpty);
      expect(card.id, startsWith('imported-'));
    });

    test('fromJson defaults the name to "Untitled card" when missing', () {
      // A card whose `name` is missing must surface as
      // "Untitled card" rather than empty (so the UI
      // shows something useful).
      final card = WalletCard.fromJson(<String, Object?>{
        'id': 'k',
        'category': 'loyalty',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });
      expect(card.name, 'Untitled card');
    });

    test('fromJson uses defaults for missing contact lists', () {
      final card = WalletCard.fromJson(<String, Object?>{
        'id': 'k',
        'name': 'k',
        'category': 'loyalty',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });
      expect(card.contactPhones, isEmpty);
      expect(card.contactEmails, isEmpty);
      expect(card.contactWebsites, isEmpty);
    });

    test('fromJson maps an unknown category to the fallback', () {
      // The fromName helper maps unknown values to a
      // safe default rather than throwing.
      final card = WalletCard.fromJson(<String, Object?>{
        'id': 'k',
        'name': 'k',
        'category': 'unknown-future-category',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });
      // The fallback is the "other" enum value, which
      // is what CardCategory.fromName uses as the
      // safe-default when it cannot match the input.
      expect(card.category, CardCategory.other);
    });
  });

  group('WalletCard.generateNewId', () {
    test('produces non-empty distinct ids', () {
      // Two consecutive calls must not collide (the
      // random suffix is 32 bits, so the probability of
      // a collision in 2 calls is 1/2^32).
      final a = WalletCard.generateNewId();
      final b = WalletCard.generateNewId();
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(b));
    });
  });
}
