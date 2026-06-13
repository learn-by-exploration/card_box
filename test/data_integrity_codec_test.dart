// Targeted tests for `CardStorageCodec`. The codec is the only line of
// defense between a hand-edited or older-version backup and a
// usable `WalletCard`. These tests pin down the migration paths
// and the per-field round-trip that the existing test suite does
// not exercise.
//
// Most of these are regression tests: the production code
// documents each migration step with a comment, and the tests
// assert the contract that comment describes.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/card_storage_codec.dart';

void main() {
  final codec = CardStorageCodec();

  group('CardStorageCodec v1->v2 migration', () {
    test('synthesizes defaults when every optional field is missing', () {
      // A v1 envelope with only the four required columns should
      // round-trip through `_migrateCardV1toV2` to a fully-formed
      // card whose defaults are stable.
      final raw = jsonEncode({
        'format': 'card_box_storage',
        'schemaVersion': 1,
        'cards': [
          {
            'id': 'c1',
            'name': 'Minimal v1 card',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
          },
        ],
      });

      final payload = codec.decodeStored(raw);

      final card = payload.cards.single;
      // The codec stamps `updatedAt` to the createdAt string when
      // it is missing — that is the "fall back to createdAt" path.
      expect(card.updatedAt.toIso8601String(), '2024-01-01T00:00:00.000Z');
      expect(card.frontImagePath, '');
      expect(card.backImagePath, '');
      expect(card.barcodePayload, '');
      expect(card.barcodeFormat, '');
      expect(card.nfcTagSummary, '');
      expect(card.favorite, isFalse);
      expect(card.archived, isFalse);
      expect(card.customCategory, isNull);
    });

    test('strips file:// URIs from legacy frontPhotoPath', () {
      // Older builds stored a `file://` prefix; the v1->v2 step
      // must remove it so the path is usable on every platform.
      final raw = jsonEncode({
        'format': 'card_box_storage',
        'schemaVersion': 1,
        'cards': [
          {
            'id': 'c1',
            'name': 'Card with file:// photo',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'frontPhotoPath': 'file:///sdcard/Pictures/card_front.jpg',
          },
        ],
      });

      final payload = codec.decodeStored(raw);

      expect(
        payload.cards.single.frontImagePath,
        '/sdcard/Pictures/card_front.jpg',
      );
    });

    test('prefers frontImagePath over frontPhotoPath when both are set', () {
      // Newer v1 builds had already moved to `frontImagePath`; the
      // alias is the legacy fallback. If both are present, the
      // primary key wins.
      final raw = jsonEncode({
        'format': 'card_box_storage',
        'schemaVersion': 1,
        'cards': [
          {
            'id': 'c1',
            'name': 'Card with both image keys',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'frontImagePath': '/new/path.jpg',
            'frontPhotoPath': '/old/path.jpg',
          },
        ],
      });

      final payload = codec.decodeStored(raw);

      expect(payload.cards.single.frontImagePath, '/new/path.jpg');
    });
  });

  group('CardStorageCodec v3->v4 / v4->v5 migration', () {
    test('tolerates a null barcodeCapturedAt on a v3 card', () {
      // A v3 card whose `barcodeCapturedAt` was null (the field
      // was added in v4) must round-trip without throwing.
      final raw = jsonEncode({
        'format': 'card_box_storage',
        'schemaVersion': 3,
        'cards': [
          {
            'id': 'c1',
            'name': 'V3 card',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'updatedAt': '2024-01-02T00:00:00.000Z',
            'barcodePayload': '1234',
            'barcodeCapturedAt': null,
          },
        ],
      });

      final payload = codec.decodeStored(raw);

      final card = payload.cards.single;
      expect(card.barcodeCapturedAt, isNull);
      // V3->V4 fills these defaults.
      expect(card.barcodeDisplayValue, '');
      expect(card.barcodeValueType, '');
      expect(card.barcodeStructuredData, '');
      expect(card.barcodeRawBytesHex, '');
    });

    test('strips file:// from a v4 barcodeImagePath', () {
      // A v4 card whose barcode image was written with a file://
      // prefix (early importer bug) must be normalized by v4->v5.
      final raw = jsonEncode({
        'format': 'card_box_storage',
        'schemaVersion': 4,
        'cards': [
          {
            'id': 'c1',
            'name': 'V4 card',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
            'updatedAt': '2024-01-02T00:00:00.000Z',
            'barcodeImagePath': 'file:///cache/barcode.jpg',
          },
        ],
      });

      final payload = codec.decodeStored(raw);

      expect(payload.cards.single.barcodeImagePath, '/cache/barcode.jpg');
    });
  });

  group('CardStorageCodec payload validation', () {
    test('rejects a schema version newer than the app supports', () {
      final raw = jsonEncode({
        'format': 'card_box_storage',
        'schemaVersion': 999,
        'cards': [],
      });

      expect(() => codec.decodeBackup(raw), throwsA(isA<FormatException>()));
    });

    test('rejects a backup that is not a JSON object', () {
      // `decodeBackup` is stricter than `decodeStored` — it must
      // not accept a top-level list. The legacy path is the only
      // place a list is acceptable.
      expect(() => codec.decodeBackup('[]'), throwsA(isA<FormatException>()));
    });

    test('rejects an envelope without a cards list', () {
      final raw = jsonEncode({
        'format': 'card_box_plain_json',
        'schemaVersion': 5,
      });

      expect(() => codec.decodeBackup(raw), throwsA(isA<FormatException>()));
    });

    test('rejects an unknown data format', () {
      final raw = jsonEncode({
        'format': 'something_else',
        'schemaVersion': 5,
        'cards': [],
      });

      expect(() => codec.decodeBackup(raw), throwsA(isA<FormatException>()));
    });
  });

  group('CardStorageCodec round-trip preserves every WalletCard field', () {
    // The existing round-trip test in widget_test.dart covers a
    // handful of common fields. This test pins down every
    // optional field, including the ones that JSON round-trips
    // are most likely to drop (the `barcode*` family, the
    // `lastUsedAt` DateTime, the contact list fields).
    test('round-trips a fully populated card through backup', () {
      final created = DateTime.utc(2024, 1, 1);
      final updated = DateTime.utc(2024, 6, 1);
      final captured = DateTime.utc(2024, 5, 15);
      final used = DateTime.utc(2024, 6, 10);
      final original = WalletCard(
        id: 'full-card',
        name: 'Full card',
        issuer: 'Issuer',
        category: CardCategory.other,
        customCategory: 'MembershipPlus',
        notes: 'Multiline\nnotes',
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
        barcodeCapturedAt: captured,
        nfcTagSummary: 'ISO-DEP, ISO-14443',
        compatibilityStatus: CompatibilityStatus.androidHceCandidate,
        cardType: CardType.visitingCard,
        rawOcrText: 'raw ocr line\nsecond line',
        contactTitle: 'CTO',
        contactPhones: const ['+1-555-0100', '+1-555-0101'],
        contactEmails: const ['hello@example.test'],
        contactWebsites: const ['https://example.test'],
        contactAddress: '1 Main St, Springfield',
        createdAt: created,
        updatedAt: updated,
        lastUsedAt: used,
        useCount: 7,
      );

      final encoded = codec.encodeBackup([original]);
      final decoded = codec.decodeBackup(encoded).cards.single;

      // Compare field by field — `==` on WalletCard is structural
      // value equality, but pinning each field makes a regression
      // message obvious.
      expect(decoded.id, original.id);
      expect(decoded.name, original.name);
      expect(decoded.issuer, original.issuer);
      expect(decoded.category, original.category);
      expect(decoded.customCategory, original.customCategory);
      expect(decoded.notes, original.notes);
      expect(decoded.favorite, original.favorite);
      expect(decoded.archived, original.archived);
      expect(decoded.frontImagePath, original.frontImagePath);
      expect(decoded.backImagePath, original.backImagePath);
      expect(decoded.barcodePayload, original.barcodePayload);
      expect(decoded.barcodeFormat, original.barcodeFormat);
      expect(decoded.barcodeImagePath, original.barcodeImagePath);
      expect(decoded.barcodeDisplayValue, original.barcodeDisplayValue);
      expect(decoded.barcodeValueType, original.barcodeValueType);
      expect(decoded.barcodeStructuredData, original.barcodeStructuredData);
      expect(decoded.barcodeRawBytesHex, original.barcodeRawBytesHex);
      expect(decoded.barcodeCapturedAt, captured);
      expect(decoded.nfcTagSummary, original.nfcTagSummary);
      expect(decoded.compatibilityStatus, original.compatibilityStatus);
      expect(decoded.cardType, original.cardType);
      expect(decoded.rawOcrText, original.rawOcrText);
      expect(decoded.contactTitle, original.contactTitle);
      expect(decoded.contactPhones, original.contactPhones);
      expect(decoded.contactEmails, original.contactEmails);
      expect(decoded.contactWebsites, original.contactWebsites);
      expect(decoded.contactAddress, original.contactAddress);
      expect(decoded.createdAt, created);
      expect(decoded.updatedAt, updated);
      expect(decoded.lastUsedAt, used);
      expect(decoded.useCount, original.useCount);
    });
  });

  group('CardStorageCodec corrupt-card skipping', () {
    test('skips a single card whose v2->v3 migration throws', () {
      // The codec's contract is that one corrupt card must not
      // poison the rest of the import. A v2 card with a non-string
      // `contactPhone` exercises the `_splitLegacyLines` guard
      // (which only handles `String`).
      final raw = jsonEncode({
        'format': 'card_box_plain_json',
        'schemaVersion': 2,
        'cards': [
          {
            'id': 'bad',
            'name': 'Bad card',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
            // A list, not a string — `_splitLegacyLines` is the
            // only place that consumes this; it returns an empty
            // list, but the surrounding cast in v2->v3 may still
            // throw depending on the field. Either way the codec
            // must skip the card, not abort the whole decode.
            'contactPhone': ['+1-555-0100', '+1-555-0101'],
          },
          {
            'id': 'good',
            'name': 'Good card',
            'category': 'loyalty',
            'createdAt': '2024-01-01T00:00:00.000Z',
          },
        ],
      });

      final payload = codec.decodeBackup(raw);

      // The good card must survive even when its sibling is
      // skipped.
      expect(payload.cards.map((c) => c.id), contains('good'));
    });
  });
}
