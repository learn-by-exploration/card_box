import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/backup_file_info.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/imported_backup.dart';
import 'package:card_box/models/nfc_scan_result.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/models/visiting_card_extraction.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/category_settings_screen.dart';
import 'package:card_box/screens/compatibility_test_screen.dart';
import 'package:card_box/screens/edit_card_screen.dart';
import 'package:card_box/screens/export_import_screen.dart';
import 'package:card_box/screens/visiting_card_review_screen.dart';
import 'package:card_box/services/backup_crypto_service.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/device_settings_service.dart';
import 'package:card_box/services/file_share_service.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/services/nfc_service.dart';
import 'package:card_box/services/visiting_card_ocr_service.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('EditCardScreen', () {
    testWidgets('saves a custom category and registers it in settings', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final mediaRecoveryService = MediaRecoveryService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          EditCardScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            mediaRecoveryService: mediaRecoveryService,
          ),
        ),
      );

      await tester.enterText(_fieldWithLabel('Card name'), 'Saturday Hoops');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(_fieldWithLabel('Custom category'), 'Sports Club');

      final saveButton = find.byType(FilledButton).last;
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, -1400),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.cards, hasLength(1));
      final card = repository.cards.single;
      expect(card.name, 'Saturday Hoops');
      expect(card.category, CardCategory.other);
      expect(card.customCategory, 'Sports Club');
      expect(categoryService.customCategories, contains('Sports Club'));
    });

    testWidgets('extracts visiting card details and applies reviewed values', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final mediaRecoveryService = MediaRecoveryService(preferences: prefs);
      const frontImagePath = '/tmp/visiting_front.png';
      final fakeOcrService = FakeVisitingCardOcrService(
        extraction: const VisitingCardExtraction(
          suggestedName: 'Aiko Tanaka',
          suggestedCompany: 'CourtSide Japan',
          suggestedTitle: 'Community Manager',
          suggestedPhones: <String>['+81 90 1111 2222'],
          suggestedEmails: <String>['aiko@example.jp'],
          suggestedWebsites: <String>['courtside.jp'],
          suggestedAddress: 'Tokyo, Japan',
          rawOcrText: 'Aiko Tanaka\nCourtSide Japan',
        ),
      );

      await tester.pumpWidget(
        wrapForTest(
          EditCardScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            mediaRecoveryService: mediaRecoveryService,
            preset: AddCardPreset.visiting,
            recoveredMediaDraft: RecoveredMediaDraft(
              draftCardId: 'draft-contact',
              preset: AddCardPreset.visiting,
              frontImagePath: frontImagePath,
            ),
            visitingCardOcrService: fakeOcrService,
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Extract details'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Extract details'));
      await tester.pumpAndSettle();

      expect(find.text('Review extracted details'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Use selected details'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Use selected details'));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, -1800),
        1000,
      );
      await tester.pumpAndSettle();
      final saveButton = find.byType(FilledButton).last;
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final saved = repository.cards.single;
      expect(saved.name, 'Aiko Tanaka');
      expect(saved.issuer, 'CourtSide Japan');
      expect(saved.contactTitle, 'Community Manager');
      expect(saved.contactPhones, <String>['+81 90 1111 2222']);
      expect(fakeOcrService.lastFrontImagePath, frontImagePath);
    });

    testWidgets('existing cards expose help and archive controls', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final existing = WalletCard(
        id: 'club-card',
        name: 'Club Card',
        category: CardCategory.membership,
        createdAt: DateTime(2026, 6, 6),
        updatedAt: DateTime(2026, 6, 6),
      );
      await repository.upsert(existing);
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final mediaRecoveryService = MediaRecoveryService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => EditCardScreen(
                repository: repository,
                appLockService: appLockService,
                categoryService: categoryService,
                mediaRecoveryService: mediaRecoveryService,
                existingCard: existing,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Help'), findsOneWidget);
      expect(find.byTooltip('Archive card'), findsOneWidget);
      expect(find.byTooltip('Delete permanently'), findsOneWidget);

      await tester.tap(find.byTooltip('Help'));
      await tester.pumpAndSettle();
      expect(find.text('How this card flow works'), findsOneWidget);
      expect(find.textContaining('Enter the card name'), findsOneWidget);

      Navigator.of(tester.element(find.text('How this card flow works'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Archive card'));
      await tester.pumpAndSettle();
      expect(repository.findById(existing.id)!.archived, isTrue);
    });
  });

  group('ExportImportScreen', () {
    testWidgets('creates a standard backup and records the shared result', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'library',
          name: 'Library card',
          category: CardCategory.library,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final backupService = FakeBackupFileService(
        createdBackup: BackupFileInfo(
          path: '/tmp/card_box_backup.json',
          fileName: 'card_box_backup.json',
          createdAt: DateTime(2026, 6, 7, 12),
          cardCount: 1,
        ),
      );
      final shareService = FakeFileShareService(shareResult: true);

      await tester.pumpWidget(
        wrapForTest(
          ExportImportScreen(
            repository: repository,
            appLockService: appLockService,
            backupFileService: backupService,
            fileShareService: shareService,
          ),
        ),
      );

      await tester.tap(find.text('Create and share standard backup').last);
      await tester.pumpAndSettle();

      expect(find.text('Latest backup'), findsOneWidget);
      expect(find.textContaining('opened in the share sheet'), findsOneWidget);
      expect(backupService.lastCreateCardCount, 1);
      expect(shareService.sharedPaths, contains('/tmp/card_box_backup.json'));
    });

    testWidgets('imports an encrypted backup and keeps newer local cards', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final sourceRepository = CardRepository(
        database: createInMemoryDatabase(),
      );
      await sourceRepository.init();
      await sourceRepository.upsert(
        WalletCard(
          id: 'same-card',
          name: 'Backup Older',
          category: CardCategory.membership,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 4, 10),
        ),
      );
      await sourceRepository.upsert(
        WalletCard(
          id: 'new-card',
          name: 'Fresh Backup Card',
          category: CardCategory.loyalty,
          createdAt: DateTime(2026, 6, 5),
          updatedAt: DateTime(2026, 6, 5),
        ),
      );

      final plainJson = await sourceRepository.exportPlainJson();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'same-card',
          name: 'Local Newer',
          category: CardCategory.membership,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 7, 10),
        ),
      );
      final cryptoService = FakeBackupCryptoService(
        decryptedJson: plainJson.rawJson,
      );
      final password = 'password123';
      const encryptedJson = '{"format":"card_box_encrypted_backup"}';
      final appLockService = await createReadyAppLockService();
      final backupService = FakeBackupFileService(
        importedBackup: ImportedBackup(
          fileName: 'backup_encrypted.json',
          rawJson: encryptedJson,
        ),
      );

      await tester.pumpWidget(
        wrapForTest(
          ExportImportScreen(
            repository: repository,
            appLockService: appLockService,
            backupFileService: backupService,
            backupCryptoService: cryptoService,
          ),
        ),
      );

      await tester.tap(find.text('Choose backup file').last);
      await tester.pumpAndSettle();
      await tester.enterText(_fieldWithLabel('Backup password'), password);
      await tester.tap(find.text('Decrypt backup').last);
      await tester.pumpAndSettle();

      expect(repository.findById('same-card')?.name, 'Local Newer');
      expect(repository.findById('new-card')?.name, 'Fresh Backup Card');
      expect(find.textContaining('Kept 1 newer card'), findsOneWidget);
    });
  });

  group('CompatibilityTestScreen', () {
    testWidgets('refreshes NFC availability after opening settings', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final card = WalletCard(
        id: 'nfc-card',
        name: 'Club card',
        category: CardCategory.membership,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      await repository.upsert(card);
      final appLockService = await createReadyAppLockService();
      final nfcService = FakeNfcService(
        availabilitySequence: <NfcAvailability>[
          NfcAvailability.disabled,
          NfcAvailability.enabled,
        ],
      );
      final settingsService = FakeDeviceSettingsService(
        openNfcSettingsResult: true,
      );

      await tester.pumpWidget(
        wrapForTest(
          CompatibilityTestScreen(
            repository: repository,
            appLockService: appLockService,
            card: card,
            nfcService: nfcService,
            deviceSettingsService: settingsService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('NFC exists but is currently disabled.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Turn on NFC').last);
      await tester.pumpAndSettle();

      expect(settingsService.openNfcSettingsCalls, 1);
      expect(find.text('NFC is available on this device.'), findsOneWidget);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan NFC card').last);
      await tester.pumpAndSettle();
      expect(find.text('Use NFC reader?'), findsOneWidget);
    });

    testWidgets('applies a successful NFC scan and saves the result', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final card = WalletCard(
        id: 'nfc-card',
        name: 'Transit card',
        category: CardCategory.transit,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      await repository.upsert(card);
      final appLockService = await createReadyAppLockService();
      final nfcService = FakeNfcService(
        availabilitySequence: <NfcAvailability>[NfcAvailability.enabled],
        scanResult: const NfcScanResult(
          status: CompatibilityStatus.nfcReadable,
          summary: 'NFC NDEF readable',
          detail: 'NDEF type: text/plain',
        ),
      );

      await tester.pumpWidget(
        wrapForTest(
          CompatibilityTestScreen(
            repository: repository,
            appLockService: appLockService,
            card: card,
            nfcService: nfcService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan NFC card').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start NFC').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save result').last);
      await tester.pumpAndSettle();

      final saved = repository.findById('nfc-card');
      expect(saved?.compatibilityStatus, CompatibilityStatus.nfcReadable);
      expect(saved?.nfcTagSummary, 'NDEF type: text/plain');
    });
  });

  group('CategorySettingsScreen', () {
    testWidgets('adds and renames a custom category', (tester) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );

      await tester.pumpWidget(
        wrapForTest(
          CategorySettingsScreen(
            categoryService: categoryService,
            repository: repository,
          ),
        ),
      );

      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(_fieldWithLabel('Category name'), 'Sports Club');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(categoryService.customCategories, contains('Sports Club'));

      await tester.tap(find.byTooltip('Category actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      await tester.enterText(_fieldWithLabel('Category name'), 'Hoops Club');
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();

      expect(categoryService.customCategories, contains('Hoops Club'));
      expect(categoryService.customCategories, isNot(contains('Sports Club')));
    });

    testWidgets('migrates cards from a custom category into a built-in one', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'sports-card',
          name: 'Saturday Run',
          category: CardCategory.other,
          customCategory: 'Sports Club',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
        customCategories: const <String>['Sports Club'],
      );

      await tester.pumpWidget(
        wrapForTest(
          CategorySettingsScreen(
            categoryService: categoryService,
            repository: repository,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Category actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move cards').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move cards').last);
      await tester.pumpAndSettle();

      final migrated = repository.findById('sports-card');
      expect(migrated?.category, CardCategory.library);
      expect(migrated?.customCategory, isNull);
      expect(find.textContaining('1 card moved to Library.'), findsOneWidget);
    });
  });

  group('VisitingCardReviewScreen', () {
    testWidgets('returns only selected fields and trims multiline values', (
      tester,
    ) async {
      await _setLargeSurface(tester);
      VisitingCardReviewResult? result;

      await tester.pumpWidget(
        wrapForTest(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push(
                      MaterialPageRoute<VisitingCardReviewResult>(
                        builder: (_) => const VisitingCardReviewScreen(
                          extraction: VisitingCardExtraction(
                            suggestedName: 'Aiko Tanaka',
                            suggestedCompany: 'CourtSide Japan',
                            suggestedTitle: 'Coach',
                            suggestedPhones: <String>['123'],
                            suggestedEmails: <String>['aiko@example.jp'],
                            suggestedWebsites: <String>['courtside.jp'],
                            suggestedAddress: 'Tokyo',
                            rawOcrText: 'raw lines',
                          ),
                          frontImagePath: '',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        _fieldWithLabel('Phone numbers'),
        ' 123 \n\n 456  ',
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Emails'));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, -1000),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use selected details').last);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'Aiko Tanaka');
      expect(result!.phones, <String>['123', '456']);
      expect(result!.emails, isEmpty);
      expect(result!.rawOcrText, 'raw lines');
    });
  });
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Finder _fieldWithLabel(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator && widget.decoration.labelText == label,
      description: 'InputDecorator($label)',
    ),
    matching: find.byType(EditableText),
  );
}

class FakeBackupFileService extends BackupFileService {
  FakeBackupFileService({this.createdBackup, this.importedBackup});

  final BackupFileInfo? createdBackup;
  final ImportedBackup? importedBackup;
  String? lastCreateRawJson;
  int? lastCreateCardCount;
  String? lastFileNamePrefix;

  @override
  Future<BackupFileInfo?> createBackupFile({
    required String rawJson,
    required int cardCount,
    String fileNamePrefix = 'card_box_backup',
  }) async {
    lastCreateRawJson = rawJson;
    lastCreateCardCount = cardCount;
    lastFileNamePrefix = fileNamePrefix;
    return createdBackup;
  }

  @override
  Future<ImportedBackup?> pickBackupFile() async => importedBackup;
}

class FakeBackupCryptoService extends BackupCryptoService {
  FakeBackupCryptoService({required this.decryptedJson});

  final String decryptedJson;
  String? lastPassword;

  @override
  Future<String> decryptJson({
    required String encryptedJson,
    required String password,
  }) async {
    lastPassword = password;
    return decryptedJson;
  }

  @override
  bool looksEncrypted(String rawJson) => true;
}

class FakeFileShareService extends FileShareService {
  FakeFileShareService({required this.shareResult});

  final bool shareResult;
  final List<String> sharedPaths = <String>[];

  @override
  Future<bool> shareFile({
    required String path,
    required String subject,
    String? text,
  }) async {
    sharedPaths.add(path);
    return shareResult;
  }
}

class FakeDeviceSettingsService extends DeviceSettingsService {
  FakeDeviceSettingsService({required this.openNfcSettingsResult});

  final bool openNfcSettingsResult;
  int openNfcSettingsCalls = 0;

  @override
  Future<bool> openNfcSettings() async {
    openNfcSettingsCalls += 1;
    return openNfcSettingsResult;
  }
}

class FakeNfcService extends NfcService {
  FakeNfcService({List<NfcAvailability>? availabilitySequence, this.scanResult})
    : _availabilitySequence =
          availabilitySequence ?? <NfcAvailability>[NfcAvailability.enabled],
      super(isWeb: false, platform: TargetPlatform.android);

  final List<NfcAvailability> _availabilitySequence;
  final NfcScanResult? scanResult;
  int _availabilityIndex = 0;

  @override
  Future<NfcAvailability> checkAvailability() async {
    final index = _availabilityIndex;
    if (_availabilityIndex < _availabilitySequence.length - 1) {
      _availabilityIndex += 1;
    }
    return _availabilitySequence[index];
  }

  @override
  Future<NfcScanResult> scanTag() async {
    return scanResult ??
        const NfcScanResult(
          status: CompatibilityStatus.unsupported,
          summary: 'No scan configured.',
          detail: 'No fake NFC result was configured for this test.',
        );
  }
}

class FakeVisitingCardOcrService extends VisitingCardOcrService {
  FakeVisitingCardOcrService({required this.extraction});

  final VisitingCardExtraction extraction;
  String? lastFrontImagePath;
  String? lastBackImagePath;

  @override
  Future<VisitingCardExtraction> extractFromImages({
    required String frontImagePath,
    String? backImagePath,
  }) async {
    lastFrontImagePath = frontImagePath;
    lastBackImagePath = backImagePath;
    return extraction;
  }
}
