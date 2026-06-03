import 'package:flutter/material.dart';

Widget buildStoredCardImage(
  BuildContext context, {
  required String path,
  required String emptyLabel,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFD8DEDC)),
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
    ),
    child: Text(
      path.trim().isEmpty ? emptyLabel : path,
      textAlign: TextAlign.center,
    ),
  );
}
