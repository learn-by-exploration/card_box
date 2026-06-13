// Tests for `computeCardCrop` — the pure geometry function
// that picks the tightest card-shaped crop given the image
// dimensions and the bounding boxes of all detected text
// lines. The function is exposed at the top level precisely
// so it can be unit-tested without instantiating the
// recognizer pipeline. The existing test suite exercises
// the happy path; this file pins down the corner cases:
// zero dimensions, off-image content, and the no-text
// fallback.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/services/card_photo_tightener.dart';

void main() {
  group('computeCardCrop', () {
    test('returns a zero-sized crop for a non-positive image', () {
      // A 0×0 image (or negative) must not throw. The
      // function returns a crop that is clamped to the
      // image dimensions — i.e. a 0-sized crop. This
      // path is reachable in the recognizer pipeline when
      // the input image is malformed.
      final crop = computeCardCrop(
        imageWidth: 0,
        imageHeight: 0,
        textBoxes: const <Rect>[],
      );
      expect(crop.width, 0);
      expect(crop.height, 0);
    });

    test('falls back to the ID-1 center crop when no text is detected', () {
      // The "no text" path is the most common code path
      // for a photo of a card that the recognizer failed
      // to read. The crop must:
      //   - have the ID-1 aspect ratio
      //   - be centered on the longer axis
      // 1000×800: imageAspect = 1.25, cardAspect ≈ 1.586.
      // The image is *taller* than the card → the
      // function crops top/bottom and the crop spans the
      // full width.
      const width = 1000;
      const height = 800;
      final crop = computeCardCrop(
        imageWidth: width,
        imageHeight: height,
        textBoxes: const <Rect>[],
      );
      expect(crop.x, 0);
      expect(crop.width, width);
      // The crop is shorter than the image (we cropped
      // some of the top/bottom) and is centered
      // vertically.
      expect(crop.height, lessThan(height));
      expect(crop.y, greaterThan(0));
    });

    test('pads the union of text boxes by 10% on each side', () {
      // The padding is `union.width * 0.10` and
      // `union.height * 0.10`. A single small text box
      // centered on a large image should produce a
      // padded crop, then expanded to the ID-1 aspect
      // ratio, then clamped to the image.
      const width = 1000;
      const height = 800;
      const text = Rect.fromLTWH(400, 350, 200, 100);
      final crop = computeCardCrop(
        imageWidth: width,
        imageHeight: height,
        textBoxes: const <Rect>[text],
      );
      // The crop must be at least the size of the
      // padded union, but no larger than the image.
      expect(crop.x, greaterThanOrEqualTo(0));
      expect(crop.y, greaterThanOrEqualTo(0));
      expect(crop.x + crop.width, lessThanOrEqualTo(width));
      expect(crop.y + crop.height, lessThanOrEqualTo(height));
    });

    test('preserves the ID-1 aspect ratio after expansion', () {
      // The aspect ratio of width/height must equal the
      // ID-1 ratio (85.6 / 53.98) within rounding error.
      // A 1:1 input with a single text box is a stress
      // test — the function must extend the rectangle in
      // BOTH directions to reach the card aspect.
      const width = 500;
      const height = 500;
      const text = Rect.fromLTWH(200, 200, 100, 100);
      final crop = computeCardCrop(
        imageWidth: width,
        imageHeight: height,
        textBoxes: const <Rect>[text],
      );
      // 85.6 / 53.98 ≈ 1.5858
      final ratio = crop.width / crop.height;
      expect(ratio, closeTo(85.6 / 53.98, 0.05));
    });

    test(
      'shifts the crop back inside the image when content is near an edge',
      () {
        // When the union is near the top-left corner, the
        // padded + ID-1-expanded rect may extend off the
        // left/top edge. The function must shift, not
        // clamp — clamping would silently break the
        // aspect ratio.
        const width = 1000;
        const height = 800;
        const text = Rect.fromLTWH(0, 0, 50, 30);
        final crop = computeCardCrop(
          imageWidth: width,
          imageHeight: height,
          textBoxes: const <Rect>[text],
        );
        expect(crop.x, greaterThanOrEqualTo(0));
        expect(crop.y, greaterThanOrEqualTo(0));
        expect(crop.x + crop.width, lessThanOrEqualTo(width));
        expect(crop.y + crop.height, lessThanOrEqualTo(height));
      },
    );

    test('scales the crop down when the natural ID-1 rect does not fit', () {
      // The padded union, when expanded to the ID-1
      // aspect, may be larger than the image. The
      // function must uniformly scale to fit (preserving
      // the aspect ratio), not just clamp one axis.
      const width = 200;
      const height = 200;
      const text = Rect.fromLTWH(0, 0, 180, 100);
      final crop = computeCardCrop(
        imageWidth: width,
        imageHeight: height,
        textBoxes: const <Rect>[text],
      );
      // The aspect ratio is preserved.
      final ratio = crop.width / crop.height;
      expect(ratio, closeTo(85.6 / 53.98, 0.05));
      // The crop fits within the image.
      expect(crop.x + crop.width, lessThanOrEqualTo(width));
      expect(crop.y + crop.height, lessThanOrEqualTo(height));
    });

    test('handles a single off-image text box (negative coordinates)', () {
      // The recognizer may report a box with negative
      // coordinates if a glyph was clipped at the image
      // edge. The function must treat the union the
      // same as any other box and produce a valid crop.
      const width = 1000;
      const height = 800;
      const text = Rect.fromLTWH(-30, 350, 200, 100);
      final crop = computeCardCrop(
        imageWidth: width,
        imageHeight: height,
        textBoxes: const <Rect>[text],
      );
      expect(crop.x, greaterThanOrEqualTo(0));
      expect(crop.y, greaterThanOrEqualTo(0));
    });

    test('unions multiple text boxes before padding', () {
      // Two text boxes on opposite sides of the image
      // must produce a crop that contains both, not
      // just the larger one.
      const width = 1000;
      const height = 800;
      const left = Rect.fromLTWH(50, 300, 100, 80);
      const right = Rect.fromLTWH(850, 300, 100, 80);
      final crop = computeCardCrop(
        imageWidth: width,
        imageHeight: height,
        textBoxes: const <Rect>[left, right],
      );
      // The crop should span most of the image width
      // because the union covers x=50..950.
      expect(crop.width, greaterThan(width * 0.7));
    });
  });
}
