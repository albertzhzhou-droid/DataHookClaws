class ImportLogEntry {
  const ImportLogEntry({
    required this.id,
    required this.importerId,
    required this.sourceName,
    required this.status,
    required this.importedCount,
    required this.query,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String importerId;
  final String sourceName;
  final String status;
  final int importedCount;
  final String query;
  final String message;
  final DateTime createdAt;
}
