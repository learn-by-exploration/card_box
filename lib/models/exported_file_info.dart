class ExportedFileInfo {
  const ExportedFileInfo({
    required this.path,
    required this.fileName,
    required this.createdAt,
  });

  final String path;
  final String fileName;
  final DateTime createdAt;
}
