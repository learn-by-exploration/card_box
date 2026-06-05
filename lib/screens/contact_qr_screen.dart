import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/vcard_export_service.dart';
import 'package:card_box/widgets/barcode_preview.dart';

class ContactQrScreen extends StatelessWidget {
  const ContactQrScreen({super.key, required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    final payload = const VCardExportService().buildQrPayload(card);
    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Scan to save contact',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                card.issuer.isEmpty ? card.categoryLabel : card.issuer,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD8DEDC)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: BarcodePreview(
                        data: payload,
                        format: 'QRCode',
                        height: 320,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This QR contains a compact contact card so another phone can save the details quickly.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
