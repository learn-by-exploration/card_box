// Round-trip smoke test: create a card, export an encrypted
// backup, wipe the database, import the backup, and verify the
// card and its image bytes are restored. This is the
// release-build safety net the stabilization plan calls for.

import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/backup_crypto_service.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'card round-trips through encrypted export, wipe, and import',
    () async {
      SharedPreferences.setMockInitialValues({});
      final mediaManager = FakeCardMediaManager();
      // Seed an image on disk so the export has bytes to bundle.
      final frontBytes = Uint8List.fromList(
        List<int>.generate(64, (i) => i % 251),
      );
      const frontPath = '/images/round_trip_front.jpg';
      mediaManager.seedImage(
        frontPath,
        StoredImageBackupData(bytes: frontBytes, extension: '.jpg'),
      );

      final originalCard = WalletCard(
        id: 'round-trip-card',
        name: 'Round Trip Card',
        issuer: 'Issuer',
        category: CardCategory.loyalty,
        notes: 'Smoke test',
        frontImagePath: frontPath,
        createdAt: DateTime(2026, 6, 4),
        updatedAt: DateTime(2026, 6, 4, 0, 0, 5),
      );

      // 1. Create a repository, persist the card.
      final repository = CardRepository(
        database: createInMemoryDatabase(),
        mediaManager: mediaManager,
      );
      await repository.init();
      await repository.upsert(originalCard);

      // 2. Export an encrypted backup and capture the bytes.
      final crypto = BackupCryptoService();
      const password = 'round-trip-password';
      final summary = await repository.exportPlainJson();
      final encrypted = await crypto.encryptJson(
        rawJson: summary.rawJson,
        password: password,
      );

      // 3. Wipe the database. A fresh in-memory database simulates
      // the user uninstalling and reinstalling the app.
      repository.dispose();
      final wipedDatabase = createInMemoryDatabase();
      final wipedCards = await wipedDatabase.loadCards();
      expect(wipedCards, isEmpty);
      // The repository's media store still has the image on disk
      // because we never called deleteCard, but a real wipe would
      // also clear the on-disk images. Simulate that too.
      await mediaManager.deleteImage(frontPath);

      // 4. Re-import the encrypted backup into a fresh repository
      // against the wiped database.
      final restored = CardRepository(
        database: wipedDatabase,
        mediaManager: mediaManager,
      );
      await restored.init();
      final decryptedJson = await crypto.decryptJson(
        encryptedJson: encrypted,
        password: password,
      );
      final importResult = await restored.importPlainJsonProtected(
        decryptedJson,
      );
      expect(importResult.addedCount, 1);
      expect(importResult.updatedCount, 0);

      // 5. Verify the card and its image bytes are restored.
      final reloaded = await wipedDatabase.loadCards();
      expect(reloaded, hasLength(1));
      final restoredCard = reloaded.first;
      expect(restoredCard.id, originalCard.id);
      expect(restoredCard.name, originalCard.name);
      expect(restoredCard.frontImagePath, isNotEmpty);
      // The image bytes may live at a different path after
      // re-import (the media manager rewrites the path), so read
      // the bytes through the manager rather than the original
      // path.
      final restoredBytes = await mediaManager.readImageForBackup(
        restoredCard.frontImagePath,
      );
      expect(restoredBytes, isNotNull);
      expect(restoredBytes!.bytes, equals(frontBytes));

      restored.dispose();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
