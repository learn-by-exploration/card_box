enum CardType {
  standard('Standard'),
  visitingCard('Visiting card');

  const CardType(this.label);

  final String label;

  static CardType fromName(String value) {
    return CardType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => CardType.standard,
    );
  }
}
