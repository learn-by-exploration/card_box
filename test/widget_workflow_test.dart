import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/app_lock_settings_screen.dart';
import 'package:card_box/screens/app_root.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/screens/card_search_screen.dart';
import 'package:card_box/screens/home_screen.dart';
import 'package:card_box/screens/theme_settings_screen.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('HomeScreen', () {
    testWidgets('search screen and category filter work together', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'barcode-card',
          name: 'Library card',
          issuer: 'City Library',
          category: CardCategory.library,
          barcodePayload: 'LIB-123',
          barcodeFormat: 'Code128',
          compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      await repository.upsert(
        WalletCard(
          id: 'visit-card',
          name: 'Aiko Tanaka',
          issuer: 'CourtSide Japan',
          category: CardCategory.contact,
          cardType: CardType.visitingCard,
          rawOcrText: 'basketball community manager',
          contactTitle: 'Community Manager',
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      await repository.upsert(
        WalletCard(
          id: 'ref-card',
          name: 'Office badge',
          category: CardCategory.access,
          compatibilityStatus: CompatibilityStatus.referenceOnly,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final themeService = await createReadyThemeService(preferences: prefs);
      final mediaRecoveryService = MediaRecoveryService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            themeService: themeService,
            mediaRecoveryService: mediaRecoveryService,
            onRecoveredMediaDiscarded: () async {},
            onRecoveredMediaUsed: () {},
          ),
        ),
      );

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'basketball');
      await tester.pumpAndSettle();
      expect(find.text('Aiko Tanaka'), findsOneWidget);
      expect(find.text('Library card'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();
      expect(find.text('Library card'), findsOneWidget);
      expect(find.text('Aiko Tanaka'), findsNothing);
      expect(find.text('Office badge'), findsOneWidget);

      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library').last);
      await tester.pumpAndSettle();
      expect(find.text('Library card'), findsOneWidget);
      expect(find.text('Aiko Tanaka'), findsNothing);

      // Help entry should live inside the three-dot menu, not as a FAB.
      expect(find.byTooltip('How to add cards'), findsNothing);
      expect(find.byTooltip('help_fab'), findsNothing);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How to add'));
      await tester.pumpAndSettle();
      expect(find.text('How to add a card'), findsOneWidget);
      expect(find.text('Barcode card'), findsOneWidget);
      expect(find.text('General card'), findsOneWidget);
    });

    testWidgets('barcode card actions open full-screen code presentation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'barcode-card',
          name: 'Gym pass',
          issuer: 'Gym',
          category: CardCategory.membership,
          barcodePayload: 'GYM-42',
          barcodeFormat: 'qr',
          compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final themeService = await createReadyThemeService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            themeService: themeService,
            mediaRecoveryService: MediaRecoveryService(preferences: prefs),
            onRecoveredMediaDiscarded: () async {},
            onRecoveredMediaUsed: () {},
          ),
        ),
      );

      await tester.tap(find.text('Gym pass'));
      await tester.pumpAndSettle();
      expect(find.text('Show code'), findsOneWidget);

      await tester.tap(find.text('Show code'));
      await tester.pumpAndSettle();
      expect(find.text('GYM-42'), findsOneWidget);
      expect(find.text('Gym pass'), findsWidgets);
    });

    testWidgets('"More options" sheet scrolls when many actions are shown', (
      tester,
    ) async {
      // Use a small viewport so the bottom actions fall below the fold.
      await tester.binding.setSurfaceSize(const Size(360, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'long-card',
          name: 'Library card',
          issuer: 'City Library',
          category: CardCategory.library,
          barcodePayload: 'LIB-123',
          barcodeFormat: 'code128',
          compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final themeService = await createReadyThemeService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            themeService: themeService,
            mediaRecoveryService: MediaRecoveryService(preferences: prefs),
            onRecoveredMediaDiscarded: () async {},
            onRecoveredMediaUsed: () {},
          ),
        ),
      );

      await tester.tap(find.text('Library card'));
      await tester.pumpAndSettle();

      // The card tile also shows "More options" as a label, so check the
      // sheet header specifically via the last occurrence in the tree.
      expect(find.text('More options'), findsWidgets);
      expect(find.text('More options').last, findsOneWidget);
      // Scroll affordance (Scrollbar) is rendered in the sheet.
      expect(find.byType(Scrollbar), findsOneWidget);
      // First action is visible without scrolling.
      expect(find.text('Show code'), findsOneWidget);
      // Bottom actions must be reachable by scrolling.
      await tester.scrollUntilVisible(
        find.text('View details'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('View details'), findsOneWidget);
      // All listed actions are now present in the tree.
      expect(find.text('Share card'), findsOneWidget);
      expect(find.text('Edit card'), findsOneWidget);
    });

    testWidgets('recovered media card can be discarded from home', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final themeService = await createReadyThemeService(preferences: prefs);
      var discarded = false;

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            themeService: themeService,
            mediaRecoveryService: MediaRecoveryService(preferences: prefs),
            recoveredMediaDraft: const RecoveredMediaDraft(
              draftCardId: 'draft-1',
              preset: AddCardPreset.general,
              frontImagePath: '/tmp/front.jpg',
            ),
            onRecoveredMediaDiscarded: () async {
              discarded = true;
            },
            onRecoveredMediaUsed: () {},
          ),
        ),
      );

      expect(find.textContaining('Recovered front photo'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(discarded, isTrue);
      expect(find.text('Recovered photo discarded.'), findsOneWidget);
    });

    testWidgets('custom categories appear in the card filter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
        customCategories: const ['Sports Club'],
      );
      final themeService = await createReadyThemeService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            themeService: themeService,
            mediaRecoveryService: MediaRecoveryService(preferences: prefs),
            onRecoveredMediaDiscarded: () async {},
            onRecoveredMediaUsed: () {},
          ),
        ),
      );

      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();

      expect(find.text('Sports Club'), findsOneWidget);
      expect(find.text('All categories'), findsWidgets);
    });
  });

  group('CardSearchScreen', () {
    testWidgets('shows recent items when query is empty', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'recent-1',
          name: 'Newest card',
          category: CardCategory.loyalty,
          updatedAt: DateTime(2026, 6, 6, 12),
          createdAt: DateTime(2026, 6, 6, 12),
        ),
      );
      await repository.upsert(
        WalletCard(
          id: 'recent-2',
          name: 'Older card',
          category: CardCategory.library,
          updatedAt: DateTime(2026, 6, 5, 12),
          createdAt: DateTime(2026, 6, 5, 12),
        ),
      );

      await tester.pumpWidget(
        wrapForTest(
          CardSearchScreen(
            repository: repository,
            showContactsInitially: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('recent item'), findsOneWidget);
      expect(find.text('Newest card'), findsOneWidget);
      expect(find.text('Older card'), findsOneWidget);
    });

    testWidgets('remembers last selected mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'card-item',
          name: 'Wallet card',
          category: CardCategory.loyalty,
          updatedAt: DateTime(2026, 6, 6, 12),
          createdAt: DateTime(2026, 6, 6, 12),
        ),
      );
      await repository.upsert(
        WalletCard(
          id: 'contact-item',
          name: 'Aiko Tanaka',
          category: CardCategory.contact,
          cardType: CardType.visitingCard,
          updatedAt: DateTime(2026, 6, 6, 13),
          createdAt: DateTime(2026, 6, 6, 13),
        ),
      );

      await tester.pumpWidget(
        wrapForTest(
          CardSearchScreen(
            repository: repository,
            showContactsInitially: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        wrapForTest(
          CardSearchScreen(
            repository: repository,
            showContactsInitially: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aiko Tanaka'), findsOneWidget);
      expect(find.text('Wallet card'), findsNothing);
    });
  });

  group('Theme settings', () {
    testWidgets('theme mode and palette can be updated from settings', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeService = await createReadyThemeService(
        preferences: prefs,
        initialMode: ThemeMode.system,
        initialPalette: CardBoxThemePalette.softTeal,
      );

      await tester.pumpWidget(
        wrapForTest(ThemeSettingsScreen(themeService: themeService)),
      );
      await tester.pumpAndSettle();

      expect(themeService.themeMode, ThemeMode.system);
      expect(themeService.palette, CardBoxThemePalette.softTeal);
      await tester.tap(find.text('Slate'));
      await tester.pumpAndSettle();
      expect(themeService.palette, CardBoxThemePalette.slate);
      expect(
        prefs.getString(ThemeService.themePaletteKey),
        CardBoxThemePalette.slate.storageKey,
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeService.themeMode, ThemeMode.dark);
      expect(prefs.getString(ThemeService.themeModeKey), 'dark');
    });
  });

  group('AppRoot and lock flow', () {
    testWidgets('locked app unlocks with PIN and obscures on inactive', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(
        seedDemoCards: true,
        database: createInMemoryDatabase(),
      );
      await repository.init();
      final appLockService = await createReadyAppLockService(
        lockEnabled: true,
        pin: '1234',
      );
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );
      final themeService = await createReadyThemeService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          AppRoot(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            themeService: themeService,
            mediaRecoveryService: MediaRecoveryService(preferences: prefs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock Card Box'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0000');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('That PIN did not match.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Card Box'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final expectedScrim = CardBoxThemeTokens.of(
        tester.element(find.byType(AppRoot)),
      ).appObscureScrim;
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == expectedScrim,
        ),
        findsOneWidget,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == const Color(0xFF0F1713),
        ),
        findsNothing,
      );
    });
  });

  group('Settings and detail screens', () {
    testWidgets('app lock settings can create and update lock settings', (
      tester,
    ) async {
      final auth = FakeDeviceAuthService(biometricsEnrolled: true);
      final appLockService = await createReadyAppLockService(
        deviceAuthService: auth,
      );

      await tester.pumpWidget(
        wrapForTest(AppLockSettingsScreen(appLockService: appLockService)),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'PIN'), '2468');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm PIN'),
        '2468',
      );
      await tester.tap(find.text('Turn on app lock'));
      await tester.pumpAndSettle();

      expect(appLockService.lockEnabled, isTrue);
      expect(find.text('App lock is enabled.'), findsOneWidget);

      await tester.tap(find.text('Lock when app resumes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lock settings'));
      await tester.pumpAndSettle();
      expect(appLockService.lockOnResume, isFalse);
    });

    testWidgets('card detail reflects visiting-card specific actions', (
      tester,
    ) async {
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'visit-card',
          name: 'Aiko Tanaka',
          issuer: 'CourtSide Japan',
          category: CardCategory.contact,
          cardType: CardType.visitingCard,
          contactPhones: const ['+81 90 1111 2222'],
          contactEmails: const ['aiko@example.com'],
          contactWebsites: const ['courtside.jp'],
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService();

      await tester.pumpWidget(
        wrapForTest(
          CardDetailScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
            cardId: 'visit-card',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show contact QR'), findsOneWidget);
      expect(find.text('Share contact'), findsOneWidget);
      expect(find.text('More actions'), findsOneWidget);
      expect(find.textContaining('NFC/RFID'), findsNothing);

      await tester.tap(find.text('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Copy contact'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Export vCard'), findsOneWidget);
    });

    testWidgets(
      'mixed-interface visiting cards keep share contact in primary actions',
      (tester) async {
        final repository = CardRepository(database: createInMemoryDatabase());
        await repository.init();
        await repository.upsert(
          WalletCard(
            id: 'visit-code-card',
            name: 'Aiko Tanaka',
            issuer: 'CourtSide Japan',
            category: CardCategory.contact,
            cardType: CardType.visitingCard,
            barcodePayload: 'https://courtside.jp/aiko',
            barcodeFormat: 'qrCode',
            contactPhones: const ['+81 90 1111 2222'],
            contactEmails: const ['aiko@example.com'],
            createdAt: DateTime(2026, 6, 4),
            updatedAt: DateTime(2026, 6, 4),
          ),
        );
        final appLockService = await createReadyAppLockService();
        final categoryService = await createReadyCategoryService();

        await tester.pumpWidget(
          wrapForTest(
            CardDetailScreen(
              repository: repository,
              appLockService: appLockService,
              categoryService: categoryService,
              cardId: 'visit-code-card',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Show contact QR'), findsOneWidget);
        expect(find.text('Share contact'), findsOneWidget);
        expect(find.text('Present code'), findsNothing);
        expect(find.text('More actions'), findsOneWidget);
      },
    );

    testWidgets('card detail exposes archive action in the top bar', (
      tester,
    ) async {
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'archive-me',
          name: 'Club badge',
          category: CardCategory.access,
          createdAt: DateTime(2026, 6, 4),
          updatedAt: DateTime(2026, 6, 4),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService();

      await tester.pumpWidget(
        wrapForTest(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => CardDetailScreen(
                repository: repository,
                appLockService: appLockService,
                categoryService: categoryService,
                cardId: 'archive-me',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Archive card'), findsOneWidget);
      expect(find.text('Archive card'), findsNothing);

      await tester.tap(find.byTooltip('Archive card'));
      await tester.pumpAndSettle();

      expect(repository.findById('archive-me')!.archived, isTrue);
    });
  });
}
