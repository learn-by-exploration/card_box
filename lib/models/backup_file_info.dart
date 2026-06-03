class BackupFileInfo {
  const BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.cardCount,
  });

  final String path;
  final String fileName;
  final DateTime createdAt;
  final int cardCount;
}
