import 'dart:async';

import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart' as barcode_package;
import 'package:barcode_widget/barcode_widget.dart';

import 'package:card_box/services/tts_service.dart';
import 'package:card_box/theme.dart';

/// An accessibility-first barcode widget.
///
/// Wraps [`BarcodeWidget`] in a `Semantics` node whose label includes
/// the card name and the payload grouped the way a sighted user
/// reads it (e.g. `4844412344` → `4844 4123 44`). A 44 dp
/// `IconButton` with `tooltip: 'Read aloud'` triggers the injected
/// [TtsService] so a non-sighted user can hear the digits.
///
/// Two non-obvious design choices:
///
/// 1. **The read-aloud button is always present.** The TTS *call*
///    is gated by a Settings toggle (so a user can opt out of
///    voice), but the affordance is always visible. A user who
///    enables the toggle then opens a card must not have to
///    re-discover the button on every screen.
/// 2. **Empty payload collapses to `SizedBox.shrink()`.** Matches
///    the existing `BarcodePreview` behaviour and prevents a
///    phantom read-aloud button on cards whose payload has not
///    been captured yet.
///
/// See DR-014 (docs/v_model/decision_record.md) and the accessibility
/// widget initiative in `docs/v_model/plan.md`.
class AnnounceableBarcode extends StatelessWidget {
  const AnnounceableBarcode({
    super.key,
    required this.data,
    required this.format,
    required this.tts,
    this.cardName,
    this.height = 120,
    this.ttsEnabled = true,
  });

  /// The barcode payload. Empty string → the widget renders nothing.
  final String data;

  /// The barcode format. One of `qrcode`/`qr`, `ean13`, `ean8`,
  /// `upca`, `upce`, `code39`, `code93`, `code128`. Unknown values
  /// fall through to `code128` (matches `BarcodePreview`).
  final String format;

  /// The TTS service. Injected so widget tests can pass a
  /// recording fake. The production wire-in lives in the
  /// `ScaffoldMessenger` parent that builds the
  /// `BarcodePresentScreen`.
  final TtsService tts;

  /// The user-facing card name (e.g. "Supermarket X"). Used in
  /// the Semantics label and the spoken text so a user at the
  /// cashier can verify the right card is open.
  final String? cardName;

  /// The render height of the barcode raster. Independent of
  /// the read-aloud button's 44 dp hit target.
  final double height;

  /// Whether tapping the read-aloud button actually triggers
  /// `tts.speak`. Gated by a Settings toggle. The button itself
  /// is always rendered (so the affordance is discoverable), but
  /// when `false` the tap is a no-op. Defaults to `true`; the
  /// parent screen reads the user's preference.
  final bool ttsEnabled;

  /// The number of digits in a single spoken "chunk" for
  /// grouping (e.g. EAN-13 group of 4 + 4 + 4 + 1). 4 is the
  /// common credit-card / loyalty-card reading pattern.
  static const int _groupSize = 4;

  /// Formats [data] for the Semantics label and the spoken text.
  /// Pure function so it is unit-testable in isolation.
  ///
  /// Examples:
  ///   `groupBarcode('4844412344')` → `'4844 4123 44'`
  ///   `groupBarcode('https://x.example/foo')` → unchanged
  ///   `groupBarcode('')` → `''`
  static String groupBarcode(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return '';
    // Only group if the payload is purely digits; alphanumeric
    // payloads (Code 39, Code 128) read better ungrouped, and
    // URLs must not be re-spaced.
    final isAllDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isAllDigits) return trimmed;
    final groups = <String>[];
    for (var i = 0; i < trimmed.length; i += _groupSize) {
      final end = (i + _groupSize).clamp(0, trimmed.length);
      groups.add(trimmed.substring(i, end));
    }
    return groups.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    final tokens = CardBoxThemeTokens.of(context);
    final grouped = groupBarcode(trimmed);
    final label = _buildSemanticsLabel(cardName, grouped);

    return Semantics(
      container: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: BarcodeWidget(
              data: trimmed,
              barcode: _barcodeForFormat(format),
              drawText: true,
              errorBuilder: (_, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Unable to render this code yet.\n$trimmed',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              backgroundColor: tokens.presentationSurface,
              height: height,
            ),
          ),
          const SizedBox(height: 8),
          _ReadAloudButton(
            tts: tts,
            enabled: ttsEnabled,
            cardName: cardName,
            groupedPayload: grouped,
          ),
        ],
      ),
    );
  }

  static String _buildSemanticsLabel(String? cardName, String grouped) {
    // Compose the label so the screen reader speaks it as a
    // single coherent sentence: "[Name]. Barcode [grouped]."
    // The card name is optional; if absent, omit it.
    if (cardName == null || cardName.trim().isEmpty) {
      return 'Barcode $grouped';
    }
    return '${cardName.trim()}. Barcode $grouped.';
  }

  barcode_package.Barcode _barcodeForFormat(String format) {
    switch (format.trim().toLowerCase()) {
      case 'qrcode':
      case 'qr':
        return barcode_package.Barcode.qrCode();
      case 'ean13':
        return barcode_package.Barcode.ean13();
      case 'ean8':
        return barcode_package.Barcode.ean8();
      case 'upca':
        return barcode_package.Barcode.upcA();
      case 'upce':
        return barcode_package.Barcode.upcE();
      case 'code39':
        return barcode_package.Barcode.code39();
      case 'code93':
        return barcode_package.Barcode.code93();
      case 'code128':
      default:
        return barcode_package.Barcode.code128();
    }
  }
}

class _ReadAloudButton extends StatelessWidget {
  const _ReadAloudButton({
    required this.tts,
    required this.enabled,
    required this.cardName,
    required this.groupedPayload,
  });

  final TtsService tts;
  final bool enabled;
  final String? cardName;
  final String groupedPayload;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        tooltip: 'Read aloud',
        icon: const Icon(Icons.volume_up_outlined),
        // 44 dp minimum hit target per lib-screens.md §6 and
        // WCAG 2.5.5. The Material 3 IconButton defaults to
        // 40 dp visual / 48 dp tap; we constrain the visual
        // size to 44 dp and the tap slop is provided by the
        // surrounding Align. Belt-and-suspenders.
        iconSize: 24,
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: enabled ? _onPressed : null,
      ),
    );
  }

  void _onPressed() {
    // Compose the spoken text: the card name (if any) followed
    // by the grouped payload. A short pause is inserted via a
    // full stop — most TTS engines handle a full stop as a
    // sentence boundary and pause briefly.
    final name = cardName?.trim();
    final buffer = StringBuffer();
    if (name != null && name.isNotEmpty) {
      buffer.write(name);
      buffer.write('. ');
    }
    buffer.write(groupedPayload);
    // Fire-and-forget; the TTS service handles its own error
    // reporting. The widget does not await — the user is at
    // the cashier and does not want a UI snackbar mid-flow.
    unawaited(tts.speak(buffer.toString()));
  }
}
