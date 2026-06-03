import 'dart:io';

import 'package:flutter/material.dart';

class CardImageViewerScreen extends StatefulWidget {
  const CardImageViewerScreen({
    super.key,
    required this.imagePath,
    required this.title,
  });

  final String imagePath;
  final String title;

  @override
  State<CardImageViewerScreen> createState() => _CardImageViewerScreenState();
}

class _CardImageViewerScreenState extends State<CardImageViewerScreen> {
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    final canReset = _quarterTurns != 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Rotate left',
            onPressed: () => _rotate(-1),
            icon: const Icon(Icons.rotate_90_degrees_ccw),
          ),
          IconButton(
            tooltip: 'Rotate right',
            onPressed: () => _rotate(1),
            icon: const Icon(Icons.rotate_90_degrees_cw),
          ),
          IconButton(
            tooltip: 'Reset rotation',
            onPressed: canReset ? _resetRotation : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: _quarterTurns,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'This image could not be loaded.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Pinch to zoom. Use the rotate buttons if the card was captured sideways.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rotate(int delta) {
    setState(() {
      _quarterTurns = (_quarterTurns + delta) % 4;
      if (_quarterTurns < 0) {
        _quarterTurns += 4;
      }
    });
  }

  void _resetRotation() {
    setState(() => _quarterTurns = 0);
  }
}
