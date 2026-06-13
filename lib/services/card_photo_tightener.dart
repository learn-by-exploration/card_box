import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset, Rect;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'package:card_box/services/card_media_service.dart' show cardAspectRatio;

/// Tightens the auto-cropped image returned by the smart scan into a
/// card-shaped region. The smart scan detectors on Android (ML Kit) and iOS
/// (VisionKit) find a "document" bounding box that typically includes some
/// background around the card. The text printed on the card is a strong
/// proxy for the card's location — we run on-device text recognition, union
/// the text-line bounding boxes, then fit the union to the ID-1 card aspect
/// ratio so the saved image is always card-shaped and OCR-friendly.
/// Outcome of an attempt to tighten a scanned card photo. The
/// `bytes` are always usable — either the tightened crop or the
/// original bytes when no improvement was possible. `reason`
/// tells the UI *why* no improvement was made so it can surface a
/// one-time "auto-crop wasn't applied" hint without showing
/// anything when everything worked.
class TightenResult {
  const TightenResult({required this.bytes, required this.reason});

  final Uint8List bytes;
  final TightenReason reason;
}

enum TightenReason {
  /// Tightening succeeded and the bytes are a tighter crop.
  tightened,

  /// No crop was necessary — the image was already card-shaped
  /// (or smaller than the crop window), so the original bytes
  /// are returned unchanged.
  noChange,

  /// The image could not be decoded as a JPEG.
  decodeFailed,

  /// The recognizer could not detect any text on the image, so
  /// there was no basis to compute a tighter region.
  noTextDetected,

  /// A recognizer or other internal step threw. The original
  /// bytes are returned.
  internalError,
}

abstract class CardPhotoTightener {
  /// Returns a [TightenResult] whose `bytes` are the tightest
  /// card-shaped crop the tightener could produce, or the original
  /// bytes when no improvement was possible. This method is
  /// fail-safe by contract: smart scan is a best-effort feature
  /// and tightening is an improvement on top of it, not a
  /// requirement.
  Future<TightenResult> tighten(Uint8List jpegBytes);
}

/// Factory that produces the list of text recognizers used during
/// tightening. Exposed so tests can inject recognizers that return
/// hand-crafted results without spinning up ML Kit.
typedef TextRecognizerFactory = List<TextRecognizer> Function();

/// Default implementation that runs ML Kit text recognition on the input
/// JPEG and crops to the detected text region.
class DefaultCardPhotoTightener implements CardPhotoTightener {
  const DefaultCardPhotoTightener({TextRecognizerFactory? recognizerFactory})
    : _recognizerFactory = recognizerFactory ?? _defaultRecognizerFactory;

  final TextRecognizerFactory _recognizerFactory;

  static List<TextRecognizer> _defaultRecognizerFactory() => <TextRecognizer>[
    TextRecognizer(script: TextRecognitionScript.latin),
    TextRecognizer(script: TextRecognitionScript.japanese),
  ];

  @override
  Future<TightenResult> tighten(Uint8List jpegBytes) async {
    if (jpegBytes.isEmpty) {
      return TightenResult(bytes: jpegBytes, reason: TightenReason.noChange);
    }
    try {
      final decoded = img.decodeJpg(jpegBytes);
      if (decoded == null) {
        return TightenResult(
          bytes: jpegBytes,
          reason: TightenReason.decodeFailed,
        );
      }
      final imageWidth = decoded.width;
      final imageHeight = decoded.height;
      if (imageWidth == 0 || imageHeight == 0) {
        return TightenResult(
          bytes: jpegBytes,
          reason: TightenReason.decodeFailed,
        );
      }

      final tempPath =
          '${Directory.systemTemp.path}/card_box_tighten_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final tempFile = File(tempPath);
      List<Rect> textBoxes = const <Rect>[];
      try {
        await tempFile.writeAsBytes(jpegBytes);
        final inputImage = InputImage.fromFilePath(tempPath);
        textBoxes = await _detectTextBoxes(inputImage);
      } finally {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (error) {
            if (kDebugMode) {
              debugPrint(
                'PhotoTightener: best-effort temp delete failed: $error',
              );
            }
          }
        }
      }

      // If we found no text on the image, there is no basis to
      // compute a tighter region. The caller can choose to surface
      // a one-time hint via the reason field.
      if (textBoxes.isEmpty) {
        return TightenResult(
          bytes: jpegBytes,
          reason: TightenReason.noTextDetected,
        );
      }

      final crop = computeCardCrop(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        textBoxes: textBoxes,
      );

      // If the computed crop is the full image, there is nothing to tighten.
      if (crop.x == 0 &&
          crop.y == 0 &&
          crop.width == imageWidth &&
          crop.height == imageHeight) {
        return TightenResult(bytes: jpegBytes, reason: TightenReason.noChange);
      }

      final cropped = img.copyCrop(
        decoded,
        x: crop.x,
        y: crop.y,
        width: crop.width,
        height: crop.height,
      );
      return TightenResult(
        bytes: Uint8List.fromList(img.encodeJpg(cropped, quality: 92)),
        reason: TightenReason.tightened,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PhotoTightener: crop failed, using original bytes: $error');
      }
      return TightenResult(
        bytes: jpegBytes,
        reason: TightenReason.internalError,
      );
    }
  }

  Future<List<Rect>> _detectTextBoxes(InputImage image) async {
    final recognizers = _recognizerFactory();
    final boxes = <Rect>[];
    try {
      for (final recognizer in recognizers) {
        RecognizedText result;
        try {
          result = await recognizer.processImage(image);
        } catch (error) {
          // A single recognizer failing should not abort tightening.
          if (kDebugMode) {
            debugPrint(
              'PhotoTightener: recognizer.processImage failed: $error',
            );
          }
          continue;
        }
        for (final block in result.blocks) {
          for (final line in block.lines) {
            final box = line.boundingBox;
            if (box.width >= 8 && box.height >= 4) {
              boxes.add(box);
            }
          }
        }
      }
      return boxes;
    } finally {
      for (final recognizer in recognizers) {
        try {
          await recognizer.close();
        } catch (error) {
          if (kDebugMode) {
            debugPrint('PhotoTightener: recognizer.close failed: $error');
          }
        }
      }
    }
  }
}

/// Result of [computeCardCrop]: the integer rectangle to crop the source
/// image to. Coordinates are in source-image pixel space and always lie
/// within `[0, imageWidth] x [0, imageHeight]`.
class CardPhotoCrop {
  const CardPhotoCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardPhotoCrop &&
          other.x == x &&
          other.y == y &&
          other.width == width &&
          other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'CardPhotoCrop($x, $y, $width x $height)';
}

/// Pure geometry: given the image dimensions and the bounding boxes of all
/// detected text lines, compute the tightest card-shaped crop region.
///
/// Algorithm:
/// 1. If no text was found, return an ID-1 center-crop of the full image.
/// 2. Otherwise, union the boxes, add 10% padding, then expand to the ID-1
///    aspect ratio (whichever axis is shorter gets extended symmetrically),
///    and clamp to the image bounds.
///
/// Exposed at the top level so it can be unit-tested without instantiating
/// the recognizer pipeline.
CardPhotoCrop computeCardCrop({
  required int imageWidth,
  required int imageHeight,
  required List<Rect> textBoxes,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return CardPhotoCrop(
      x: 0,
      y: 0,
      width: math.max(0, imageWidth),
      height: math.max(0, imageHeight),
    );
  }

  if (textBoxes.isEmpty) {
    return _idOneCenterCrop(imageWidth, imageHeight);
  }

  // Union all text boxes, then add 10% padding on each side.
  Rect union = textBoxes.first;
  for (var i = 1; i < textBoxes.length; i++) {
    union = union.expandToInclude(textBoxes[i]);
  }
  final padW = union.width * 0.10;
  final padH = union.height * 0.10;
  final padded = Rect.fromLTRB(
    math.max(0.0, union.left - padW),
    math.max(0.0, union.top - padH),
    math.min(imageWidth.toDouble(), union.right + padW),
    math.min(imageHeight.toDouble(), union.bottom + padH),
  );

  // Expand to the ID-1 aspect ratio without rotating the card. Compute the
  // "natural" ID-1 rect that contains the padded region, centered on it.
  final paddedAspect = padded.width / padded.height;
  final double naturalWidth;
  final double naturalHeight;
  if (paddedAspect > cardAspectRatio) {
    // Wider than card → extend vertically, keep padded width.
    naturalWidth = padded.width;
    naturalHeight = padded.width / cardAspectRatio;
  } else {
    // Taller than card (or already card-shaped) → extend horizontally,
    // keep padded height.
    naturalHeight = padded.height;
    naturalWidth = padded.height * cardAspectRatio;
  }
  final paddedCenter = padded.center;
  Rect fitted = Rect.fromCenter(
    center: paddedCenter,
    width: naturalWidth,
    height: naturalHeight,
  );

  // If the natural rect doesn't fit in the image, scale it down uniformly
  // (preserving the ID-1 aspect ratio) so it does. This is preferable to
  // clamping one axis, which would silently break the card aspect ratio.
  if (fitted.width > imageWidth || fitted.height > imageHeight) {
    final scale = math.min(
      imageWidth / fitted.width,
      imageHeight / fitted.height,
    );
    fitted = Rect.fromCenter(
      center: fitted.center,
      width: fitted.width * scale,
      height: fitted.height * scale,
    );
  }

  // If the rect's center is off-image (e.g. card content is near a corner),
  // shifting rather than clamping keeps the ID-1 aspect ratio intact. After
  // scaling, the rect still might be off-screen — shift it back inside.
  var shiftX = 0.0;
  var shiftY = 0.0;
  if (fitted.left < 0) {
    shiftX = -fitted.left;
  } else if (fitted.right > imageWidth) {
    shiftX = imageWidth - fitted.right;
  }
  if (fitted.top < 0) {
    shiftY = -fitted.top;
  } else if (fitted.bottom > imageHeight) {
    shiftY = imageHeight - fitted.bottom;
  }
  if (shiftX != 0 || shiftY != 0) {
    fitted = fitted.shift(Offset(shiftX, shiftY));
  }

  // Round to integers and clamp to image bounds.
  final x = fitted.left.round().clamp(0, imageWidth);
  final y = fitted.top.round().clamp(0, imageHeight);
  final right = fitted.right.round().clamp(0, imageWidth);
  final bottom = fitted.bottom.round().clamp(0, imageHeight);
  return CardPhotoCrop(
    x: x,
    y: y,
    width: math.max(1, right - x),
    height: math.max(1, bottom - y),
  );
}

CardPhotoCrop _idOneCenterCrop(int imageWidth, int imageHeight) {
  final imageAspect = imageWidth / imageHeight;
  if (imageAspect > cardAspectRatio) {
    // Image is wider than the card → crop the sides.
    final newWidth = (imageHeight * cardAspectRatio).round();
    final dx = ((imageWidth - newWidth) / 2).round();
    return CardPhotoCrop(
      x: dx.clamp(0, imageWidth - 1),
      y: 0,
      width: math.max(1, math.min(newWidth, imageWidth)),
      height: imageHeight,
    );
  } else {
    // Image is taller than (or already at) the card → crop top/bottom.
    final newHeight = (imageWidth / cardAspectRatio).round();
    final dy = ((imageHeight - newHeight) / 2).round();
    return CardPhotoCrop(
      x: 0,
      y: dy.clamp(0, imageHeight - 1),
      width: imageWidth,
      height: math.max(1, math.min(newHeight, imageHeight)),
    );
  }
}
