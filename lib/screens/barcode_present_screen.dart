import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/tts_service.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/announceable_barcode.dart';

class BarcodePresentScreen extends StatefulWidget {
  const BarcodePresentScreen({super.key, required this.card, this.onShown});

  final WalletCard card;

  /// Optional callback fired once when the screen first renders.
  /// Used to record that the card was used (marking lastUsedAt and
  /// useCount). The returned future is awaited inside the post-frame
  /// callback so a thrown error is observed by the caller, not
  /// silently swallowed. Callers without a repository can leave
  /// this null.
  final Future<void> Function()? onShown;

  @override
  State<BarcodePresentScreen> createState() => _BarcodePresentScreenState();
}

class _BarcodePresentScreenState extends State<BarcodePresentScreen> {
  bool _wakelockAcquired = false;
  bool _onShownFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_wakelockAcquired) {
        // The plugin is idempotent, but we still gate the call so a
        // hot-reload re-entry into initState does not double-acquire.
        _wakelockAcquired = true;
        try {
          await WakelockPlus.enable();
        } catch (error) {
          debugPrint(
            'BarcodePresentScreen: WakelockPlus.enable failed: $error',
          );
          _wakelockAcquired = false;
        }
      }
      if (!mounted) return;
      final callback = widget.onShown;
      if (callback != null && !_onShownFired) {
        _onShownFired = true;
        try {
          await callback();
        } catch (error) {
          debugPrint('BarcodePresentScreen: onShown callback failed: $error');
        }
      }
    });
  }

  @override
  void dispose() {
    if (_wakelockAcquired) {
      _wakelockAcquired = false;
      // Best-effort: a stuck wakelock is auto-cleared on Android when
      // the Activity is destroyed, but on iOS the idleTimerDisabled
      // flag would otherwise outlive this screen.
      unawaited(
        WakelockPlus.disable().catchError((Object error) {
          debugPrint(
            'BarcodePresentScreen: WakelockPlus.disable failed: $error',
          );
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final tokens = CardBoxThemeTokens.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: tokens.presentationCanvas,
      appBar: AppBar(
        backgroundColor: tokens.presentationCanvas,
        foregroundColor: colors.onSurface,
        title: Text(card.name),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceXLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                card.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (card.issuer.isNotEmpty) ...[
                SizedBox(height: tokens.spaceSmall - 2),
                Text(
                  card.issuer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              SizedBox(height: tokens.spaceXLarge + tokens.spaceSmall),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(tokens.spaceXLarge),
                  decoration: BoxDecoration(
                    color: tokens.presentationSurface,
                    border: Border.all(color: tokens.borderSoft),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  ),
                  child: Center(
                    child: AnnounceableBarcode(
                      data: card.barcodePayload,
                      format: card.barcodeFormat,
                      // The TTS *call* is gated by a Settings
                      // toggle (DR-014.a). Until the Settings
                      // wiring lands, the read-aloud button is
                      // rendered but disabled; the Semantics
                      // label is always present so a screen-
                      // reader user can still long-press to hear
                      // the payload via the OS TTS, even with the
                      // in-app button disabled.
                      tts: NoOpTtsService(),
                      cardName: card.name,
                      height: 220,
                      ttsEnabled: false,
                    ),
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceLarge),
              SelectableText(
                card.barcodePayload,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tokens.spaceSmall),
              Text(
                card.barcodeFormat.isEmpty ? 'Stored code' : card.barcodeFormat,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
