class FetchJobEntry {
  const FetchJobEntry({
    required this.id,
    required this.query,
    required this.phase,
    required this.status,
    required this.importerId,
    required this.startedAt,
    required this.finishedAt,
    required this.message,
  });

  final String id;
  final String query;
  final String phase;
  final String status;
  final String importerId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String message;

  FetchJobEntry copyWith({
    String? status,
    DateTime? finishedAt,
    String? message,
  }) {
    return FetchJobEntry(
      id: id,
      query: query,
      phase: phase,
      status: status ?? this.status,
      importerId: importerId,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      message: message ?? this.message,
    );
  }
}
