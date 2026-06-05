class CardMediaException implements Exception {
  const CardMediaException(this.message);

  final String message;

  @override
  String toString() => message;
}
