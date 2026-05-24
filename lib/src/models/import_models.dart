class ImportRequest {
  const ImportRequest({
    required this.query,
    required this.limit,
    this.apiKey,
    this.datasetPath,
  });

  final String query;
  final int limit;
  final String? apiKey;
  final String? datasetPath;

  ImportRequest copyWith({
    String? query,
    int? limit,
    String? apiKey,
    String? datasetPath,
  }) {
    return ImportRequest(
      query: query ?? this.query,
      limit: limit ?? this.limit,
      apiKey: apiKey ?? this.apiKey,
      datasetPath: datasetPath ?? this.datasetPath,
    );
  }
}

class ImportResult {
  const ImportResult({
    required this.importerId,
    required this.importedCount,
    required this.message,
  });

  final String importerId;
  final int importedCount;
  final String message;
}
