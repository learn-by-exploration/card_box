enum CardCategory {
  loyalty('Loyalty'),
  membership('Membership'),
  access('Access'),
  transit('Transit'),
  gift('Gift'),
  id('ID'),
  library('Library'),
  contact('Contact'),
  other('Other');

  const CardCategory(this.label);

  final String label;

  static CardCategory fromName(String value) {
    return CardCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => CardCategory.other,
    );
  }
}
