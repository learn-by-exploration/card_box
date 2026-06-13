import 'wallet_card.dart';

/// How the home screen orders the visible card list. Persisted across
/// launches via shared preferences; the storage is the caller's
/// responsibility so this enum stays free of plugin dependencies.
enum CardBoxSort {
  nameAtoZ('Name (A to Z)'),
  nameZtoA('Name (Z to A)'),
  recentlyUpdated('Recently updated'),
  recentlyAdded('Recently added');

  const CardBoxSort(this.label);

  final String label;

  static const String preferenceKey = 'card_box.home_sort.v1';
  static const CardBoxSort fallback = CardBoxSort.nameAtoZ;

  static CardBoxSort fromPreferenceValue(String? value) {
    if (value == null) return fallback;
    final index = int.tryParse(value);
    if (index == null) return fallback;
    if (index < 0 || index >= CardBoxSort.values.length) return fallback;
    return CardBoxSort.values[index];
  }

  String get preferenceValue => index.toString();
}

/// Pure sort: returns a new list sorted according to [sort]. The
/// caller is responsible for filtering; this function does not look at
/// favorites or browse mode — it only orders.
List<WalletCard> applyCardSort(
  List<WalletCard> cards,
  CardBoxSort sort,
) {
  final copy = List<WalletCard>.of(cards);
  switch (sort) {
    case CardBoxSort.nameAtoZ:
      copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case CardBoxSort.nameZtoA:
      copy.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case CardBoxSort.recentlyUpdated:
      copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case CardBoxSort.recentlyAdded:
      copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return copy;
}
