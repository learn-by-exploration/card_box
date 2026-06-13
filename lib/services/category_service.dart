import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';

class CategoryService extends ChangeNotifier {
  CategoryService({required this._preferences});

  static const _customCategoriesKey = 'card_box.custom_categories.v1';

  final SharedPreferences _preferences;
  final List<String> _customCategories = <String>[];

  /// Hook called whenever a rename actually changes a category label.
  /// The repository installs this so cards whose `customCategory`
  /// string equals [fromLabel] can be rewritten in lockstep with
  /// the rename. The service must not depend on the repository
  /// directly, so the wiring is opt-in.
  Future<void> Function(String fromLabel, String toLabel)?
  _categoryMigrationHook;

  /// Installs (or clears) the migration hook. Pass `null` to remove
  /// the hook — useful in tests and on disposal.
  Future<void> setCategoryMigrationHook(
    Future<void> Function(String fromLabel, String toLabel)? hook,
  ) async {
    _categoryMigrationHook = hook;
  }

  List<String> get customCategories => List.unmodifiable(_customCategories);

  Future<void> init() async {
    final stored = _preferences.getStringList(_customCategoriesKey) ?? const [];
    _customCategories
      ..clear()
      ..addAll(_normalize(stored));
    notifyListeners();
  }

  Future<bool> addCategory(String label) async {
    final normalized = _normalizeLabel(label);
    if (normalized == null || _containsLabel(normalized)) {
      return false;
    }
    _customCategories.add(normalized);
    _customCategories.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> renameCategory({
    required String fromLabel,
    required String toLabel,
  }) async {
    final fromNormalized = _normalizeLabel(fromLabel);
    final toNormalized = _normalizeLabel(toLabel);
    if (fromNormalized == null || toNormalized == null) {
      return false;
    }
    final index = _customCategories.indexWhere(
      (existing) => existing.toLowerCase() == fromNormalized.toLowerCase(),
    );
    if (index == -1) {
      return false;
    }
    final currentLabel = _customCategories[index];
    if (currentLabel.toLowerCase() == toNormalized.toLowerCase()) {
      // No real change — the only thing that happened is whitespace
      // was normalized. Skip the migration hook: there is nothing
      // for cards to follow. The notification still fires so
      // listeners see the canonical form of the label.
      if (currentLabel == toNormalized) {
        return true;
      }
      _customCategories[index] = toNormalized;
      _customCategories.sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
      await _persist();
      notifyListeners();
      return true;
    }
    if (_containsLabel(toNormalized)) {
      return false;
    }
    _customCategories[index] = toNormalized;
    _customCategories.sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    await _persist();
    notifyListeners();
    // Fire the migration hook only after the rename is durable so
    // a hook crash cannot leave the label renamed without the
    // cards following. The hook is allowed to throw — that means
    // the cards were not migrated, which is preferable to a
    // half-applied state.
    final hook = _categoryMigrationHook;
    if (hook != null) {
      await hook(fromNormalized, toNormalized);
    }
    return true;
  }

  Future<bool> removeCategory(String label) async {
    final normalized = _normalizeLabel(label);
    if (normalized == null) {
      return false;
    }
    final hadMatch = _customCategories.any(
      (existing) => existing.toLowerCase() == normalized.toLowerCase(),
    );
    if (!hadMatch) {
      return false;
    }
    _customCategories.removeWhere(
      (existing) => existing.toLowerCase() == normalized.toLowerCase(),
    );
    await _persist();
    notifyListeners();
    return true;
  }

  bool containsCategory(String label) {
    final normalized = _normalizeLabel(label);
    if (normalized == null) {
      return false;
    }
    return _containsLabel(normalized);
  }

  bool _containsLabel(String label) {
    final normalized = label.toLowerCase();
    if (CardCategory.values.any(
      (category) => category.label.toLowerCase() == normalized,
    )) {
      return true;
    }
    return _customCategories.any(
      (existing) => existing.toLowerCase() == normalized,
    );
  }

  Future<void> _persist() async {
    await _preferences.setStringList(_customCategoriesKey, _customCategories);
  }

  List<String> _normalize(List<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final label = _normalizeLabel(value);
      if (label == null) {
        continue;
      }
      final key = label.toLowerCase();
      if (seen.contains(key) ||
          CardCategory.values.any(
            (category) => category.label.toLowerCase() == key,
          )) {
        continue;
      }
      seen.add(key);
      normalized.add(label);
    }
    normalized.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return normalized;
  }

  String? _normalizeLabel(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
