import 'dart:io';

import 'package:flutter/material.dart';
import 'package:card_box/theme.dart';

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
    final tokens = CardBoxThemeTokens.of(context);
    final theme = Theme.of(context);
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
                      errorBuilder: (_, _, _) => Padding(
                        padding: EdgeInsets.all(tokens.spaceXLarge + 4),
                        child: Text(
                          'This image could not be loaded.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLarge,
                0,
                tokens.spaceLarge,
                tokens.spaceLarge,
              ),
              child: Text(
                'Pinch to zoom. Use the rotate buttons if the card was captured sideways.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
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
