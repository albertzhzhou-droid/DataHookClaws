import '../api/export_models.dart';

class ExportHistoryEntry {
  const ExportHistoryEntry({
    required this.id,
    required this.path,
    required this.format,
    required this.detailLevel,
    required this.recordCount,
    required this.scopeLabel,
    required this.createdAt,
    required this.status,
    required this.summary,
  });

  final String id;
  final String path;
  final ExportFormat format;
  final ExportDetailLevel detailLevel;
  final int recordCount;
  final String scopeLabel;
  final DateTime createdAt;
  final String status;
  final String summary;
}
