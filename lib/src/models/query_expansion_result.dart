import 'dart:convert';

class QueryExpansionResult {
  const QueryExpansionResult({
    required this.primaryQuery,
    required this.aliases,
    required this.translations,
    required this.sourceHints,
    required this.usedModel,
  });

  final String primaryQuery;
  final List<String> aliases;
  final List<String> translations;
  final List<String> sourceHints;
  final bool usedModel;

  List<String> get allQueries => [
    primaryQuery,
    ...aliases,
    ...translations,
  ].where((value) => value.trim().isNotEmpty).toSet().toList(growable: false);

  String toJsonString() {
    return jsonEncode({
      'primaryQuery': primaryQuery,
      'aliases': aliases,
      'translations': translations,
      'sourceHints': sourceHints,
      'usedModel': usedModel,
    });
  }
}
