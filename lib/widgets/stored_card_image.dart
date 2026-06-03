import 'package:flutter/material.dart';

import 'package:card_box/widgets/stored_card_image_impl.dart';

class StoredCardImage extends StatelessWidget {
  const StoredCardImage({
    super.key,
    required this.path,
    required this.emptyLabel,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String path;
  final String emptyLabel;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return buildStoredCardImage(
      context,
      path: path,
      emptyLabel: emptyLabel,
      height: height,
      fit: fit,
    );
  }
}
