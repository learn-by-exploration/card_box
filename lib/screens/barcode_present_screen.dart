import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/barcode_preview.dart';

class BarcodePresentScreen extends StatelessWidget {
  const BarcodePresentScreen({super.key, required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
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
                    child: BarcodePreview(
                      data: card.barcodePayload,
                      format: card.barcodeFormat,
                      height: 220,
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
