enum ExportFormat { json, csv, sqliteSnapshot }

enum ExportDetailLevel { summary, detailed }

class ExportArtifact {
  const ExportArtifact({
    required this.path,
    required this.format,
    required this.detailLevel,
    required this.recordCount,
    required this.createdAt,
    required this.scopeLabel,
    required this.mimeType,
  });

  final String path;
  final ExportFormat format;
  final ExportDetailLevel detailLevel;
  final int recordCount;
  final DateTime createdAt;
  final String scopeLabel;
  final String mimeType;
}
