import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/theme.dart';

class ThemeService extends ChangeNotifier {
  ThemeService({required this._preferences});

  static const themeModeKey = 'card_box.theme_mode.v1';
  static const themePaletteKey = 'card_box.theme_palette.v1';

  final SharedPreferences _preferences;

  ThemeMode _themeMode = ThemeMode.system;
  CardBoxThemePalette _palette = CardBoxThemePalette.softTeal;

  ThemeMode get themeMode => _themeMode;
  CardBoxThemePalette get palette => _palette;

  Future<void> init() async {
    final stored = _preferences.getString(themeModeKey);
    _themeMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final storedPalette = _preferences.getString(themePaletteKey);
    _palette = CardBoxThemePalette.values.firstWhere(
      (palette) => palette.storageKey == storedPalette,
      orElse: () => CardBoxThemePalette.softTeal,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    await _preferences.setString(themeModeKey, _encode(mode));
    notifyListeners();
  }

  Future<void> updatePalette(CardBoxThemePalette palette) async {
    if (_palette == palette) {
      return;
    }
    _palette = palette;
    await _preferences.setString(themePaletteKey, palette.storageKey);
    notifyListeners();
  }

  String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
