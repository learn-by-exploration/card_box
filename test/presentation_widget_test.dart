import 'package:barcode_widget/barcode_widget.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/services/card_repository.dart';
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
      expect(find.text('Tap for code'), findsOneWidget);

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
      expect(find.text('Contact'), findsOneWidget);
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
}
