import 'package:flutter/material.dart';

final cardBoxTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF196C6B),
    primary: const Color(0xFF196C6B),
    secondary: const Color(0xFFB65F2A),
    tertiary: const Color(0xFF415F91),
  ),
  scaffoldBackgroundColor: const Color(0xFFF8FAF9),
  useMaterial3: true,
  appBarTheme: const AppBarTheme(centerTitle: false),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD8DEDC)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD8DEDC)),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    side: const BorderSide(color: Color(0xFFD8DEDC)),
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      side: BorderSide(color: Color(0xFFE1E7E5)),
    ),
  ),
);
