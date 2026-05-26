import 'dart:convert';

import '../models/ai_suggestion_log_entry.dart';
import '../models/query_expansion_result.dart';
import 'normalization/text_normalizer.dart';
import 'model_budget_controller.dart';
import 'ollama_client.dart';

class QueryExpansionService {
  QueryExpansionService({
    required this.persistSuggestion,
    OllamaClient? ollamaClient,
    ModelBudgetController? modelBudgetController,
    TextNormalizer? textNormalizer,
  }) : _ollamaClient = ollamaClient ?? OllamaClient(),
       _modelBudgetController =
           modelBudgetController ?? ModelBudgetController(),
       _textNormalizer = textNormalizer ?? const TextNormalizer();

  final Future<void> Function(AiSuggestionLogEntry entry) persistSuggestion;
  final OllamaClient _ollamaClient;
  final ModelBudgetController _modelBudgetController;
  final TextNormalizer _textNormalizer;

  ModelBudgetSnapshot get budgetSnapshot => _modelBudgetController.snapshot();

  Future<QueryExpansionResult> expand(String rawQuery) async {
    final query = _textNormalizer.cleanText(rawQuery);
    if (query.length < 2) {
      return _fallback(query);
    }
    final budgetDecision = _modelBudgetController.evaluate(query);
    if (!budgetDecision.allowed) {
      final fallback = _fallback(query);
      await _persistFallback(query, fallback, budgetDecision.reason);
      return fallback;
    }

    try {
      _modelBudgetController.recordCall();
      final response = await _ollamaClient.generateJson(
        prompt: _buildPrompt(query),
      );
      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final result = QueryExpansionResult(
        primaryQuery: query,
        aliases: _stringList(parsed['aliases']),
        translations: _stringList(parsed['translations']),
        sourceHints: _mapSourceHints(_stringList(parsed['sourceHints'])),
        usedModel: true,
      );

      await persistSuggestion(
        AiSuggestionLogEntry(
          id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
          query: query,
          suggestionType: 'query-expansion',
          inputPayload: jsonEncode({'query': query}),
          outputPayload: result.toJsonString(),
          modelName: _ollamaClient.model,
          createdAt: DateTime.now(),
        ),
      );

      return result;
    } catch (_) {
      _modelBudgetController.recordFailure();
      final fallback = _fallback(query);
      await _persistFallback(query, fallback, 'Ollama request failed.');
      return fallback;
    }
  }

  Future<void> _persistFallback(
    String query,
    QueryExpansionResult fallback,
    String reason,
  ) async {
    await persistSuggestion(
      AiSuggestionLogEntry(
        id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
        query: query,
        suggestionType: 'query-expansion-fallback',
        inputPayload: jsonEncode({'query': query, 'reason': reason}),
        outputPayload: fallback.toJsonString(),
        modelName: _ollamaClient.model,
        createdAt: DateTime.now(),
      ),
    );
  }

  QueryExpansionResult _fallback(String query) {
    final cleaned = _textNormalizer.cleanText(query);
    final normalized = _textNormalizer.aliasKey(cleaned).replaceAll('  ', ' ');
    final aliases = <String>{
      cleaned,
      normalized,
      if (cleaned.contains('-')) cleaned.replaceAll('-', ' '),
    }.where((value) => value.trim().isNotEmpty).toList(growable: false);

    return QueryExpansionResult(
      primaryQuery: cleaned,
      aliases: aliases,
      translations: const [],
      sourceHints: const [],
      usedModel: false,
    );
  }

  String _buildPrompt(String query) {
    return '''
Return only valid JSON with keys aliases, translations, sourceHints.
The query is a food search term. Provide common food aliases and common Chinese, English, or Japanese search variants.
Do not include nutrition facts or prose.
Use sourceHints only from: usda, canada-cnf, uk-mccance, jp-standard.
Query: "$query"
''';
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => _textNormalizer.cleanText(item.toString()))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _mapSourceHints(List<String> hints) {
    const allowed = {'usda', 'canada-cnf', 'uk-mccance', 'jp-standard'};
    return hints.where(allowed.contains).toList(growable: false);
  }
}
