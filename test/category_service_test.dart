// Tests for the singleton `CategoryService`.
// The service holds the user's custom category labels in
// SharedPreferences, deduplicates them, fires a migration
// hook on rename, and rejects labels that collide with
// built-in `CardCategory` values. The existing
// `models_and_service_unit_test.dart` covers add/remove;
// this file pins the rename hook contract, the
// case-insensitive built-in collision, and the
// normalize-on-load behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/services/category_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('CategoryService.init', () {
    test(
      'loads from SharedPreferences and deduplicates case-insensitively',
      () async {
        // Pre-seed prefs with two labels that differ only in
        // case. The normalize step must collapse them to one.
        SharedPreferences.setMockInitialValues({
          'card_box.custom_categories.v1': <String>[
            'MembershipPlus',
            'membershipplus',
          ],
        });
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();

        expect(service.customCategories, hasLength(1));
      },
    );

    test(
      'drops labels that collide with built-in CardCategory values',
      () async {
        // 'Loyalty' is a built-in label. The service must NOT
        // surface it as a custom category — the add/contains
        // path treats built-ins as already taken.
        SharedPreferences.setMockInitialValues({
          'card_box.custom_categories.v1': <String>[
            'Loyalty',
            'MembershipPlus',
          ],
        });
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();

        expect(service.customCategories, ['MembershipPlus']);
      },
    );

    test('drops blank labels during normalize', () async {
      SharedPreferences.setMockInitialValues({
        'card_box.custom_categories.v1': <String>['', '  ', 'Valid'],
      });
      final service = CategoryService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();

      expect(service.customCategories, ['Valid']);
    });
  });

  group('CategoryService.addCategory', () {
    test(
      'rejects a label that collides with a built-in CardCategory',
      () async {
        // 'Gift' is built-in. Adding 'Gift' must fail and must
        // not touch persistence.
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();

        final added = await service.addCategory('Gift');
        expect(added, isFalse);
        expect(service.customCategories, isEmpty);
      },
    );

    test(
      'rejects a duplicate (case-insensitive) of an existing custom label',
      () async {
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();
        expect(await service.addCategory('Premium'), isTrue);
        expect(await service.addCategory('premium'), isFalse);
        expect(service.customCategories, ['Premium']);
      },
    );

    test('trims and collapses internal whitespace before storing', () async {
      final service = CategoryService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(await service.addCategory('  Multi  Space  '), isTrue);
      expect(service.customCategories, ['Multi Space']);
    });
  });

  group('CategoryService.renameCategory', () {
    test(
      'fires the migration hook with the normalized from/to labels',
      () async {
        // The hook is what rewrites cards whose customCategory
        // matched the old label. The service must call the hook
        // AFTER the rename is persisted, never before, so a
        // hook crash cannot leave the rename in flight without
        // cards following. The hook receives the *normalized*
        // inputs (trimmed + whitespace-collapsed), not the
        // canonical stored form — the case-insensitive lookup
        // is what matched them, but the migration needs the
        // exact strings the caller passed.
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();
        await service.addCategory('OldName');

        String? hookFrom;
        String? hookTo;
        var hookCalled = false;
        await service.setCategoryMigrationHook((from, to) async {
          hookCalled = true;
          hookFrom = from;
          hookTo = to;
        });

        final ok = await service.renameCategory(
          fromLabel: 'oldname',
          toLabel: '  NewName  ',
        );
        expect(ok, isTrue);
        expect(hookCalled, isTrue);
        expect(hookFrom, 'oldname');
        expect(hookTo, 'NewName');
      },
    );

    test(
      'does not fire the hook for a no-op rename (whitespace only)',
      () async {
        // Renaming "Premium" → "Premium" is a no-op. The
        // hook must NOT fire (no cards to migrate). The
        // service still returns true so callers can show
        // "renamed" feedback.
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();
        await service.addCategory('Premium');

        var hookCalls = 0;
        await service.setCategoryMigrationHook((_, _) async {
          hookCalls += 1;
        });

        final ok = await service.renameCategory(
          fromLabel: 'Premium',
          toLabel: '  Premium  ',
        );
        expect(ok, isTrue);
        expect(hookCalls, 0);
        // The label is still normalized (whitespace collapsed).
        expect(service.customCategories, ['Premium']);
      },
    );

    test(
      'returns false when the target label collides with a built-in',
      () async {
        // The new label would shadow 'Library'. Reject.
        final service = CategoryService(
          preferences: await SharedPreferences.getInstance(),
        );
        await service.init();
        await service.addCategory('RareBooks');

        final ok = await service.renameCategory(
          fromLabel: 'RareBooks',
          toLabel: 'Library',
        );
        expect(ok, isFalse);
        // The original label is preserved.
        expect(service.customCategories, ['RareBooks']);
      },
    );
  });

  group('CategoryService.containsCategory', () {
    test('returns true for built-in labels', () async {
      final service = CategoryService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(service.containsCategory('Loyalty'), isTrue);
      expect(service.containsCategory('  loyalty  '), isTrue);
    });

    test('returns false for empty / whitespace-only labels', () async {
      final service = CategoryService(
        preferences: await SharedPreferences.getInstance(),
      );
      await service.init();
      expect(service.containsCategory(''), isFalse);
      expect(service.containsCategory('   '), isFalse);
    });
  });
}
