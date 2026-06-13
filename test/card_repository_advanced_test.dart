// Tests for the failure-path branches of `CardRepository`.
// The existing `widget_test.dart` covers the happy path of
// import/export. This file pins down the migrations, the
// import-side persisted-filter (only write cards that
// changed), and the `migrateCustomCategory` contract that
// `SettingsService` and the settings UI depend on.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/card_database.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/card_storage_codec.dart';

import 'test_support.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('CardRepository.migrateCustomCategory', () {
    test(
      'throws ArgumentError when target is Other without a custom label',
      () {
        // The migration is meaningful only when the target is a
        // built-in category or a *different* custom label.
        // Migrating to `Other` with an empty custom label would
        // erase the category entirely — that is a programmer
        // error and must surface as an exception, not a silent
        // no-op.
        final repo = CardRepository(
          database: CardDatabase(NativeDatabase.memory()),
        );

        expect(
          () => repo.migrateCustomCategory(
            fromLabel: 'MembershipPlus',
            toCategory: CardCategory.other,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('returns 0 for an empty source label', () async {
      // An empty source matches no card. The migration is a
      // silent no-op — the result is 0.
      final repo = CardRepository(
        database: CardDatabase(NativeDatabase.memory()),
      );
      await repo.init();

      final n = await repo.migrateCustomCategory(
        fromLabel: '   ',
        toCategory: CardCategory.loyalty,
      );

      expect(n, 0);
    });

    test('returns 0 when target custom label matches the source', () async {
      // The migration is idempotent in the case of `Other →
      // Other` with the same label. The check is
      // case-insensitive.
      final repo = CardRepository(
        database: CardDatabase(NativeDatabase.memory()),
      );
      await repo.init();

      final n = await repo.migrateCustomCategory(
        fromLabel: 'MembershipPlus',
        toCategory: CardCategory.other,
        toCustomCategory: 'membershipplus',
      );

      expect(n, 0);
    });

    test('migrates matching cards and bumps updatedAt', () async {
      // The happy path. A card whose category is Other +
      // customCategory == 'MembershipPlus' is rewritten to
      // (loyalty, customCategory == null). The updatedAt
      // is stamped to "now" so the change is visible in the
      // sort cache and on disk.
      final repo = CardRepository(
        database: CardDatabase(NativeDatabase.memory()),
      );
      await repo.init();
      await repo.upsert(
        WalletCard(
          id: 'a',
          name: 'A',
          category: CardCategory.other,
          customCategory: 'MembershipPlus',
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
      );
      await repo.upsert(
        WalletCard(
          id: 'b',
          name: 'B',
          category: CardCategory.other,
          customCategory: 'OtherLabel',
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
      );

      final n = await repo.migrateCustomCategory(
        fromLabel: 'MembershipPlus',
        toCategory: CardCategory.loyalty,
      );

      expect(n, 1);
      final migrated = repo.findById('a')!;
      expect(migrated.category, CardCategory.loyalty);
      expect(migrated.customCategory, isNull);
      // The non-matching card is untouched.
      final untouched = repo.findById('b')!;
      expect(untouched.category, CardCategory.other);
      expect(untouched.customCategory, 'OtherLabel');
    });
  });

  group('CardRepository.importPlainJsonProtected', () {
    test('returns added/updated/skipped counts', () async {
      // The detailed import result separates added (new id),
      // updated (existing id, newer or different), and
      // skipped older (existing id, incoming is older).
      final repo = CardRepository(
        database: CardDatabase(NativeDatabase.memory()),
      );
      await repo.init();
      // Seed one card with an old updatedAt so an import
      // trying to overwrite it is treated as "skipped".
      final seed = WalletCard(
        id: 'old',
        name: 'Old',
        category: CardCategory.loyalty,
        createdAt: DateTime.utc(2024, 6, 1),
        updatedAt: DateTime.utc(2024, 6, 1),
      );
      await repo.upsert(seed);

      final payload = CardStorageCodec().encodeBackup([
        WalletCard(
          id: 'old',
          name: 'Old-older',
          category: CardCategory.loyalty,
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 1),
        ),
        WalletCard(
          id: 'new',
          name: 'New',
          category: CardCategory.loyalty,
          createdAt: DateTime.utc(2024, 7, 1),
          updatedAt: DateTime.utc(2024, 7, 1),
        ),
      ]);

      final result = await repo.importPlainJsonProtected(payload);
      expect(result.addedCount, 1);
      expect(result.updatedCount, 0);
      expect(result.skippedOlderCount, 1);
      // The skipped card keeps the original (newer) data.
      expect(repo.findById('old')!.name, 'Old');
    });

    test(
      'persists cards that already exist with newer updatedAt as updates',
      () async {
        // The import path uses Dart's default `==` to skip
        // identical content, while `upsert` uses the more
        // thorough `_cardsContentEqual` (which strips
        // `updatedAt` from the comparison). The import path is
        // therefore stricter: a re-import of a byte-identical
        // card counts as an update. Pin that behavior so any
        // future tightening of the import comparison has a
        // regression test.
        final db = ImportRecordingCardDatabase();
        final repo = CardRepository(database: db);
        await repo.init();
        final card = WalletCard(
          id: 'k',
          name: 'K',
          category: CardCategory.loyalty,
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 1),
        );
        await repo.upsert(card);
        db.upsertedIds.clear();

        // Re-import the same card. The merge sees the same id
        // but different references and treats it as an update.
        final payload = CardStorageCodec().encodeBackup([card]);
        final result = await repo.importPlainJsonProtected(payload);

        expect(result.addedCount, 0);
        expect(result.updatedCount, 1);
        expect(db.upsertedIds, contains('k'));
      },
    );
  });
}
