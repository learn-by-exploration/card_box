// Tests for the vCard / MECARD / contact-URI exporters.
// These are the wire formats that flow out of Card Box into
// other apps (Contacts, QR scanners, phone dialers). The
// existing widget tests cover happy-path exports. This file
// pins down the escape semantics, the family/given name
// split, and the silent-failure paths of `ContactActionService`.

import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/contact_action_service.dart';
import 'package:card_box/services/vcard_export_service.dart';

void main() {
  const exporter = VCardExportService();
  const contact = ContactActionService();

  WalletCard card({
    String name = 'Jane Doe',
    String issuer = 'ACME',
    String contactTitle = 'CTO',
    List<String> phones = const ['+1 555 123 4567'],
    List<String> emails = const ['jane@example.test'],
    List<String> websites = const ['https://example.test'],
    String contactAddress = '1 Main St',
    String notes = '',
    String rawOcrText = '',
  }) {
    return WalletCard(
      id: 'c1',
      name: name,
      issuer: issuer,
      contactTitle: contactTitle,
      contactPhones: phones,
      contactEmails: emails,
      contactWebsites: websites,
      contactAddress: contactAddress,
      notes: notes,
      rawOcrText: rawOcrText,
      category: CardCategory.contact,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );
  }

  group('VCardExportService.buildVCard', () {
    test('emits the canonical envelope and FN line', () {
      final out = exporter.buildVCard(card());
      expect(out, startsWith('BEGIN:VCARD\r\n'));
      expect(out, endsWith('END:VCARD\r\n'));
      expect(out, contains('VERSION:3.0'));
      expect(out, contains('FN:Jane Doe'));
    });

    test('splits a multi-word name into family/given (last is family)', () {
      // vCard 3.0 N: format is `family;given;middle;prefix;suffix`.
      // The split convention: the *last* whitespace-separated
      // token is the family name; everything before is the
      // given name. For "Jane Marie Doe" →
      // family = "Doe", given = "Jane Marie".
      final out = exporter.buildVCard(card(name: 'Jane Marie Doe'));
      expect(out, contains('N:Doe;Jane Marie;;;'));
    });

    test('omits N: for a single-word name (cannot split)', () {
      // A one-word name is ambiguous — vCard 3.0 allows the
      // field to be omitted, and the export must NOT emit
      // a partial N: line that downstream parsers will reject.
      final out = exporter.buildVCard(card(name: 'Madonna'));
      expect(out, isNot(contains('\nN:')));
      expect(out, contains('FN:Madonna'));
    });

    test('escapes ;, , \\, and newlines per vCard 3.0', () {
      final out = exporter.buildVCard(
        card(notes: 'line1\nline2; comma, backslash\\end'),
      );
      // The newline becomes the escape sequence \n, the
      // semicolon and comma are backslash-escaped, the
      // backslash itself is doubled.
      expect(out, contains(r'NOTE:line1\nline2\; comma\, backslash\\end'));
    });

    test('omits optional fields when the source is empty', () {
      final out = exporter.buildVCard(
        card(
          issuer: '',
          contactTitle: '',
          contactAddress: '',
          phones: const [],
          emails: const [],
          websites: const [],
        ),
      );
      expect(out, isNot(contains('ORG:')));
      expect(out, isNot(contains('TITLE:')));
      expect(out, isNot(contains('TEL;')));
      expect(out, isNot(contains('EMAIL;')));
      expect(out, isNot(contains('URL:')));
      expect(out, isNot(contains('ADR;')));
    });

    test('emits TEL for each non-empty phone, skipping blanks', () {
      final out = exporter.buildVCard(
        card(phones: const ['+1 555 123 4567', '', '  ']),
      );
      final telCount = '\n'.allMatches(out).where((m) {
        final line = out.substring(m.end).split('\r\n').first;
        return line.startsWith('TEL;');
      }).length;
      expect(telCount, 1);
    });
  });

  group('VCardExportService.suggestedFileName', () {
    test('sanitizes a Latin name to lowercase-with-underscores', () {
      final name = exporter.suggestedFileName(card(name: 'Jane Doe'));
      expect(name, 'jane_doe');
    });

    test('collapses runs of non-alphanumeric characters', () {
      final name = exporter.suggestedFileName(card(name: 'Dr. Jane Doe'));
      expect(name, 'dr_jane_doe');
    });

    test('falls back to "contact" for non-ASCII (regex strips them)', () {
      // The regex is `[^a-z0-9]+` — Unicode letters like
      // 田中 do not match, so the sanitized result is empty
      // and the function returns the fallback.
      final name = exporter.suggestedFileName(card(name: '田中 太郎'));
      expect(name, 'contact');
    });

    test('falls back to "contact" for an empty name', () {
      final name = exporter.suggestedFileName(card(name: ''));
      expect(name, 'contact');
    });
  });

  group('VCardExportService.buildQrPayload', () {
    test('emits a MECARD envelope terminated by ;;', () {
      final out = exporter.buildQrPayload(card());
      expect(out, startsWith('MECARD:'));
      expect(out, contains('N:Jane Doe;'));
      expect(out, contains('TEL:+1 555 123 4567;'));
      // The trailing empty value (;) is the MECARD terminator.
      expect(out, endsWith(';;'));
    });

    test('QR escape strips backslashes and replaces newlines with spaces', () {
      // QR codes cannot carry backslashes or newlines
      // reliably. The QR escape is more aggressive than the
      // vCard escape: backslashes are removed entirely,
      // newlines become spaces.
      final out = exporter.buildQrPayload(
        card(notes: 'line1\nline2; with, colons:'),
      );
      // The escape: \n → space, ; → \;, , → \,, : → \:
      // The trailing `;` is the field terminator, then
      // another `;` is the MECARD envelope terminator.
      expect(out, contains(r'NOTE:line1 line2\; with\, colons\:'));
    });
  });

  group('ContactActionService URI building', () {
    test('phoneUri returns null for empty input', () {
      expect(contact.phoneUri(''), isNull);
      expect(contact.phoneUri('   '), isNull);
    });

    test('phoneUri returns a tel: URI for non-empty input', () {
      final uri = contact.phoneUri('+1 555 123 4567');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'tel');
      // The path is percent-encoded; the rendered form is what
      // `tel:` dialers consume.
      expect(uri.toString(), startsWith('tel:+1'));
    });

    test('emailUri returns null for empty input', () {
      expect(contact.emailUri(''), isNull);
    });

    test('emailUri returns a mailto: URI for non-empty input', () {
      final uri = contact.emailUri('jane@example.test');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'mailto');
      expect(uri.path, 'jane@example.test');
    });

    test('websiteUri prepends https:// when no scheme is present', () {
      final uri = contact.websiteUri('example.test');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'example.test');
    });

    test('websiteUri preserves an explicit http:// scheme', () {
      final uri = contact.websiteUri('http://example.test/path');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'http');
      expect(uri.host, 'example.test');
      expect(uri.path, '/path');
    });

    test('websiteUri returns null for empty input', () {
      expect(contact.websiteUri(''), isNull);
    });
  });
}
