import 'package:card_box/models/card_box_sort.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:flutter_test/flutter_test.dart';

WalletCard _card({
  required String id,
  required String name,
  bool favorite = false,
  bool hasBarcode = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2024, 1, 1);
  return WalletCard(
    id: id,
    name: name,
    category: CardCategory.loyalty,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    favorite: favorite,
    barcodePayload: hasBarcode ? 'BC-$id' : '',
  );
}

void main() {
  group('CardBoxSort', () {
    final cards = <WalletCard>[
      _card(id: 'a', name: 'Banana', hasBarcode: true),
      _card(id: 'b', name: 'apple', updatedAt: DateTime(2024, 2, 1)),
      _card(
        id: 'c',
        name: 'Cherry',
        favorite: true,
        createdAt: DateTime(2024, 3, 1),
      ),
    ];

    test('nameAtoZ sorts case-insensitively', () {
      final sorted = applyCardSort(cards, CardBoxSort.nameAtoZ);
      expect(sorted.map((c) => c.id).toList(), ['b', 'a', 'c']);
    });

    test('nameZtoA is the reverse of nameAtoZ', () {
      final sorted = applyCardSort(cards, CardBoxSort.nameZtoA);
      expect(sorted.map((c) => c.id).toList(), ['c', 'a', 'b']);
    });

    test('recentlyUpdated puts most-recently-updated first', () {
      final sorted = applyCardSort(cards, CardBoxSort.recentlyUpdated);
      expect(sorted.first.id, 'b', reason: 'card b has the latest updatedAt');
    });

    test('recentlyAdded puts most-recently-created first', () {
      final sorted = applyCardSort(cards, CardBoxSort.recentlyAdded);
      expect(sorted.first.id, 'c', reason: 'card c has the latest createdAt');
    });
  });
}
