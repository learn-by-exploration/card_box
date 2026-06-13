// Tests for `ThemeService`. The service persists the
// user's theme mode and palette selection in
// SharedPreferences. The existing test_support helper
// `createReadyThemeService` is used in many places but
// its behavior is not pinned. This file pins down the
// unknown-value fallback, the no-op short-circuit, and
// the listener notification contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService.init', () {
    test('returns system mode when prefs is empty', () async {
      final service = ThemeService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(service.themeMode, ThemeMode.system);
      expect(service.palette, CardBoxThemePalette.softTeal);
    });

    test('falls back to system for an unknown theme mode', () async {
      // A future version may write a new mode string the
      // current app does not understand. The service must
      // not crash — it falls back to system.
      SharedPreferences.setMockInitialValues({
        'card_box.theme_mode.v1': 'ultra-dark',
      });
      final service = ThemeService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(service.themeMode, ThemeMode.system);
    });

    test('falls back to softTeal for an unknown palette key', () async {
      SharedPreferences.setMockInitialValues({
        'card_box.theme_palette.v1': 'neon-pink',
      });
      final service = ThemeService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(service.palette, CardBoxThemePalette.softTeal);
    });

    test('reads a previously-persisted mode and palette', () async {
      SharedPreferences.setMockInitialValues({
        'card_box.theme_mode.v1': 'dark',
        'card_box.theme_palette.v1': 'forest',
      });
      final service = ThemeService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(service.themeMode, ThemeMode.dark);
      expect(service.palette, CardBoxThemePalette.forest);
    });
  });

  group('ThemeService.updateThemeMode', () {
    test('persists the new mode and notifies listeners', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService(preferences: prefs);
      await service.init();
      var notifications = 0;
      service.addListener(() => notifications += 1);

      await service.updateThemeMode(ThemeMode.dark);

      expect(service.themeMode, ThemeMode.dark);
      expect(prefs.getString('card_box.theme_mode.v1'), 'dark');
      expect(notifications, 1);
    });

    test('is a no-op when the mode did not change', () async {
      // The service guards against redundant writes. A
      // call with the current mode must not bump the
      // counter or notify listeners.
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService(preferences: prefs);
      await service.init();
      var notifications = 0;
      service.addListener(() => notifications += 1);

      await service.updateThemeMode(ThemeMode.system);

      expect(notifications, 0);
      // No write happened — the prefs key is empty.
      expect(prefs.getString('card_box.theme_mode.v1'), isNull);
    });
  });

  group('ThemeService.updatePalette', () {
    test('persists the new palette and notifies listeners', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService(preferences: prefs);
      await service.init();
      var notifications = 0;
      service.addListener(() => notifications += 1);

      await service.updatePalette(CardBoxThemePalette.slate);

      expect(service.palette, CardBoxThemePalette.slate);
      expect(prefs.getString('card_box.theme_palette.v1'), 'slate');
      expect(notifications, 1);
    });

    test('is a no-op when the palette did not change', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ThemeService(preferences: prefs);
      await service.init();
      var notifications = 0;
      service.addListener(() => notifications += 1);

      await service.updatePalette(CardBoxThemePalette.softTeal);

      expect(notifications, 0);
      expect(prefs.getString('card_box.theme_palette.v1'), isNull);
    });
  });
}
