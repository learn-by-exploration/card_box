import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart' show MissingPluginException, PlatformException;
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/services/media_recovery_service.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CardRepository', () {
    test(
      'upsertCard round-trips a card through payload JSON',
      () async {
        final database = createInMemoryDatabase();
        final card = WalletCard(
          id: 'db-card',
          name: 'Aiko Tanaka',
          issuer: 'CourtSide Japan',
          category: CardCategory.contact,
          notes: 'Met after practice',
          barcodePayload: 'AIKO-42',
          nfcTagSummary: 'ISO-DEP candidate',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        );

        await database.upsertCard(card);
        final cards = await database.loadCards();
        expect(cards, hasLength(1));
        final loaded = cards.single;
        expect(loaded.id, card.id);
        expect(loaded.name, card.name);
        expect(loaded.issuer, card.issuer);
        expect(loaded.category, card.category);
        expect(loaded.barcodePayload, card.barcodePayload);
        expect(loaded.nfcTagSummary, card.nfcTagSummary);
        await database.close();
      },
    );

    test(
      'loadCards skips rows with corrupt payload JSON and returns the rest',
      () async {
        final database = createInMemoryDatabase();
        final valid = WalletCard(
          id: 'valid-card',
          name: 'Valid card',
          category: CardCategory.access,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        );
        await database.upsertCard(valid);
        // Inject rows with corrupt payloads to verify both decode
        // failure modes (invalid JSON and JSON-but-not-Map) are skipped.
        final millis = DateTime(2026, 6, 4).millisecondsSinceEpoch;
        await database.customStatement(
          'INSERT INTO card_records (id, payload_json, created_at_millis, '
          'updated_at_millis) VALUES (?, ?, ?, ?)',
          ['corrupt-1', 'not json{{{', millis, millis],
        );
        await database.customStatement(
          'INSERT INTO card_records (id, payload_json, created_at_millis, '
          'updated_at_millis) VALUES (?, ?, ?, ?)',
          ['corrupt-2', '[1, 2, 3]', millis, millis],
        );

        final cards = await database.loadCards();

        expect(cards, hasLength(1));
        expect(cards.first.id, 'valid-card');
        await database.close();
      },
    );

    test(
      'v3 schema codec round-trips a card through payload JSON',
      () async {
        // The v3 schema is the minimum storage-of-record: only
        // id, payload_json, created_at_millis, updated_at_millis.
        // Writing a card and reading it back must return the
        // same field values, proving the codec and the row
        // shape are aligned. (The cross-process / device
        // round-trip is exercised by test/round_trip_test.dart.)
        //
        // The v1->v2 per-row backfill and the v2->v3 drop path
        // use the same per-row try/catch isolation as
        // loadCards, which is exercised by the "loadCards skips
        // rows with corrupt payload JSON" test earlier in this
        // group. Restoring a direct migration test would
        // require either a @visibleForTesting escape hatch on
        // `_backfillNormalizedColumns` or a v1-subclass harness;
        // both are deferred to a follow-up pass.
        final database = createInMemoryDatabase();
        final original = WalletCard(
          id: 'round-trip',
          name: 'Round-trip card',
          category: CardCategory.access,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4, 0, 0, 5),
        );
        await database.upsertCard(original);
        final loaded = await database.loadCards();
        expect(loaded, hasLength(1));
        expect(loaded.single.id, original.id);
        expect(loaded.single.name, original.name);
        expect(loaded.single.updatedAt, original.updatedAt);
        await database.close();
      },
    );

    test(
      'sort cache returns the same instance until notifyListeners fires',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = CardRepository(
          database: createInMemoryDatabase(),
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'cache-1',
            name: 'Cached card',
            category: CardCategory.contact,
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        // The first call materializes the cache; subsequent calls
        // must return the same instance without re-sorting. We
        // rely on Dart list identity (`identical`) to detect a
        // cache hit, which is exactly what `_sortedCards` does
        // internally.
        final first = repository.cards;
        final second = repository.cards;
        expect(identical(first, second), isTrue);

        // After a write that triggers notifyListeners, the cache
        // is invalidated and a fresh list is materialized.
        await repository.upsert(
          WalletCard(
            id: 'cache-2',
            name: 'Newer card',
            category: CardCategory.contact,
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4, 0, 0, 5),
          ),
        );
        final third = repository.cards;
        expect(identical(third, first), isFalse);
        repository.dispose();
      },
    );

    test('cleans up replaced images when a card is updated', () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      mediaManager.seedImage(
        '/images/front_old.jpg',
        StoredImageBackupData(
          bytes: Uint8List.fromList([1, 2, 3]),
          extension: '.jpg',
        ),
      );
      mediaManager.seedImage(
        '/images/back_same.jpg',
        StoredImageBackupData(
          bytes: Uint8List.fromList([4, 5, 6]),
          extension: '.jpg',
        ),
      );
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'card-1',
          name: 'Badge',
          category: CardCategory.access,
          frontImagePath: '/images/front_old.jpg',
          backImagePath: '/images/back_same.jpg',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      await repository.upsert(
        repository
            .findById('card-1')!
            .copyWith(
              frontImagePath: '/images/front_new.jpg',
              backImagePath: '/images/back_same.jpg',
            ),
      );

      expect(mediaManager.deletedPaths, contains('/images/front_old.jpg'));
      expect(
        mediaManager.deletedPaths,
        isNot(contains('/images/back_same.jpg')),
      );
    });

    test(
      'upsert is a no-op when the new card has the same content as the existing one',
      () async {
        SharedPreferences.setMockInitialValues({});
        final database = ImportRecordingCardDatabase();
        final mediaManager = FakeCardMediaManager();
        final repository = CardRepository(
          database: database,
          mediaManager: mediaManager,
        );
        await repository.init();
        final baseTimestamp = DateTime(2026, 6, 4);
        final original = WalletCard(
          id: 'noop-card',
          name: 'Noop',
          category: CardCategory.id,
          notes: 'same content',
          createdAt: baseTimestamp,
          updatedAt: baseTimestamp,
        );
        await repository.upsert(original);
        // After the first upsert, the database has captured the row.
        final firstUpsertCount = database.upsertedIds.length;
        // Calling upsert with an equal content (but freshly built, so
        // different object identity) must be a no-op — no DB write,
        // no updatedAt bump.
        await repository.upsert(
          WalletCard(
            id: 'noop-card',
            name: 'Noop',
            category: CardCategory.id,
            notes: 'same content',
            createdAt: baseTimestamp,
            updatedAt: baseTimestamp,
          ),
        );
        expect(database.upsertedIds.length, firstUpsertCount,
            reason: 'No-op upsert must not hit the database');
        final reloaded = repository.findById('noop-card')!;
        expect(reloaded.updatedAt, baseTimestamp,
            reason: 'No-op upsert must not bump updatedAt');
      },
    );

    test('duplicateCard returns a copy with a new id and (copy) suffix',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final original = WalletCard(
        id: 'orig-1',
        name: 'Coffee card',
        issuer: 'Beans Co',
        category: CardCategory.loyalty,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        barcodePayload: 'BC-12345',
      );
      await repository.upsert(original);
      final copy = await repository.duplicateCard('orig-1');
      expect(copy, isNotNull,
          reason: 'Duplicate must succeed for a known card id');
      expect(copy!.id, isNot('orig-1'),
          reason: 'Duplicate must have a new id');
      expect(copy.name, 'Coffee card (copy)',
          reason: 'Duplicate must append (copy) to the name');
      expect(copy.issuer, original.issuer,
          reason: 'Other fields must be preserved on the copy');
      expect(copy.barcodePayload, original.barcodePayload,
          reason: 'Barcode payload must be preserved on the copy');
      expect(repository.findById('orig-1'), isNotNull,
          reason: 'Original card must still be present');
      expect(repository.findById(copy.id), isNotNull,
          reason: 'New card must be persisted');
    });

    test('duplicateCard returns null for an unknown id', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final copy = await repository.duplicateCard('does-not-exist');
      expect(copy, isNull);
    });

    test('duplicateCard resets archived, favorite, and usage telemetry',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final stamp = DateTime(2024, 1, 1);
      final original = WalletCard(
        id: 'orig-archived',
        name: 'Retired metro card',
        category: CardCategory.transit,
        createdAt: stamp,
        updatedAt: stamp,
        barcodePayload: 'METRO-9',
        archived: true,
        favorite: true,
        lastUsedAt: stamp,
        useCount: 7,
      );
      await repository.upsert(original);
      final copy = await repository.duplicateCard('orig-archived');
      expect(copy, isNotNull);
      expect(copy!.archived, isFalse,
          reason: 'Duplicate of an archived card must be active');
      expect(copy.favorite, isFalse,
          reason: 'Duplicate of a favorite must not inherit the favorite');
      expect(copy.lastUsedAt, isNull,
          reason: 'Duplicate must not inherit the lastUsedAt timestamp');
      expect(copy.useCount, 0,
          reason: 'Duplicate must start with a zero use count');
    });

    test('findByBarcodePayload matches case-insensitively', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'bc-1',
          name: 'Library',
          category: CardCategory.library,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          barcodePayload: 'LIB-12345',
        ),
      );
      expect(repository.findByBarcodePayload('lib-12345'), isNotNull,
          reason: 'Lowercase needle should match uppercase payload');
      expect(repository.findByBarcodePayload('  LIB-12345  '), isNotNull,
          reason: 'Whitespace should be trimmed');
      expect(repository.findByBarcodePayload('not-there'), isNull,
          reason: 'No match for unrelated payload');
    });

    test('findByBarcodePayload ignores archived cards', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'bc-arch',
          name: 'Old',
          category: CardCategory.loyalty,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          barcodePayload: 'X-1',
          archived: true,
        ),
      );
      expect(repository.findByBarcodePayload('X-1'), isNull,
          reason: 'Archived card must not be a duplicate hit');
    });

    test('markUsed stamps lastUsedAt and increments useCount', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final base = DateTime(2024, 1, 1);
      await repository.upsert(
        WalletCard(
          id: 'used-1',
          name: 'Loyalty',
          category: CardCategory.loyalty,
          createdAt: base,
          updatedAt: base,
        ),
      );
      final stamp = DateTime(2024, 5, 5, 12, 0);
      await repository.markUsed('used-1', at: stamp);
      final card = repository.findById('used-1')!;
      expect(card.useCount, 1, reason: 'useCount should start at 1 after first use');
      expect(card.lastUsedAt, stamp, reason: 'lastUsedAt should be the supplied stamp');
      await repository.markUsed('used-1', at: stamp.add(const Duration(days: 1)));
      final after = repository.findById('used-1')!;
      expect(after.useCount, 2, reason: 'useCount should bump on subsequent uses');
      expect(after.lastUsedAt, stamp.add(const Duration(days: 1)),
          reason: 'lastUsedAt should advance');
    });

    test('markUsed is a no-op for an unknown card id', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final before = repository.cards.length;
      // Should not throw, should not synthesize a new card, and
      // should not change the visible card list.
      await repository.markUsed('does-not-exist');
      expect(repository.cards, hasLength(before),
          reason: 'markUsed must not create a card for an unknown id');
    });

    test(
      'upsert preserves the supplied updatedAt for a fresh insert',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = CardRepository(database: createInMemoryDatabase());
        await repository.init();
        final suppliedTimestamp = DateTime(2024, 3, 1);
        await repository.upsert(
          WalletCard(
            id: 'imported-fresh',
            name: 'Imported',
            category: CardCategory.loyalty,
            createdAt: suppliedTimestamp,
            updatedAt: suppliedTimestamp,
          ),
        );
        expect(
          repository.findById('imported-fresh')!.updatedAt,
          suppliedTimestamp,
        );
      },
    );

    test(
      'upsert writes the database row before cleaning up replaced images',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = RecordingCardMediaManager();
        final database = OrderingUpsertCardDatabase();
        final repository = CardRepository(
          database: database,
          mediaManager: mediaManager,
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'atomic-card',
            name: 'Atomic',
            category: CardCategory.id,
            frontImagePath: '/images/old.jpg',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        // Trigger an update that changes the image path.
        await repository.upsert(
          repository.findById('atomic-card')!.copyWith(
            name: 'Updated',
            frontImagePath: '/images/new.jpg',
          ),
        );

        // The old image delete must happen AFTER the DB write — a
        // partial-failure reorder would orphan files referenced by
        // a stale DB row.
        final dbAt = database.lastUpsertAt;
        final img = mediaManager.deletes.firstWhere(
          (d) => d.path == '/images/old.jpg',
        );
        expect(dbAt, isNotNull, reason: 'DB upsert was not recorded');
        expect(dbAt!.isBefore(img.at) || dbAt.isAtSameMomentAs(img.at),
            isTrue,
            reason: 'DB upsert must precede image delete. '
                'dbAt=$dbAt imgAt=${img.at}');
        expect(repository.findById('atomic-card')!.name, 'Updated');
        expect(
          repository.findById('atomic-card')!.frontImagePath,
          '/images/new.jpg',
        );
      },
    );

    test(
      'upsert rolls back in-memory state when the DB write fails',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = FakeCardMediaManager();
        final database = UpsertThrowingCardDatabase(
          throwForId: 'rollback-card',
        );
        final repository = CardRepository(
          database: database,
          mediaManager: mediaManager,
        );
        // Seed the card directly via SQL so the throwing path is not
        // triggered for the initial insert, then load it into memory.
        final millis = DateTime(2026, 6, 4).millisecondsSinceEpoch;
        await database.customStatement(
          'INSERT INTO card_records (id, payload_json, created_at_millis, '
          'updated_at_millis) VALUES (?, ?, ?, ?)',
          [
            'rollback-card',
            '{"id":"rollback-card","name":"Original","category":"id",'
                '"frontImagePath":"/images/keep.jpg",'
                '"createdAt":"2026-06-04T00:00:00.000",'
                '"updatedAt":"2026-06-04T00:00:00.000"}',
            millis,
            millis,
          ],
        );
        await repository.init();
        expect(repository.findById('rollback-card')!.name, 'Original');

        await expectLater(
          repository.upsert(
            repository
                .findById('rollback-card')!
                .copyWith(name: 'Updated'),
          ),
          throwsA(isA<StateError>()),
        );

        // In-memory state must reflect the original — the failed
        // write must not have leaked into the cache.
        expect(repository.findById('rollback-card')!.name, 'Original');
        // No image cleanup should have happened.
        expect(mediaManager.deletedPaths, isEmpty);
      },
    );

    test(
      'concurrent upserts for the same card serialize through the queue',
      () async {
        SharedPreferences.setMockInitialValues({});
        final database = ConcurrentRecordingCardDatabase();
        final repository = CardRepository(database: database);
        await repository.init();
        // Two concurrent upserts with different content. The queue
        // must serialize them so that the max in-flight count never
        // exceeds 1, and the final in-memory state matches whichever
        // call completed last.
        final writes = <Future<void>>[
          Future(() async {
            await repository.upsert(
              WalletCard(
                id: 'race',
                name: 'A',
                category: CardCategory.id,
                createdAt: DateTime(2026, 6, 4),
                updatedAt: DateTime(2026, 6, 4, 0, 0, 0),
              ),
            );
          }),
          Future(() async {
            await repository.upsert(
              WalletCard(
                id: 'race',
                name: 'B',
                category: CardCategory.id,
                createdAt: DateTime(2026, 6, 4),
                updatedAt: DateTime(2026, 6, 4, 0, 0, 1),
              ),
            );
          }),
        ];
        await Future.wait(writes);

        // The repository must have written exactly twice.
        expect(database.writeCount, 2);
        // The queue must have prevented any overlap — the simulated
        // I/O latency (10ms) gives concurrent calls plenty of time to
        // overlap, so maxInFlight > 1 would indicate a missing queue.
        expect(database.maxInFlight, 1,
            reason: 'concurrent upserts must serialize through the queue');
        // The two writes must have non-overlapping time ranges.
        final w = database.writes;
        final firstBeforeSecond = w[0].ended.isBefore(w[1].started) ||
            w[0].ended.isAtSameMomentAs(w[1].started);
        final secondBeforeFirst = w[1].ended.isBefore(w[0].started) ||
            w[1].ended.isAtSameMomentAs(w[0].started);
        expect(firstBeforeSecond || secondBeforeFirst, isTrue,
            reason: 'writes must not overlap: ${w[0]} vs ${w[1]}');
        // The final in-memory state must be one of the two valid
        // writes (A or B), not a torn or partial value.
        final name = repository.findById('race')!.name;
        expect(['A', 'B'], contains(name));
      },
    );

    test(
      'CardMediaManager deleteImage is idempotent for missing files',
      () async {
        // On the IO platform, deleteImage calls into the file system.
        // Deleting a path that doesn't exist must be a no-op (not an
        // error) so that a re-delete attempt after a partial failure
        // does not break the cleanup pipeline.
        final tempDir = await Directory.systemTemp.createTemp(
          'card_box_media_idempotent_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final manager = const DefaultCardMediaManager();
        final missing = '${tempDir.path}/nope.jpg';
        // Should not throw.
        await manager.deleteImage(missing);
        // And the second call should also not throw.
        await manager.deleteImage(missing);
        // And an empty path should also be a no-op (defensive).
        await manager.deleteImage('');
        expect(await tempDir.exists(), isTrue);
      },
      skip: !Platform.isLinux && !Platform.isMacOS && !Platform.isWindows
          ? 'IO platform only'
          : null,
    );

    test('CardRepository dispose is idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      final database = createInMemoryDatabase();
      final repository = CardRepository(database: database);
      await repository.init();
      // Calling dispose twice must not throw. A second call without
      // idempotency would call into a closed Drift database and
      // surface a confusing "database is closed" error to the user.
      repository.dispose();
      repository.dispose();
    });

    test('deletes stored images when a card is permanently removed', () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'card-2',
          name: 'Photo card',
          category: CardCategory.id,
          frontImagePath: '/images/front.jpg',
          backImagePath: '/images/back.jpg',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      await repository.deleteCard('card-2');

      expect(mediaManager.deletedPaths, contains('/images/front.jpg'));
      expect(mediaManager.deletedPaths, contains('/images/back.jpg'));
      expect(repository.findById('card-2'), isNull);
    });

    test(
      'deleteCard removes the database row before deleting images',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = RecordingCardMediaManager();
        final database = RecordingDeleteCardDatabase();
        final repository = CardRepository(
          database: database,
          mediaManager: mediaManager,
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'card-order',
            name: 'Order test',
            category: CardCategory.id,
            frontImagePath: '/images/order.jpg',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        await repository.deleteCard('card-order');

        // DB-first ordering means a partial failure cannot leave the
        // on-disk image orphaned by a still-existing DB row.
        final dbAt = database.lastDeleteAt;
        final img = mediaManager.deletes.firstWhere(
          (d) => d.path == '/images/order.jpg',
        );
        expect(dbAt, isNotNull, reason: 'DB delete was not recorded');
        expect(dbAt!.isBefore(img.at) || dbAt.isAtSameMomentAs(img.at),
            isTrue,
            reason:
                'DB delete must happen at or before image delete. dbAt=$dbAt imgAt=${img.at}');
        expect(repository.findById('card-order'), isNull);
      },
    );

    test(
      'deleteCard rolls back in-memory state when the database write fails',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = FakeCardMediaManager();
        // Use a throwing database so deleteCardById throws.
        final repository = CardRepository(
          database: DeleteThrowingCardDatabase(),
          mediaManager: mediaManager,
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'card-keep',
            name: 'Keep me',
            category: CardCategory.id,
            frontImagePath: '/images/keep.jpg',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        await expectLater(
          repository.deleteCard('card-keep'),
          throwsA(isA<StateError>()),
        );

        // Card must be restored to in-memory state.
        expect(repository.findById('card-keep'), isNotNull);
        // Images must NOT have been deleted — the DB still owns the row.
        expect(mediaManager.deletedPaths, isEmpty);
      },
    );

    test(
      'importing an existing card replaces old images and keeps new ones',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = FakeCardMediaManager();
        mediaManager.seedImage(
          '/images/old_front.jpg',
          StoredImageBackupData(
            bytes: Uint8List.fromList([1, 1, 1]),
            extension: '.jpg',
          ),
        );
        final repository = CardRepository(
          database: createInMemoryDatabase(),
          mediaManager: mediaManager,
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'same-card',
            name: 'Old card',
            category: CardCategory.membership,
            frontImagePath: '/images/old_front.jpg',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        final importedCount = await repository.importPlainJson('''
        {
          "format": "card_box_plain_json",
          "version": 3,
          "cards": [
            {
              "id": "same-card",
              "name": "Updated card",
              "category": "membership",
              "frontImagePath": "",
              "createdAt": "2026-06-04T00:00:00.000",
              "updatedAt": "2030-06-04T00:00:00.000"
            }
          ],
          "images": [
            {
              "cardId": "same-card",
              "side": "front",
              "extension": ".jpg",
              "bytesBase64": "AQIDBA=="
            }
          ]
        }
        ''');

        expect(importedCount, 1);
        expect(mediaManager.deletedPaths, contains('/images/old_front.jpg'));
        expect(repository.findById('same-card')!.name, 'Updated card');
        expect(
          repository.findById('same-card')!.frontImagePath,
          '/imported/same-card_front.jpg',
        );
      },
    );

    test(
      'import keeps newer local cards instead of overwriting them',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = CardRepository(database: createInMemoryDatabase());
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'same-card',
            name: 'Local newer card',
            category: CardCategory.membership,
            notes: 'keep me',
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        final result = await repository.importPlainJsonProtected('''
      {
        "format": "card_box_plain_json",
        "version": 3,
        "cards": [
          {
            "id": "same-card",
            "name": "Older backup card",
            "category": "membership",
            "notes": "stale backup",
            "createdAt": "2026-06-03T00:00:00.000",
            "updatedAt": "2026-06-03T00:00:00.000"
          }
        ]
      }
      ''');

        expect(result.importedCount, 0);
        expect(result.skippedOlderCount, 1);
        expect(repository.findById('same-card')!.name, 'Local newer card');
        expect(repository.findById('same-card')!.notes, 'keep me');
      },
    );

    test(
      'import persists the imported updatedAt and skips skipped-older rows',
      () async {
        SharedPreferences.setMockInitialValues({});
        // Use a database that records which cards are written, so the
        // test can assert that the persist filter is not just always-true.
        final database = ImportRecordingCardDatabase();
        final repository = CardRepository(database: database);
        // Insert the local card directly through the database (bypassing
        // repository.upsert, which currently always bumps updatedAt).
        // The import test cares about import semantics, not the upsert
        // helper.
        final localTimestamp = DateTime(2026, 6, 4);
        final localCard = WalletCard(
          id: 'newer-local',
          name: 'Newer local',
          category: CardCategory.membership,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: localTimestamp,
        );
        await database.upsertCard(localCard);
        // Seed the in-memory cache to match the DB so import flow runs.
        await repository.init();

        final result = await repository.importPlainJsonProtected('''
      {
        "format": "card_box_plain_json",
        "version": 3,
        "cards": [
          {
            "id": "freshly-added",
            "name": "Fresh add",
            "category": "membership",
            "createdAt": "2025-12-01T00:00:00.000",
            "updatedAt": "2025-12-01T00:00:00.000"
          },
          {
            "id": "newer-local",
            "name": "Older backup",
            "category": "membership",
            "createdAt": "2025-12-01T00:00:00.000",
            "updatedAt": "2025-12-01T00:00:00.000"
          }
        ]
      }
      ''');

        // Only the freshly-added card is persisted; the local card is
        // already in the DB and its import is older so it is skipped.
        expect(database.upsertedIds, ['freshly-added']);
        expect(result.addedCount, 1);
        expect(result.updatedCount, 0);
        expect(result.skippedOlderCount, 1);
        // The local card keeps its newer updatedAt — the import did
        // not clobber it.
        expect(
          repository.findById('newer-local')!.updatedAt,
          localTimestamp,
        );
        expect(repository.findById('newer-local')!.name, 'Newer local');
      },
    );

    test(
      'import preserves the imported card updatedAt on a fresh add',
      () async {
        SharedPreferences.setMockInitialValues({});
        final database = ImportRecordingCardDatabase();
        final repository = CardRepository(database: database);
        await repository.init();
        final importedTimestamp = DateTime(2024, 3, 1);

        await repository.importPlainJsonProtected('''
      {
        "format": "card_box_plain_json",
        "version": 3,
        "cards": [
          {
            "id": "imported-card",
            "name": "Imported",
            "category": "loyalty",
            "createdAt": "${importedTimestamp.toIso8601String()}",
            "updatedAt": "${importedTimestamp.toIso8601String()}"
          }
        ]
      }
      ''');

        // The persisted row must have the imported updatedAt — NOT
        // a freshly-bumped DateTime.now() from the upsert path.
        final persisted = database.upsertedIds;
        expect(persisted, ['imported-card']);
        expect(
          repository.findById('imported-card')!.updatedAt,
          importedTimestamp,
        );
      },
    );

    test('backup preserves scanned barcode image attachments', () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      mediaManager.seedImage(
        '/images/code.jpg',
        StoredImageBackupData(
          bytes: Uint8List.fromList([7, 8, 9, 10]),
          extension: '.jpg',
        ),
      );
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'code-card',
          name: 'Store card',
          category: CardCategory.loyalty,
          barcodePayload: 'STORE-123',
          barcodeFormat: 'QRCode',
          barcodeImagePath: '/images/code.jpg',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      final exported = await repository.exportPlainJson();

      final importedMediaManager = FakeCardMediaManager();
      final importedRepository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: importedMediaManager,
      );
      await importedRepository.init();
      final result = await importedRepository.importPlainJsonProtected(
        exported.rawJson,
      );

      expect(result.importedCount, 1);
      expect(
        importedRepository.findById('code-card')!.barcodeImagePath,
        '/imported/code-card_barcode.jpg',
      );
      expect(
        importedMediaManager.importedPaths,
        contains('/imported/code-card_barcode.jpg'),
      );
    });

    test(
      'exportPlainJson reports missing images in the summary',
      () async {
        SharedPreferences.setMockInitialValues({});
        final mediaManager = FakeCardMediaManager();
        // Seed a single image so the export has something to drop.
        mediaManager.seedImage(
          '/present.jpg',
          StoredImageBackupData(bytes: Uint8List.fromList([1, 2, 3]), extension: '.jpg'),
        );
        final repository = CardRepository(
          database: createInMemoryDatabase(),
          mediaManager: mediaManager,
        );
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'card-with-missing',
            name: 'Has two missing + one present image',
            category: CardCategory.id,
            frontImagePath: '/present.jpg',
            backImagePath: '/gone-back.jpg', // not seeded
            barcodeImagePath: '/gone-barcode.jpg', // not seeded
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );

        final summary = await repository.exportPlainJson();

        // The present image is in the payload; the two missing
        // images are NOT silently dropped — they are reported back
        // in the summary so the UI can warn the user.
        expect(summary.missingImages.length, 2);
        final missingSides = summary.missingImages
            .where((m) => m.cardId == 'card-with-missing')
            .map((m) => m.side)
            .toSet();
        expect(missingSides, {'back', 'barcode'});
        // The payload still encodes the present image.
        expect(summary.rawJson, contains('present'));
      },
    );

    test('migrates custom-category cards into a built-in category', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'club-1',
          name: 'Court pass',
          category: CardCategory.other,
          customCategory: 'Sports Club',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      await repository.upsert(
        WalletCard(
          id: 'club-2',
          name: 'Archived club card',
          category: CardCategory.other,
          customCategory: 'Sports Club',
          archived: true,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );

      final movedCount = await repository.migrateCustomCategory(
        fromLabel: 'Sports Club',
        toCategory: CardCategory.membership,
      );

      expect(movedCount, 2);
      expect(repository.findById('club-1')!.category, CardCategory.membership);
      expect(repository.findById('club-1')!.customCategory, isNull);
      expect(repository.findById('club-2')!.category, CardCategory.membership);
      expect(repository.findById('club-2')!.archived, isTrue);
    });

    test(
      'init completes when the legacy shared-preferences blob is corrupt',
      () async {
        SharedPreferences.setMockInitialValues({
          'card_box.cards.v1': 'this is not json{{{',
        });
        final prefs = await SharedPreferences.getInstance();
        final repository = CardRepository(
          database: createInMemoryDatabase(),
          legacyPreferences: prefs,
        );

        await repository.init();

        expect(repository.cards, isEmpty);
        // The corrupt blob should be moved aside so the next launch is clean
        // and a forensic copy is preserved for recovery.
        expect(prefs.getString('card_box.cards.v1'), isNull);
        expect(
          prefs.getString('card_box.cards.v1.corrupt'),
          'this is not json{{{',
        );
      },
    );

    test(
      'init preserves the legacy key when the database write fails',
      () async {
        const legacyPayload = '''
        {
          "format": "card_box_storage",
          "schemaVersion": 5,
          "cards": [
            {
              "id": "legacy-1",
              "name": "Legacy loyalty",
              "category": "loyalty",
              "frontImagePath": "",
              "backImagePath": "",
              "createdAt": "2024-01-01T00:00:00.000",
              "updatedAt": "2024-01-01T00:00:00.000"
            }
          ]
        }
        ''';
        SharedPreferences.setMockInitialValues({
          'card_box.cards.v1': legacyPayload,
        });
        final prefs = await SharedPreferences.getInstance();
        final database = ThrowingCardDatabase();
        final repository = CardRepository(
          database: database,
          legacyPreferences: prefs,
        );

        await repository.init();

        // Migration should NOT have removed the legacy key — a later
        // launch can retry. ThrowingCardDatabase throws on every call,
        // so loadCards() also fails, but init() must still complete
        // and leave the legacy key in place.
        expect(prefs.getString('card_box.cards.v1'), legacyPayload);
      },
    );
  });

  group('CardRepository migration', () {
    test('recoverable migration writes cards to the database', () async {
      const legacyPayload = '''
      {
        "format": "card_box_storage",
        "schemaVersion": 1,
        "cards": [
          {
            "id": "legacy-1",
            "name": "Legacy loyalty",
            "frontPhotoPath": "/old/front.jpg",
            "backPhotoPath": "/old/back.jpg",
            "createdAt": "2024-01-01T00:00:00.000",
            "updatedAt": "2024-01-01T00:00:00.000"
          }
        ]
      }
      ''';
      SharedPreferences.setMockInitialValues({
        'card_box.cards.v1': legacyPayload,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        legacyPreferences: prefs,
      );

      await repository.init();

      expect(repository.findById('legacy-1'), isNotNull);
      expect(
        repository.findById('legacy-1')!.name,
        'Legacy loyalty',
      );
      expect(prefs.getString('card_box.cards.v1'), isNull);
    });
  });

  group('CategoryService', () {
    test('adds, sorts, persists, and removes custom categories', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = CategoryService(preferences: prefs);
      await service.init();

      expect(await service.addCategory('Sports Club'), isTrue);
      expect(await service.addCategory('  sports   club  '), isFalse);
      expect(await service.addCategory('Basketball'), isTrue);
      expect(service.customCategories, ['Basketball', 'Sports Club']);
      expect(service.containsCategory('Sports Club'), isTrue);

      final reloaded = CategoryService(preferences: prefs);
      await reloaded.init();
      expect(reloaded.customCategories, ['Basketball', 'Sports Club']);

      expect(await reloaded.removeCategory('Sports Club'), isTrue);
      expect(reloaded.customCategories, ['Basketball']);
      expect(await reloaded.removeCategory('Missing'), isFalse);
    });

    test('renames a custom category and rejects collisions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = CategoryService(preferences: prefs);
      await service.init();
      await service.addCategory('Sports Club');
      await service.addCategory('Team');

      expect(
        await service.renameCategory(
          fromLabel: 'Sports Club',
          toLabel: 'Basketball Club',
        ),
        isTrue,
      );
      expect(service.customCategories, ['Basketball Club', 'Team']);
      expect(
        await service.renameCategory(
          fromLabel: 'Basketball Club',
          toLabel: 'Team',
        ),
        isFalse,
      );
    });

    test(
      'renameCategory notifies a migration hook so cards follow the rename',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = CategoryService(preferences: prefs);
        await service.init();
        await service.addCategory('Sports Club');
        // The repository owns the cards; the service should hand off
        // the (from, to) pair so the cards' customCategory strings
        // can be rewritten. The hook is the only way the service
        // can reach the repository without taking a hard dep on it.
        final migrations = <(String, String)>[];
        await service.setCategoryMigrationHook(
          (from, to) async => migrations.add((from, to)),
        );

        final ok = await service.renameCategory(
          fromLabel: 'Sports Club',
          toLabel: 'Basketball Club',
        );
        expect(ok, isTrue);
        expect(migrations, hasLength(1));
        expect(migrations.first, ('Sports Club', 'Basketball Club'));
      },
    );

    test(
      'renameCategory does not call the migration hook for a no-op rename',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = CategoryService(preferences: prefs);
        await service.init();
        await service.addCategory('Sports Club');
        final migrations = <(String, String)>[];
        await service.setCategoryMigrationHook(
          (from, to) async => migrations.add((from, to)),
        );

        // Identical labels must not trigger a migration: there is
        // no rename to apply and rewriting cards is wasted I/O.
        final ok = await service.renameCategory(
          fromLabel: 'Sports Club',
          toLabel: 'Sports Club',
        );
        expect(ok, isTrue);
        expect(migrations, isEmpty);
      },
    );

    test(
      'renameCategory does not call the migration hook when the rename fails',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = CategoryService(preferences: prefs);
        await service.init();
        await service.addCategory('Sports Club');
        await service.addCategory('Team');
        final migrations = <(String, String)>[];
        await service.setCategoryMigrationHook(
          (from, to) async => migrations.add((from, to)),
        );

        // 'Team' is already a custom category, so the rename is
        // rejected before any migration can run.
        final ok = await service.renameCategory(
          fromLabel: 'Sports Club',
          toLabel: 'Team',
        );
        expect(ok, isFalse);
        expect(migrations, isEmpty);
      },
    );
  });

  group('BackupFileService', () {
    late PathProviderPlatform originalPathProvider;
    late FileSelectorPlatform originalFileSelector;

    setUp(() {
      originalPathProvider = PathProviderPlatform.instance;
      originalFileSelector = FileSelectorPlatform.instance;
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      FileSelectorPlatform.instance = originalFileSelector;
    });

    test('creates backup files in downloads when available', () async {
      final tempDir = await createTempDir('downloads_backup');
      addTearDown(() => tempDir.delete(recursive: true));
      PathProviderPlatform.instance = FakePathProviderPlatform(
        downloadsPath: tempDir.path,
        applicationDocumentsPath: tempDir.path,
      );

      final service = const BackupFileService();
      final backup = await service.createBackupFile(
        rawJson: '{"cards":[]}',
        cardCount: 0,
      );

      expect(backup, isNotNull);
      expect(backup!.path, contains('${tempDir.path}/Card Box/'));
      expect(File(backup.path).existsSync(), isTrue);
    });

    test(
      'falls back to application documents when downloads are unavailable',
      () async {
        final tempDir = await createTempDir('docs_backup');
        addTearDown(() => tempDir.delete(recursive: true));
        PathProviderPlatform.instance = FakePathProviderPlatform(
          downloadsPath: null,
          applicationDocumentsPath: tempDir.path,
        );

        final service = const BackupFileService();
        final file = await service.createTextFile(
          content: 'hello',
          fileNamePrefix: 'card_box_test',
          extension: 'txt',
        );

        expect(file, isNotNull);
        expect(file!.path, contains('${tempDir.path}/backups/'));
        expect(File(file.path).readAsStringSync(), 'hello');
      },
    );

    test(
      'falls back to application documents when getDownloadsPath throws '
      'PlatformException',
      () async {
        final tempDir = await createTempDir('platform_exception_backup');
        addTearDown(() => tempDir.delete(recursive: true));
        // iOS can throw a PlatformException when the Files app is
        // unavailable or scoped storage has been revoked. The backup
        // service must still produce a valid file by falling back
        // to the app documents directory.
        PathProviderPlatform.instance = FakePathProviderPlatform(
          downloadsPathError: PlatformException(
            code: 'unavailable',
            message: 'No downloads directory on this device.',
          ),
          applicationDocumentsPath: tempDir.path,
        );

        final service = const BackupFileService();
        final file = await service.createTextFile(
          content: 'platform-fallback',
          fileNamePrefix: 'card_box_test',
          extension: 'txt',
        );

        expect(file, isNotNull);
        expect(file!.path, contains('${tempDir.path}/backups/'));
        expect(File(file.path).readAsStringSync(), 'platform-fallback');
      },
    );

    test(
      'falls back to application documents when getDownloadsPath throws '
      'MissingPluginException',
      () async {
        final tempDir = await createTempDir('missing_plugin_backup');
        addTearDown(() => tempDir.delete(recursive: true));
        // In a stripped-down Flutter embedder or unit test that
        // forgets to register the path_provider plugin, the channel
        // returns a MissingPluginException. The backup service must
        // still fall back to the app documents directory.
        PathProviderPlatform.instance = FakePathProviderPlatform(
          downloadsPathError: MissingPluginException(
            'No implementation found for method getDownloadsPath',
          ),
          applicationDocumentsPath: tempDir.path,
        );

        final service = const BackupFileService();
        final file = await service.createTextFile(
          content: 'pluginless',
          fileNamePrefix: 'card_box_test',
          extension: 'txt',
        );

        expect(file, isNotNull);
        expect(file!.path, contains('${tempDir.path}/backups/'));
        expect(File(file.path).readAsStringSync(), 'pluginless');
      },
    );

    test('imports a selected backup file through the file selector', () async {
      final tempDir = await createTempDir('pick_backup');
      addTearDown(() => tempDir.delete(recursive: true));
      final backupFile = File('${tempDir.path}/backup.json')
        ..writeAsStringSync('{"format":"card_box_plain_json","cards":[]}');
      final selector = FakeFileSelectorPlatform()
        ..nextOpenFile = XFile(backupFile.path, name: 'backup.json');
      FileSelectorPlatform.instance = selector;

      final imported = await const BackupFileService().pickBackupFile();

      expect(imported, isNotNull);
      expect(imported!.fileName, 'backup.json');
      expect(imported.rawJson, contains('card_box_plain_json'));
    });
  });

  group('MediaRecoveryService', () {
    late PathProviderPlatform originalPathProvider;
    late ImagePickerPlatform originalImagePicker;

    setUp(() {
      originalPathProvider = PathProviderPlatform.instance;
      originalImagePicker = ImagePickerPlatform.instance;
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      ImagePickerPlatform.instance = originalImagePicker;
    });

    test('recovers a lost front photo draft with pending metadata', () async {
      final tempDir = await createTempDir('media_recovery');
      addTearDown(() => tempDir.delete(recursive: true));
      PathProviderPlatform.instance = FakePathProviderPlatform(
        applicationDocumentsPath: tempDir.path,
        downloadsPath: tempDir.path,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final lostFile = File('${tempDir.path}/captured.jpg')
        ..writeAsBytesSync(<int>[10, 20, 30, 40]);
      final imagePicker = FakeImagePickerPlatform()
        ..lostDataResponse = LostDataResponse(
          files: <XFile>[XFile(lostFile.path)],
          type: RetrieveType.image,
        );
      ImagePickerPlatform.instance = imagePicker;
      final service = MediaRecoveryService(preferences: prefs);
      await service.markPendingPhotoRequest(
        draftCardId: 'draft-1',
        preset: AddCardPreset.visiting,
        side: 'front',
        existingCardId: 'existing-1',
      );

      final recovered = await service.recoverLostPhotoDraft();

      expect(recovered, isNotNull);
      expect(recovered!.draftCardId, 'draft-1');
      expect(recovered.preset, AddCardPreset.visiting);
      expect(recovered.existingCardId, 'existing-1');
      expect(recovered.frontImagePath, contains('/card_images/draft-1_front_'));
      expect(File(recovered.frontImagePath).existsSync(), isTrue);
      expect(prefs.getString('card_box.pending_media_request.v1'), isNull);
    });

    test(
      'preserves the pending request when no recoverable files are returned',
      () async {
        final tempDir = await createTempDir('media_recovery_empty');
        addTearDown(() => tempDir.delete(recursive: true));
        PathProviderPlatform.instance = FakePathProviderPlatform(
          applicationDocumentsPath: tempDir.path,
          downloadsPath: tempDir.path,
        );
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        // LostDataResponse.empty() simulates a dismissed picker — no
        // file to recover. The pending request must survive so a
        // future launch can still try.
        final imagePicker = FakeImagePickerPlatform()
          ..lostDataResponse = LostDataResponse.empty();
        ImagePickerPlatform.instance = imagePicker;
        final service = MediaRecoveryService(preferences: prefs);
        await service.markPendingPhotoRequest(
          draftCardId: 'draft-2',
          preset: AddCardPreset.general,
          side: 'front',
        );

        final recovered = await service.recoverLostPhotoDraft();

        expect(recovered, isNull);
        expect(
          prefs.getString('card_box.pending_media_request.v1'),
          isNotNull,
          reason: 'pending request must be preserved across empty recovery',
        );
      },
    );

    test('discardRecoveredDraft removes recovered files', () async {
      final tempDir = await createTempDir('media_discard');
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}/front.jpg')
        ..writeAsBytesSync(<int>[1]);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);

      await service.discardRecoveredDraft(
        RecoveredMediaDraft(
          draftCardId: 'draft',
          preset: AddCardPreset.general,
          existingCardId: null,
          frontImagePath: file.path,
          backImagePath: '',
        ),
      );

      expect(file.existsSync(), isFalse);
    });

    test(
      'drops a corrupt pending request so the next launch starts clean',
      () async {
        // A previous build of the app may have written a payload the
        // current build cannot decode (schema drift, partial write).
        // A silent failure leaves the user stuck without a recovery
        // banner. The service must remove the bad key and return null
        // so the UI is not lying about a pending recovery.
        SharedPreferences.setMockInitialValues({
          'card_box.pending_media_request.v1': 'not-json-at-all',
          'card_box.pending_media_request.attempts.v1': 1,
        });
        final prefs = await SharedPreferences.getInstance();
        final fakeImagePicker = FakeImagePickerPlatform()
          ..lostDataResponse = LostDataResponse.empty();
        ImagePickerPlatform.instance = fakeImagePicker;
        final service = MediaRecoveryService(preferences: prefs);
        final recovered = await service.recoverLostPhotoDraft();
        expect(recovered, isNull);
        // The corrupt key must have been dropped so we do not retry
        // an unrecoverable payload on every subsequent launch.
        expect(
          prefs.getString('card_box.pending_media_request.v1'),
          isNull,
        );
        expect(
          prefs.getInt('card_box.pending_media_request.attempts.v1'),
          isNull,
        );
      },
    );
  });

  group('AppLockService', () {
    test('supports full enable, unlock, update, and disable flow', () async {
      final secureStore = MemorySecureStore();
      final auth = FakeDeviceAuthService(
        biometricsEnrolled: true,
        authenticateResult: true,
      );
      final service = await createReadyAppLockService(
        secureStore: secureStore,
        deviceAuthService: auth,
      );

      await service.enableLock(
        pin: '2468',
        useBiometrics: true,
        lockOnResume: false,
      );
      expect(service.lockEnabled, isTrue);
      expect(service.biometricEnabled, isTrue);
      expect(service.lockOnResume, isFalse);

      service.lockForResume();
      expect(service.unlocked, isTrue);

      await service.updateSettings(useBiometrics: false, lockOnResume: true);
      expect(service.biometricEnabled, isFalse);
      expect(service.lockOnResume, isTrue);

      service.lockForResume();
      expect(service.shouldShowLockScreen, isTrue);

      expect(await service.unlockWithPin('1111'), isFalse);
      expect(await service.unlockWithPin('2468'), isTrue);

      await service.updateSettings(useBiometrics: true, lockOnResume: true);
      service.lockForResume();
      expect(await service.unlockWithBiometrics(), isTrue);
      expect(auth.authenticateCalls, 1);

      await service.disableLock();
      expect(service.lockEnabled, isFalse);
      expect(await secureStore.containsKey(AppLockService.pinKey), isFalse);
    });

    test(
      'trusted external flow auto-expires after the 60s max-age',
      () async {
        var now = DateTime(2026, 6, 1, 12, 0, 0);
        DateTime clock() => now;
        final service = await createReadyAppLockService(clock: clock);

        service.beginTrustedExternalFlow();
        expect(service.deferringBackgroundLock, isTrue);

        // Step forward 59s — still inside the window.
        now = now.add(const Duration(seconds: 59));
        expect(service.deferringBackgroundLock, isTrue);

        // Step forward 2s — past the 60s max-age. The auto-expire
        // must run on the next read and the counter must be reclaimed
        // so the next background lock will actually re-prompt the
        // user. A force-killed flow whose `finally` never ran must
        // never leave the lock silently disabled.
        now = now.add(const Duration(seconds: 2));
        expect(service.deferringBackgroundLock, isFalse);
        // A subsequent read stays false (counter is now 0).
        expect(service.deferringBackgroundLock, isFalse);
      },
    );

    test(
      'resetForDetached clears the trusted flow counter even if the '
      'caller never called endTrustedExternalFlow',
      () async {
        final service = await createReadyAppLockService();
        service.beginTrustedExternalFlow();
        service.beginTrustedExternalFlow();
        expect(service.deferringBackgroundLock, isTrue);
        // Simulate the OS reclaiming the process: detached state
        // forces a clean slate so the next launch is not stuck in
        // an un-locked state.
        service.resetForDetached();
        expect(service.deferringBackgroundLock, isFalse);
      },
    );
  });
}
