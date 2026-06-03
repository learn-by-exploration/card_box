import 'dart:io';

import 'package:flutter/material.dart';

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
    borderRadius: BorderRadius.circular(8),
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
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD8DEDC)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
