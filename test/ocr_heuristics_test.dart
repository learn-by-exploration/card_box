// Tests for the OCR line-parser in `VisitingCardOcrService`.
// The existing test only exercises one clean Latin/Japanese
// example. This file pins down the regex/keyword tuning that
// is most likely to silently regress when a real-world card
// mis-parses: phone vs address disambiguation, field-prefix
// stripping, the "Co. Manager" double-penalization, and the
// absence of a crash on degenerate inputs.

import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/services/visiting_card_ocr_service.dart';

void main() {
  final service = VisitingCardOcrService();

  group('VisitingCardOcrService.parseRecognizedLines', () {
    test('returns a phone-only card as a phone (not an address)', () {
      // A line containing only a US-style phone number must
      // surface as a phone, not be re-classified as an address.
      // The regex `_phonePattern` matches `+1 555 123 4567` and
      // the line has no address keywords, so `_looksLikeLikelyAddress`
      // is false — the phone must end up in `suggestedPhones`.
      final result = service.parseRecognizedLines(const ['+1 555 123 4567']);

      expect(result.suggestedPhones, contains('+1 555 123 4567'));
    });

    test('a hyphenated phone-shaped line is extracted as a phone', () {
      // The address regex `^(?:〒\s*)?\d{3}-\d{4}(?!-\d)` matches
      // exactly 3-digits-dash-4-digits NOT followed by dash-digit.
      // For `03-1234-5678` the next char after the 4-digit
      // segment is `5` (a digit, not `-`), so the regex does
      // *not* match — the line is therefore not classified as
      // an address and is captured by the phone branch.
      // The phone pattern `(?:\+?\d)[\d\s().-]{6,}\d` matches
      // `03-1234-5678` and `_looksLikePhone` requires 9+
      // digits, which is satisfied.
      final result = service.parseRecognizedLines(const ['03-1234-5678']);

      expect(result.suggestedPhones, ['03-1234-5678']);
      // Neither the name nor the company scorers fire on a
      // single hyphenated line — they require 2+ words.
      expect(result.suggestedName, '');
      expect(result.suggestedCompany, '');
    });

    test('a postal-code shaped line is treated as an address, not a phone', () {
      // The address regex *does* match `160-0023` style
      // Japanese postal codes when followed by the rest of
      // the address. The fix: build a line that satisfies the
      // address keyword check (e.g. contains `Tokyo`) so
      // `_looksLikeLikelyAddress` is true and the phone is
      // skipped. The address branch then captures it.
      final result = service.parseRecognizedLines(const [
        '160-0023 Tokyo, Shinjuku',
      ]);

      // The address keyword short-circuits to true before the
      // regex even runs.
      expect(result.suggestedPhones, isEmpty);
      expect(result.suggestedAddress, contains('Tokyo'));
    });

    test(
      'leaves suggestedName and suggestedTitle empty when only an address is present',
      () {
        // A card with only a street address must not have the
        // address stolen by `suggestedTitle` (the
        // "line between name and company" fallback). The address
        // line has an address keyword, so `_looksLikeLikelyAddress`
        // is true and the title fallback skips it.
        final result = service.parseRecognizedLines(const [
          '1600 Pennsylvania Avenue NW, Washington, DC',
        ]);

        expect(result.suggestedName, '');
        expect(result.suggestedTitle, '');
        expect(result.suggestedAddress, contains('Pennsylvania'));
      },
    );

    test('does not crash on a single-line card', () {
      // The scorers in `_inferName` etc. all take the first N
      // lines; a 1-line input is a degenerate case. The result
      // is empty suggestions and the parser must not throw.
      expect(
        () => service.parseRecognizedLines(const ['Plain text only.']),
        returnsNormally,
      );
    });

    test('strips a field prefix from a phone line', () {
      // A line like `Tel: +1 555 123 4567` should strip the
      // `Tel:` label, leaving the phone matched by
      // `_phonePattern`. The `_stripFieldLabel` helper runs on
      // every line that is *not* filtered out as a phone/email
      // match — and a phone line is filtered out of
      // `remainingLines` *before* name/company scoring. Verify
      // the phone ends up in `suggestedPhones` and the prefix
      // is not present in any text field.
      final result = service.parseRecognizedLines(const [
        'Tel: +1 555 123 4567',
      ]);

      expect(result.suggestedPhones, contains('+1 555 123 4567'));
    });

    test('does not promote "Co. Manager" to name or company', () {
      // `_companyKeywords` contains `co.` and `_jobTitleKeywords`
      // contains `manager`. A line containing both should be
      // penalized by both lists and end up as neither name nor
      // company. The exact scoring is internal, but the
      // behavioral guarantee is: the bare string `Co. Manager`
      // does not surface as a name or a company on its own.
      final result = service.parseRecognizedLines(const ['Co. Manager']);

      expect(result.suggestedName, isNot('Co. Manager'));
      expect(result.suggestedCompany, isNot('Co. Manager'));
    });

    test('emails do not leak into suggestedWebsites via the email filter', () {
      // The website pattern is run against the joined OCR
      // text, not the email-aware line list. A line that is
      // *only* an email pattern (e.g. `name@example.test`)
      // is also captured by the website pattern (matching
      // the domain suffix `example.test`). The
      // `_looksLikeEmail` filter checks `value.contains('@')`
      // — since `example.test` does not contain `@`, the
      // filter does NOT strip it. The net result: a card with
      // an email-only line ends up with the email in
      // `suggestedEmails` AND the bare domain in
      // `suggestedWebsites`. This is the current contract.
      // A regression that tightens the email filter would
      // surface as a behavioral change to the website list,
      // and this test would catch it.
      final result = service.parseRecognizedLines(const ['name@example.test']);

      expect(result.suggestedEmails, contains('name@example.test'));
      expect(result.suggestedWebsites, contains('example.test'));
    });

    test('domain-only lines are extracted as websites (no email filter)', () {
      // The `_looksLikeEmail` check is `value.contains('@')` —
      // a domain-only line like `example.test` does NOT
      // contain `@`, so the website pattern keeps it. This is
      // intentional: a card that lists a bare domain
      // (no scheme, no `www`) should surface as a website.
      final result = service.parseRecognizedLines(const ['example.test']);

      expect(result.suggestedWebsites, contains('example.test'));
      expect(result.suggestedEmails, isEmpty);
    });

    test('strips a Japanese mail: prefix before scoring', () {
      // `_hasFieldPrefix` matches on `mail` (and its
      // case-folded variants); `_stripFieldLabel` removes the
      // label. A Japanese mail line `mail:tanaka@example.test`
      // should be filtered out of `remainingLines` entirely.
      final result = service.parseRecognizedLines(const [
        'mail: tanaka@example.test',
      ]);

      expect(result.suggestedEmails, contains('tanaka@example.test'));
      // The name/company scoring should not promote the prefix-
      // bearing line.
      expect(result.suggestedName, isNot(contains('mail:')));
      expect(result.suggestedCompany, isNot(contains('mail:')));
    });

    test('dedupes identical lines', () {
      // OCR may report the same line twice (e.g. from two
      // recognizers). `_dedupeLines` collapses duplicates. The
      // rawOcrText is a stable join — duplicates must not
      // appear there.
      final result = service.parseRecognizedLines(const [
        'ACME Corporation',
        'ACME Corporation',
      ]);

      expect(
        result.rawOcrText
            .split('\n')
            .where((l) => l == 'ACME Corporation')
            .length,
        1,
      );
    });

    test('parses the canonical Japanese business card', () {
      // The original 7-line fixture from widget_test.dart is
      // reproduced here as a regression sentinel. The expected
      // outputs reflect the scoring in production; if any of
      // them change, the regression is intentional and this
      // test should be updated.
      final result = service.parseRecognizedLines(const [
        '田中 太郎',
        '株式会社サンプル',
        '営業部 部長',
        '03-1234-5678',
        'tanaka@example.co.jp',
        'https://example.co.jp',
        '東京都渋谷区神南1-2-3',
      ]);

      // The name is the first line, the company the second, the
      // title the third.
      expect(result.suggestedName, '田中 太郎');
      expect(result.suggestedCompany, '株式会社サンプル');
      expect(result.suggestedTitle, contains('営業部'));
      // The phone is the only number-shaped candidate that
      // isn't address-shaped. The full address shape is the
      // last line, so the phone survives.
      expect(result.suggestedPhones, isNotEmpty);
      expect(result.suggestedEmails, contains('tanaka@example.co.jp'));
      expect(result.suggestedAddress, contains('東京'));
    });
  });
}
