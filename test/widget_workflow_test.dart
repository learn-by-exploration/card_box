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
import 'package:card_box/screens/home_screen.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/media_recovery_service.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('HomeScreen', () {
    testWidgets('search, status filter, and category filter work together', (
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
      final mediaRecoveryService = MediaRecoveryService(preferences: prefs);

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
            mediaRecoveryService: mediaRecoveryService,
            onRecoveredMediaDiscarded: () async {},
            onRecoveredMediaUsed: () {},
          ),
        ),
      );

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'basketball');
      await tester.pumpAndSettle();
      expect(find.text('Aiko Tanaka'), findsOneWidget);
      expect(find.text('Library card'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ready'));
      await tester.pumpAndSettle();
      expect(find.text('Library card'), findsOneWidget);
      expect(find.text('Aiko Tanaka'), findsNothing);
      expect(find.text('Office badge'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<CardCategory?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library').last);
      await tester.pumpAndSettle();
      expect(find.text('Library card'), findsOneWidget);
      expect(find.text('Aiko Tanaka'), findsNothing);
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

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
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

    testWidgets('recovered media card can be discarded from home', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      final appLockService = await createReadyAppLockService();
      var discarded = false;

      await tester.pumpWidget(
        wrapForTest(
          HomeScreen(
            repository: repository,
            appLockService: appLockService,
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

      await tester.pumpWidget(
        wrapForTest(
          AppRoot(
            repository: repository,
            appLockService: appLockService,
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
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == const Color(0xFF0F1713),
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

      await tester.pumpWidget(
        wrapForTest(
          CardDetailScreen(
            repository: repository,
            appLockService: appLockService,
            cardId: 'visit-card',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy contact'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Export vCard'), findsOneWidget);
      expect(find.textContaining('NFC/RFID'), findsNothing);
    });
  });
}
