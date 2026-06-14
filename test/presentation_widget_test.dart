import 'package:barcode_widget/barcode_widget.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/archived_cards_screen.dart';
import 'package:card_box/screens/barcode_present_screen.dart';
import 'package:card_box/screens/barcode_scan_screen.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/screens/card_image_viewer_screen.dart';
import 'package:card_box/screens/card_reference_present_screen.dart';
import 'package:card_box/screens/contact_qr_screen.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/widgets/announceable_barcode.dart';
import 'package:card_box/widgets/barcode_preview.dart';
import 'package:card_box/widgets/card_tile.dart';
import 'package:card_box/widgets/stored_card_image.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CardTile', () {
    testWidgets('list layout shows status and fires quick actions', (
      tester,
    ) async {
      var tapped = 0;
      var showCode = 0;
      var showImages = 0;
      final card = WalletCard(
        id: 'barcode-card',
        name: 'Library card',
        issuer: 'City Library',
        category: CardCategory.library,
        barcodePayload: 'LIB-123',
        barcodeFormat: 'code128',
        compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
        favorite: true,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(
        wrapForTest(
          CardTile(
            card: card,
            onTap: () => tapped += 1,
            onShowCode: () => showCode += 1,
            onShowImages: () => showImages += 1,
          ),
        ),
      );

      expect(find.text('Library card'), findsOneWidget);
      expect(find.text('Ready to show'), findsOneWidget);
      expect(find.text('More options'), findsOneWidget);

      await tester.tap(find.byTooltip('Show code'));
      await tester.tap(find.byTooltip('Show saved images'));
      await tester.tap(find.text('Library card'));
      await tester.pumpAndSettle();

      expect(showCode, 1);
      expect(showImages, 1);
      expect(tapped, 1);
    });

    testWidgets('grid layout uses compact visiting-card hints', (tester) async {
      final card = WalletCard(
        id: 'contact-card',
        name: 'Aiko Tanaka',
        issuer: 'CourtSide Japan',
        category: CardCategory.contact,
        cardType: CardType.visitingCard,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(
        wrapForTest(
          SizedBox(
            width: 220,
            height: 260,
            child: CardTile(
              card: card,
              layout: CardTileLayout.grid,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Contact saved'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.byIcon(Icons.contact_page_outlined), findsOneWidget);
    });
  });

  group('BarcodePreview', () {
    testWidgets('renders nothing for an empty payload', (tester) async {
      await tester.pumpWidget(
        wrapForTest(const BarcodePreview(data: '', format: 'qr')),
      );

      expect(find.byType(BarcodeWidget), findsNothing);
    });

    testWidgets('shows a readable fallback when the code cannot render', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          const SizedBox(
            width: 300,
            child: BarcodePreview(data: 'abc', format: 'ean13'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Unable to render this code yet.'),
        findsOneWidget,
      );
      expect(find.textContaining('abc'), findsOneWidget);
    });
  });

  group('StoredCardImage', () {
    testWidgets('shows the empty label when no image path exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          const SizedBox(
            width: 200,
            height: 120,
            child: StoredCardImage(path: '', emptyLabel: 'Front photo'),
          ),
        ),
      );

      expect(find.text('Front photo'), findsOneWidget);
    });
  });

  group('CardDetailScreen', () {
    testWidgets(
      'visiting cards with visible codes keep contact actions primary',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = CardRepository(database: createInMemoryDatabase());
        await repository.init();
        final card = WalletCard(
          id: 'mixed-contact',
          name: 'Aiko Tanaka',
          issuer: 'CourtSide Japan',
          category: CardCategory.contact,
          cardType: CardType.visitingCard,
          frontImagePath: '/tmp/front.jpg',
          backImagePath: '/tmp/back.jpg',
          barcodePayload: 'https://courtside.jp/aiko',
          barcodeFormat: 'qr',
          barcodeImagePath: '/tmp/code.png',
          nfcTagSummary: 'Detected on Android device.',
          contactTitle: 'Community Manager',
          compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        );
        await repository.upsert(card);
        final appLockService = await createReadyAppLockService();
        final categoryService = await createReadyCategoryService(
          preferences: prefs,
        );

        await tester.pumpWidget(
          wrapForTest(
            CardDetailScreen(
              repository: repository,
              appLockService: appLockService,
              categoryService: categoryService,
              cardId: card.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Show contact QR'), findsOneWidget);
        expect(find.text('Share contact'), findsOneWidget);
        expect(find.text('Present code'), findsNothing);
        await tester.fling(
          find.byType(ListView).first,
          const Offset(0, -1200),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('front/back photos'), findsWidgets);
        expect(find.textContaining('visible code'), findsWidgets);
        expect(find.textContaining('code image'), findsWidgets);
        expect(find.textContaining('NFC/RFID notes'), findsWidgets);
      },
    );

    testWidgets(
      'standard barcode cards prioritize code presentation and sharing',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = CardRepository(database: createInMemoryDatabase());
        await repository.init();
        final card = WalletCard(
          id: 'loyalty-card',
          name: 'Gym pass',
          issuer: 'Anytime Fitness',
          category: CardCategory.membership,
          barcodePayload: 'GYM-42',
          barcodeFormat: 'qr',
          frontImagePath: '/tmp/front.jpg',
          compatibilityStatus: CompatibilityStatus.barcodeDisplayable,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        );
        await repository.upsert(card);
        final appLockService = await createReadyAppLockService();
        final categoryService = await createReadyCategoryService(
          preferences: prefs,
        );

        await tester.pumpWidget(
          wrapForTest(
            CardDetailScreen(
              repository: repository,
              appLockService: appLockService,
              categoryService: categoryService,
              cardId: card.id,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Present code'), findsOneWidget);
        expect(find.text('Share card'), findsOneWidget);
        expect(find.text('Show card'), findsNothing);
        await tester.fling(
          find.byType(ListView).first,
          const Offset(0, -1200),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('front/back photos'), findsWidgets);
        expect(find.textContaining('visible code'), findsWidgets);
      },
    );
  });

  group('Presentation screens', () {
    testWidgets('BarcodePresentScreen shows the code payload and preview', (
      tester,
    ) async {
      final card = WalletCard(
        id: 'gym-pass',
        name: 'Gym pass',
        issuer: 'Anytime Fitness',
        category: CardCategory.membership,
        barcodePayload: 'GYM-42',
        barcodeFormat: 'qr',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(wrapForTest(BarcodePresentScreen(card: card)));

      expect(find.text('Gym pass'), findsWidgets);
      expect(find.text('Anytime Fitness'), findsOneWidget);
      expect(find.text('GYM-42'), findsOneWidget);
      expect(find.text('qr'), findsOneWidget);
      expect(find.byType(AnnounceableBarcode), findsOneWidget);
    });

    testWidgets('ContactQrScreen shows the QR presentation copy', (
      tester,
    ) async {
      final card = WalletCard(
        id: 'contact',
        name: 'Aiko Tanaka',
        issuer: 'CourtSide Japan',
        category: CardCategory.contact,
        cardType: CardType.visitingCard,
        contactEmails: const <String>['aiko@example.jp'],
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(wrapForTest(ContactQrScreen(card: card)));

      expect(find.text('Scan to save contact'), findsOneWidget);
      expect(find.text('CourtSide Japan'), findsOneWidget);
      // ContactQrScreen renders a contact-card QR (no read-aloud value —
      // the on-screen text is what the recipient scans), so it still uses
      // the plain BarcodePreview rather than the a11y wrapper.
      expect(find.byType(BarcodePreview), findsOneWidget);
      expect(find.textContaining('compact contact card'), findsOneWidget);
    });

    testWidgets('CardReferencePresentScreen shows front and back tabs', (
      tester,
    ) async {
      final card = WalletCard(
        id: 'ref-card',
        name: 'Office badge',
        category: CardCategory.access,
        frontImagePath: '/tmp/front.jpg',
        backImagePath: '/tmp/back.jpg',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      await tester.pumpWidget(
        wrapForTest(CardReferencePresentScreen(card: card)),
      );

      expect(find.widgetWithText(TextButton, 'Front'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Back'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Back'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final selectedBackButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Back'),
      );
      expect(selectedBackButton.style, isNotNull);
    });

    testWidgets('CardImageViewerScreen rotates and can reset rotation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapForTest(
          const CardImageViewerScreen(
            imagePath: '/tmp/missing.jpg',
            title: 'Front photo',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resetButtonFinder = find.byType(IconButton).at(2);
      final resetBefore = tester.widget<IconButton>(resetButtonFinder);
      expect(resetBefore.onPressed, isNull);

      await tester.tap(find.byTooltip('Rotate right'));
      await tester.pumpAndSettle();

      final resetAfter = tester.widget<IconButton>(resetButtonFinder);
      expect(resetAfter.onPressed, isNotNull);

      await tester.tap(find.byTooltip('Reset rotation'));
      await tester.pumpAndSettle();

      final resetFinal = tester.widget<IconButton>(resetButtonFinder);
      expect(resetFinal.onPressed, isNull);
    });
  });

  group('BarcodeScanScreen', () {
    testWidgets('starts on the consent panel and lets you choose a mode', (
      tester,
    ) async {
      await tester.pumpWidget(wrapForTest(const BarcodeScanScreen()));

      expect(find.text('Camera permission'), findsOneWidget);
      expect(find.text('Start scanner'), findsOneWidget);
      expect(find.text('Barcode'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.byType(AnnounceableBarcode), findsNothing);

      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();

      final qrChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'QR'),
      );
      final barcodeChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Barcode'),
      );
      expect(qrChip.selected, isTrue);
      expect(barcodeChip.selected, isFalse);
    });
  });

  group('ArchivedCardsScreen', () {
    testWidgets('shows the empty state when there are no archived cards', (
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

      await tester.pumpWidget(
        wrapForTest(
          ArchivedCardsScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
          ),
        ),
      );

      expect(
        find.text(
          'Archived cards will appear here so they can be restored or deleted later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('restore action unarchives the card', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'archived-card',
          name: 'Old badge',
          category: CardCategory.access,
          archived: true,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );

      await tester.pumpWidget(
        wrapForTest(
          ArchivedCardsScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Old badge'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(repository.archivedCards, isEmpty);
      expect(repository.cards.map((card) => card.name), contains('Old badge'));
      expect(
        find.text(
          'Archived cards will appear here so they can be restored or deleted later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('delete action permanently removes the archived card', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'archived-card',
          name: 'Expired pass',
          category: CardCategory.membership,
          archived: true,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );

      await tester.pumpWidget(
        wrapForTest(
          ArchivedCardsScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete permanently?'), findsOneWidget);

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(repository.findById('archived-card'), isNull);
      expect(repository.archivedCards, isEmpty);
    });

    testWidgets('tapping the archived row opens card details', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = CardRepository(database: createInMemoryDatabase());
      await repository.init();
      await repository.upsert(
        WalletCard(
          id: 'archived-card',
          name: 'Visitor badge',
          issuer: 'Main Office',
          category: CardCategory.access,
          archived: true,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 1),
        ),
      );
      final appLockService = await createReadyAppLockService();
      final categoryService = await createReadyCategoryService(
        preferences: prefs,
      );

      await tester.pumpWidget(
        wrapForTest(
          ArchivedCardsScreen(
            repository: repository,
            appLockService: appLockService,
            categoryService: categoryService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Visitor badge'));
      await tester.pumpAndSettle();

      expect(find.text('What you can do now'), findsOneWidget);
      expect(find.text('Visitor badge'), findsWidgets);
      expect(find.text('Main Office'), findsOneWidget);
    });
  });
}
