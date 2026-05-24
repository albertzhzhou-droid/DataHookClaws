class AiSuggestionLogEntry {
  const AiSuggestionLogEntry({
    required this.id,
    required this.query,
    required this.suggestionType,
    required this.inputPayload,
    required this.outputPayload,
    required this.modelName,
    required this.createdAt,
  });

  final String id;
  final String query;
  final String suggestionType;
  final String inputPayload;
  final String outputPayload;
  final String modelName;
  final DateTime createdAt;
}
