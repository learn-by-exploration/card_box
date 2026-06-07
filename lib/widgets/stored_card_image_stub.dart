import 'package:flutter/material.dart';
import 'package:card_box/theme.dart';

Widget buildStoredCardImage(
  BuildContext context, {
  required String path,
  required String emptyLabel,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  final tokens = CardBoxThemeTokens.of(context);
  return Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: tokens.borderSoft),
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      color: tokens.surfaceRaised,
    ),
    child: Text(
      path.trim().isEmpty ? emptyLabel : path,
      textAlign: TextAlign.center,
    ),
  );
}
