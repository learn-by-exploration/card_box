import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:card_box/models/scanned_code.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scannerEnabled = false;
  bool _didReturnResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode or QR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: !_scannerEnabled
              ? _ConsentPanel(
                  onStart: () => setState(() => _scannerEnabled = true),
                )
              : Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          if (_didReturnResult) {
                            return;
                          }
                          final barcode = capture.barcodes.firstWhere(
                            (item) => (item.rawValue ?? '').trim().isNotEmpty,
                            orElse: () => capture.barcodes.first,
                          );
                          final rawValue = barcode.rawValue?.trim();
                          if (rawValue == null || rawValue.isEmpty) {
                            return;
                          }
                          _didReturnResult = true;
                          Navigator.of(context).pop(
                            ScannedCode(
                              payload: rawValue,
                              format: barcode.format.name,
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      top: 24,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Align the visible code inside the camera view.',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ConsentPanel extends StatelessWidget {
  const _ConsentPanel({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Camera permission',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Card Box uses the camera only after you choose to scan a visible barcode or QR code.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Start scanner'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
