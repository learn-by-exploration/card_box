import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/widgets/barcode_preview.dart';

class BarcodePresentScreen extends StatelessWidget {
  const BarcodePresentScreen({super.key, required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(card.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 6),
                Text(
                  card.issuer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const SizedBox(height: 28),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD8DEDC)),
                    borderRadius: BorderRadius.circular(8),
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
              const SizedBox(height: 16),
              SelectableText(
                card.barcodePayload,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
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
