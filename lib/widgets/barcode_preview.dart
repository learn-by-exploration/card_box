import 'package:barcode/barcode.dart' as barcode_package;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:card_box/theme.dart';

class BarcodePreview extends StatelessWidget {
  const BarcodePreview({
    super.key,
    required this.data,
    required this.format,
    this.height = 120,
  });

  final String data;
  final String format;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final tokens = CardBoxThemeTokens.of(context);
    final barcode = _barcodeForFormat(format);
    return BarcodeWidget(
      data: data,
      barcode: barcode,
      drawText: true,
      errorBuilder: (_, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Unable to render this code yet.\n$data',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      backgroundColor: tokens.presentationSurface,
      height: height,
    );
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
