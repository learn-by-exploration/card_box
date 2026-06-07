import 'dart:io';

import 'package:flutter/material.dart';
import 'package:card_box/theme.dart';

Widget buildStoredCardImage(
  BuildContext context, {
  required String path,
  required String emptyLabel,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  if (path.trim().isEmpty) {
    return _EmptyImage(label: emptyLabel, height: height);
  }
  final file = File(path);
  return ClipRRect(
    borderRadius: BorderRadius.circular(
      CardBoxThemeTokens.of(context).radiusSmall,
    ),
    child: Image.file(
      file,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _EmptyImage(label: emptyLabel, height: height),
    ),
  );
}

class _EmptyImage extends StatelessWidget {
  const _EmptyImage({required this.label, this.height});

  final String label;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: tokens.borderSoft),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        color: tokens.surfaceRaised,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
