import 'dart:convert';

import '../models/ai_suggestion_log_entry.dart';
import '../models/merge_review_issue.dart';
import 'model_budget_controller.dart';
import 'ollama_client.dart';

typedef AiSuggestionPersistor =
    Future<void> Function(AiSuggestionLogEntry entry);

abstract class AiAssistServiceBase {
  AiAssistServiceBase({
    required AiSuggestionPersistor persistSuggestion,
    OllamaClient? ollamaClient,
    ModelBudgetController? modelBudgetController,
    DateTime Function()? clock,
  }) : _persistSuggestion = persistSuggestion,
       _ollamaClient = ollamaClient ?? OllamaClient(),
       _modelBudgetController =
           modelBudgetController ?? ModelBudgetController(),
       _clock = clock ?? DateTime.now;

  final AiSuggestionPersistor _persistSuggestion;
  final OllamaClient _ollamaClient;
  final ModelBudgetController _modelBudgetController;
  final DateTime Function() _clock;

  String get modelName => _ollamaClient.model;

  Future<String?> runSuggestion({
    required String query,
    required String suggestionType,
    required Map<String, Object?> inputPayload,
    required String prompt,
  }) async {
    final decision = _modelBudgetController.evaluate(query);
    if (!decision.allowed) {
      await persistFallback(
        query: query,
        suggestionType: suggestionType,
        inputPayload: inputPayload,
        reason: decision.reason,
      );
      return null;
    }

    try {
      _modelBudgetController.recordCall();
      final response = await _ollamaClient.generateJson(prompt: prompt);
      await persist(
        query: query,
        suggestionType: suggestionType,
        inputPayload: inputPayload,
        outputPayload: response,
      );
      return response;
    } catch (_) {
      _modelBudgetController.recordFailure();
      await persistFallback(
        query: query,
        suggestionType: suggestionType,
        inputPayload: inputPayload,
        reason: 'Ollama request failed.',
      );
      return null;
    }
  }

  Future<void> persist({
    required String query,
    required String suggestionType,
    required Map<String, Object?> inputPayload,
    required String outputPayload,
  }) async {
    await _persistSuggestion(
      AiSuggestionLogEntry(
        id: 'ai-${_clock().microsecondsSinceEpoch}',
        query: query,
        suggestionType: suggestionType,
        inputPayload: jsonEncode(inputPayload),
        outputPayload: outputPayload,
        modelName: modelName,
        createdAt: _clock(),
      ),
    );
  }

  Future<void> persistFallback({
    required String query,
    required String suggestionType,
    required Map<String, Object?> inputPayload,
    required String reason,
  }) async {
    await persist(
      query: query,
      suggestionType: '$suggestionType-fallback',
      inputPayload: {...inputPayload, 'fallbackReason': reason},
      outputPayload: jsonEncode({'fallback': true, 'reason': reason}),
    );
  }
}

class SourceRoutingSuggestionService extends AiAssistServiceBase {
  SourceRoutingSuggestionService({
    required super.persistSuggestion,
    super.ollamaClient,
    super.modelBudgetController,
    super.clock,
  });

  Future<List<String>> suggestOrder({
    required String query,
    required List<String> candidateImporterIds,
  }) async {
    final response = await runSuggestion(
      query: query,
      suggestionType: 'source-routing-suggestion',
      inputPayload: {
        'query': query,
        'candidateImporterIds': candidateImporterIds,
      },
      prompt:
          'Return JSON only: {"orderedImporterIds":[...]} using only these ids: '
          '${candidateImporterIds.join(', ')}. Rank likely official food source usefulness for "$query". '
          'Do not include nutrition facts.',
    );
    if (response == null) {
      return candidateImporterIds;
    }
    try {
      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final ordered = (parsed['orderedImporterIds'] as List? ?? const [])
          .map((item) => item.toString())
          .where(candidateImporterIds.contains)
          .toList(growable: false);
      return [
        ...ordered,
        ...candidateImporterIds.where((id) => !ordered.contains(id)),
      ];
    } catch (_) {
      return candidateImporterIds;
    }
  }
}

class MergeCandidateExplanationService extends AiAssistServiceBase {
  MergeCandidateExplanationService({
    required super.persistSuggestion,
    super.ollamaClient,
    super.modelBudgetController,
    super.clock,
  });

  Future<String> explain(MergeReviewIssue issue) async {
    final fallback = issue.reason;
    final response = await runSuggestion(
      query: issue.canonicalFoodId,
      suggestionType: 'merge-candidate-explanation',
      inputPayload: {
        'canonicalFoodId': issue.canonicalFoodId,
        'sourceRecordId': issue.sourceRecordId,
        'type': issue.type.name,
        'severity': issue.severity.name,
        'reason': issue.reason,
        'candidateSummary': issue.candidateSummary,
      },
      prompt:
          'Return JSON only: {"explanation":"..."} explaining this deterministic merge review issue for a user. '
          'Do not recommend an automatic merge/split and do not invent nutrition facts. Issue: ${issue.reason}. '
          'Candidates: ${issue.candidateSummary}',
    );
    if (response == null) {
      return fallback;
    }
    try {
      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final explanation = parsed['explanation']?.toString().trim();
      return explanation == null || explanation.isEmpty
          ? fallback
          : explanation;
    } catch (_) {
      return fallback;
    }
  }
}

class ExportSummaryService extends AiAssistServiceBase {
  ExportSummaryService({
    required super.persistSuggestion,
    super.ollamaClient,
    super.modelBudgetController,
    super.clock,
  });

  Future<String> summarize({
    required String scopeLabel,
    required String format,
    required String detailLevel,
    required int recordCount,
  }) async {
    final fallback =
        'AI-generated summary unavailable. Export scope $scopeLabel contains $recordCount records.';
    final response = await runSuggestion(
      query: scopeLabel,
      suggestionType: 'export-summary',
      inputPayload: {
        'scopeLabel': scopeLabel,
        'format': format,
        'detailLevel': detailLevel,
        'recordCount': recordCount,
      },
      prompt:
          'Return JSON only: {"summary":"AI-generated summary: ..."} for an export artifact. '
          'Summarize scope, format, detail level, and record count only. Do not create nutrition facts. '
          'scope=$scopeLabel format=$format detail=$detailLevel records=$recordCount',
    );
    if (response == null) {
      return fallback;
    }
    try {
      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final summary = parsed['summary']?.toString().trim();
      if (summary == null || summary.isEmpty) {
        return fallback;
      }
      return summary.startsWith('AI-generated summary:')
          ? summary
          : 'AI-generated summary: $summary';
    } catch (_) {
      return fallback;
    }
  }
}
