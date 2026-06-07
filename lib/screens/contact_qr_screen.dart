import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/vcard_export_service.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/barcode_preview.dart';

class ContactQrScreen extends StatelessWidget {
  const ContactQrScreen({super.key, required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    final payload = const VCardExportService().buildQrPayload(card);
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceXLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Scan to save contact',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: tokens.spaceSmall),
              Text(
                card.issuer.isEmpty ? card.categoryLabel : card.issuer,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceXLarge + 4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.presentationSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(color: tokens.borderSoft),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spaceXLarge),
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
              SizedBox(height: tokens.spaceLarge),
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
