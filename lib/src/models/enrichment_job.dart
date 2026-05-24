class EnrichmentJob {
  const EnrichmentJob({
    required this.id,
    required this.query,
    required this.normalizedQuery,
    required this.remainingImporterIds,
    required this.status,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    required this.message,
  });

  final String id;
  final String query;
  final String normalizedQuery;
  final List<String> remainingImporterIds;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? message;

  EnrichmentJob copyWith({
    List<String>? remainingImporterIds,
    String? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? message,
  }) {
    return EnrichmentJob(
      id: id,
      query: query,
      normalizedQuery: normalizedQuery,
      remainingImporterIds: remainingImporterIds ?? this.remainingImporterIds,
      status: status ?? this.status,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      message: message ?? this.message,
    );
  }
}
