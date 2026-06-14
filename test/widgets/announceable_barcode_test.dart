import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/services/tts_service.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/announceable_barcode.dart';

/// A recording fake TTS service. The test owns the instance, so each
/// test gets a fresh empty list. Mirrors the existing
/// `MemorySecureStore` / `RecordingXxx` test helpers in
/// `test/test_support.dart`.
class _RecordingTts implements TtsService {
  final List<String> spoken = <String>[];
  final List<int> stopCalls = <int>[];
  bool _isSpeaking = false;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    _isSpeaking = true;
  }

  @override
  Future<void> stop() async {
    stopCalls.add(1);
    _isSpeaking = false;
  }

  @override
  bool get isSpeaking => _isSpeaking;
}

Future<void> _pumpWidget(
  WidgetTester tester, {
  required TtsService tts,
  String data = '4844412344',
  String format = 'code128',
  String? cardName = 'Test Card',
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: cardBoxLightTheme,
      home: Scaffold(
        // textScaler is the new Flutter 3.16+ name; the
        // legacy `textScaleFactor` is deprecated. Wrap here
        // so the 200% test can override it.
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: AnnounceableBarcode(
            data: data,
            format: format,
            tts: tts,
            cardName: cardName,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AnnounceableBarcode', () {
    testWidgets('sets a Semantics label that includes the card name and the '
        'grouped payload', (tester) async {
      final tts = _RecordingTts();
      await _pumpWidget(
        tester,
        tts: tts,
        data: '4844412344',
        cardName: 'Supermarket X',
      );

      // Find the Semantics node that wraps the widget. We use
      // a label-contains matcher so the test does not pin the
      // exact wording (e.g. "Member number" vs. "Barcode").
      final semantics = tester.getSemantics(find.byType(AnnounceableBarcode));
      expect(
        semantics.label,
        contains('Supermarket X'),
        reason:
            'Card name should appear in the Semantics label '
            'so a screen-reader user hears which card is open.',
      );
      expect(
        semantics.label,
        contains('4844 4123 44'),
        reason:
            'Payload should be grouped with spaces, the way '
            'a sighted user reads it. "4844412344" → "4844 4123 '
            '44".',
      );
    });

    testWidgets('renders a "Read aloud" button with a 44 dp hit target', (
      tester,
    ) async {
      final tts = _RecordingTts();
      await _pumpWidget(tester, tts: tts);

      // The button must be findable by tooltip (a11y contract).
      final button = find.byTooltip('Read aloud');
      expect(
        button,
        findsOneWidget,
        reason:
            'A read-aloud button must be present so a '
            'screen-reader user can trigger TTS.',
      );

      // The button's render box must be at least 44 dp in both
      // dimensions. WCAG 2.5.5 (Target Size) and the project
      // lib-screens.md §6 rule.
      final size = tester.getSize(button);
      expect(
        size.width,
        greaterThanOrEqualTo(44),
        reason: 'Touch target width must be ≥44 dp.',
      );
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'Touch target height must be ≥44 dp.',
      );
    });

    testWidgets('tapping the "Read aloud" button calls tts.speak with the '
        'grouped payload', (tester) async {
      final tts = _RecordingTts();
      await _pumpWidget(
        tester,
        tts: tts,
        data: '4844412344',
        cardName: 'Supermarket X',
      );

      await tester.tap(find.byTooltip('Read aloud'));
      // Pump once so the tap is processed, then once more for
      // the async gap before the future resolves.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        tts.spoken,
        isNotEmpty,
        reason:
            'Tapping the button must call tts.speak at least '
            'once.',
      );
      // The spoken text should include the grouped payload.
      // The exact phrasing is implementation detail; we assert
      // the digit groups and the card name both appear so a
      // user at the cashier can both identify the card and
      // read the number.
      final spoken = tts.spoken.join(' ');
      expect(spoken, contains('Supermarket X'));
      expect(spoken, contains('4844 4123 44'));
    });

    testWidgets('renders nothing visually when the payload is empty', (
      tester,
    ) async {
      final tts = _RecordingTts();
      await _pumpWidget(tester, tts: tts, data: '');

      // The whole widget should collapse to zero size; the
      // existing BarcodePreview already does this for its
      // inner widget, and the AnnounceableBarcode must follow
      // suit so an empty card does not show a phantom
      // "Read aloud" button.
      final size = tester.getSize(find.byType(AnnounceableBarcode));
      expect(size.width, 0, reason: 'Empty payload → zero-width widget.');
      expect(
        find.byTooltip('Read aloud'),
        findsNothing,
        reason: 'Empty payload → no read-aloud button.',
      );
    });

    testWidgets('keeps the 44 dp hit target at 200% text scale', (
      tester,
    ) async {
      final tts = _RecordingTts();
      await _pumpWidget(
        tester,
        tts: tts,
        data: '4844412344',
        cardName: 'Supermarket X',
        textScale: 2.0,
      );

      final button = find.byTooltip('Read aloud');
      expect(button, findsOneWidget);
      final size = tester.getSize(button);
      expect(
        size.width,
        greaterThanOrEqualTo(44),
        reason: '200% text scale must not shrink the hit target.',
      );
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: '200% text scale must not shrink the hit target.',
      );
    });
  });
}
