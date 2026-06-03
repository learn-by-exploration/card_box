import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:card_box/models/scanned_code.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 650,
    autoZoom: true,
  );
  bool _scannerEnabled = false;
  bool _didReturnResult = false;
  String? _candidatePayload;
  String? _candidateFormat;
  String? _lastSeenPayload;
  int _stableHits = 0;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode or QR'),
        actions: [
          if (_scannerEnabled)
            IconButton(
              tooltip: _torchEnabled ? 'Turn torch off' : 'Turn torch on',
              onPressed: () async {
                await _controller.toggleTorch();
                if (!mounted) {
                  return;
                }
                setState(() => _torchEnabled = !_torchEnabled);
              },
              icon: Icon(
                _torchEnabled ? Icons.flashlight_off : Icons.flashlight_on,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: !_scannerEnabled
              ? _ConsentPanel(
                  onStart: () => setState(() => _scannerEnabled = true),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final scanWindow = Rect.fromCenter(
                      center: Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight / 2 - 20,
                      ),
                      width: constraints.maxWidth * 0.72,
                      height: constraints.maxHeight * 0.34,
                    );
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            controller: _controller,
                            scanWindow: scanWindow,
                            onDetect: _handleDetection,
                          ),
                        ),
                        _ScannerOverlay(scanWindow: scanWindow),
                        Positioned(
                          left: 24,
                          right: 24,
                          top: 24,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Hold the code steady inside the frame. Card Box will wait for a stable read before suggesting it.',
                                style: TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        if (_candidatePayload != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: _CandidatePanel(
                              payload: _candidatePayload!,
                              format: _candidateFormat ?? 'Unknown format',
                              onUse: _confirmCandidate,
                              onKeepScanning: _resetCandidate,
                            ),
                          )
                        else
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  _stableHits == 0
                                      ? 'Waiting for a code inside the frame.'
                                      : 'Steady read in progress... $_stableHits/2 matches',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_didReturnResult || _candidatePayload != null) {
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

    if (_lastSeenPayload == rawValue) {
      _stableHits += 1;
    } else {
      _lastSeenPayload = rawValue;
      _stableHits = 1;
    }

    if (_stableHits < 2) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    setState(() {
      _candidatePayload = rawValue;
      _candidateFormat = barcode.format.name;
      _stableHits = 0;
      _lastSeenPayload = null;
    });
    _controller.stop();
  }

  void _confirmCandidate() {
    if (_didReturnResult || _candidatePayload == null) {
      return;
    }
    _didReturnResult = true;
    Navigator.of(context).pop(
      ScannedCode(
        payload: _candidatePayload!,
        format: _candidateFormat ?? 'unknown',
      ),
    );
  }

  Future<void> _resetCandidate() async {
    setState(() {
      _candidatePayload = null;
      _candidateFormat = null;
      _lastSeenPayload = null;
      _stableHits = 0;
    });
    await _controller.start();
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

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({
    required this.payload,
    required this.format,
    required this.onUse,
    required this.onKeepScanning,
  });

  final String payload;
  final String format;
  final VoidCallback onUse;
  final VoidCallback onKeepScanning;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stable read found',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(payload, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(format, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onKeepScanning,
                    child: const Text('Keep scanning'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onUse,
                    child: const Text('Use this code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.scanWindow});

  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScannerOverlayPainter(scanWindow: scanWindow),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.scanWindow});

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.46);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final overlayPath = Path()..addRect(Offset.zero & size);
    final cutout = RRect.fromRectAndRadius(
      scanWindow,
      const Radius.circular(18),
    );
    final cutoutPath = Path()..addRRect(cutout);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(overlayPath, overlayPaint);
    canvas.drawPath(cutoutPath, clearPaint);
    canvas.restore();

    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(cutout, framePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}
