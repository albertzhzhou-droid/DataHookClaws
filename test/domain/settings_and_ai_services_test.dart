import 'dart:async';
import 'dart:io';

import 'package:data_hook_claws/src/api/export_models.dart';
import 'package:data_hook_claws/src/api/food_catalog_export_service.dart';
import 'package:data_hook_claws/src/data/importer_registry.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:data_hook_claws/src/domain/ai_assist_services.dart';
import 'package:data_hook_claws/src/domain/model_budget_controller.dart';
import 'package:data_hook_claws/src/domain/ollama_client.dart';
import 'package:data_hook_claws/src/domain/settings_service.dart';
import 'package:data_hook_claws/src/domain/source_capability_registry.dart';
import 'package:data_hook_claws/src/domain/source_routing_service.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settings persist through app_meta and sanitize blocked sources',
    () async {
      final repository = MemoryFoodRepository();
      final registry = SourceCapabilityRegistry(
        importerDescriptors: importerDescriptors,
        entities: nationalFoodEntities,
      );
      final service = SettingsService(
        repository: repository,
        sourceCapabilities: registry,
      );

      await service.save(
        service.defaultSettings().copyWith(
          ollamaEndpoint: 'http://localhost:11435',
          modelMaxCallsPerMinute: 3,
          sourceEnabled: {'usda': false, 'nz-foodfiles': true},
        ),
      );

      final loaded = await service.load();
      expect(loaded.ollamaEndpoint, 'http://localhost:11435');
      expect(loaded.modelMaxCallsPerMinute, 3);
      expect(loaded.sourceEnabled['usda'], isFalse);
      expect(loaded.sourceEnabled['nz-foodfiles'], isFalse);
    },
  );

  test('disabled and blocked sources do not route automatically', () {
    final registry = SourceCapabilityRegistry(
      importerDescriptors: importerDescriptors,
      entities: nationalFoodEntities,
    );
    final routing = SourceRoutingService(
      registry: registry,
      disabledSourceIds: const {'usda'},
    );

    final routed = routing.route(
      defaultOrder: const ['usda', 'canada-cnf', 'nz-foodfiles'],
      sourceHints: const ['usda', 'nz-foodfiles', 'canada-cnf'],
      recentFailures: const [],
      maxImporters: 3,
    );

    expect(routed, ['canada-cnf']);
  });

  test('AI assist services log suggestions and fall back safely', () async {
    final repository = MemoryFoodRepository();
    final budget = ModelBudgetController(maxCallsPerMinute: 6);
    final routingService = SourceRoutingSuggestionService(
      persistSuggestion: repository.addAiSuggestionLog,
      ollamaClient: _FakeOllamaClient(
        response: '{"orderedImporterIds":["canada-cnf","usda"]}',
      ),
      modelBudgetController: budget,
    );
    final mergeService = MergeCandidateExplanationService(
      persistSuggestion: repository.addAiSuggestionLog,
      ollamaClient: _FakeOllamaClient(
        response:
            '{"explanation":"The deterministic review found a category mismatch."}',
      ),
      modelBudgetController: budget,
    );

    final route = await routingService.suggestOrder(
      query: 'salmon',
      candidateImporterIds: const ['usda', 'canada-cnf'],
    );
    final explanation = await mergeService.explain(
      MergeReviewIssue(
        id: 'issue-1',
        canonicalFoodId: 'food-1',
        sourceRecordId: 'source-1',
        type: MergeReviewIssueType.categoryConflictCandidate,
        severity: MergeReviewSeverity.warning,
        reason: 'Category mismatch.',
        candidateSummary: 'candidate food-2 rejected',
        createdAt: DateTime(2026),
      ),
    );

    final logs = await repository.getAiSuggestionLogs(limit: 10);
    expect(route.first, 'canada-cnf');
    expect(explanation, contains('category mismatch'));
    expect(
      logs.map((entry) => entry.suggestionType),
      containsAll(['source-routing-suggestion', 'merge-candidate-explanation']),
    );
  });

  test('AI assist services fallback on timeout and still log', () async {
    final repository = MemoryFoodRepository();
    final service = SourceRoutingSuggestionService(
      persistSuggestion: repository.addAiSuggestionLog,
      ollamaClient: _FakeOllamaClient(error: TimeoutException('timeout')),
      modelBudgetController: ModelBudgetController(),
    );

    final route = await service.suggestOrder(
      query: 'salmon',
      candidateImporterIds: const ['usda', 'canada-cnf'],
    );

    final logs = await repository.getAiSuggestionLogs();
    expect(route, ['usda', 'canada-cnf']);
    expect(logs.single.suggestionType, 'source-routing-suggestion-fallback');
  });

  test('export summary writes AI summary into export history', () async {
    final exportRoot = await Directory.systemTemp.createTemp(
      'export-summary-history',
    );
    addTearDown(() async {
      if (exportRoot.existsSync()) {
        await exportRoot.delete(recursive: true);
      }
    });
    final repository = MemoryFoodRepository(seedItems: [_food()]);
    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => exportRoot,
      exportSummaryService: ExportSummaryService(
        persistSuggestion: repository.addAiSuggestionLog,
        ollamaClient: _FakeOllamaClient(
          response:
              '{"summary":"AI-generated summary: search export with one record."}',
        ),
      ),
    );

    await service.exportSearchResults(
      query: 'salmon',
      format: ExportFormat.json,
      detailLevel: ExportDetailLevel.summary,
    );

    final history = await repository.getExportHistory();
    expect(history, hasLength(1));
    expect(history.single.summary, startsWith('AI-generated summary:'));
  });
}

class _FakeOllamaClient extends OllamaClient {
  _FakeOllamaClient({this.response = '{}', this.error}) : super();

  final String response;
  final Object? error;

  @override
  Future<String> generateJson({required String prompt}) async {
    if (error != null) {
      throw error!;
    }
    return response;
  }
}

FoodItem _food() {
  return FoodItem(
    id: 'canada-cnf:salmon',
    name: 'Atlantic Salmon',
    category: 'Seafood',
    country: 'Canada',
    sourceName: 'CNF',
    description: 'Official salmon record',
    servingBasis: 'Per 100 g',
    tags: const ['official'],
    nutrients: const [],
    lastUpdated: DateTime(2026),
  );
}
