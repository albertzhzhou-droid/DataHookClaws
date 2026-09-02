import 'dart:async';
import 'dart:convert';
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
import 'package:data_hook_claws/src/models/app_settings.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

  test(
    'settings load falls back when app_meta reads are unavailable',
    () async {
      final repository = _FailingSettingsRepository()..failReads = true;
      final registry = SourceCapabilityRegistry(
        importerDescriptors: importerDescriptors,
        entities: nationalFoodEntities,
      );
      final service = SettingsService(
        repository: repository,
        sourceCapabilities: registry,
      );

      final loaded = await service.load();

      expect(loaded.ollamaEndpoint, 'http://127.0.0.1:11434');
      expect(repository.readAttempts, 1);
      expect(repository.writeAttempts, 0);
    },
  );

  test(
    'settings load does not fail when malformed repair cannot persist',
    () async {
      final repository = _FailingSettingsRepository();
      await repository.setAppMeta(SettingsService.settingsKey, '{malformed');
      repository.failWrites = true;
      final registry = SourceCapabilityRegistry(
        importerDescriptors: importerDescriptors,
        entities: nationalFoodEntities,
      );
      final service = SettingsService(
        repository: repository,
        sourceCapabilities: registry,
      );

      final loaded = await service.load();

      expect(loaded.ollamaModel, 'llama3');
      expect(repository.readAttempts, 1);
      expect(repository.writeAttempts, 2);
    },
  );

  test(
    'effective export directory falls back when storage paths are unavailable',
    () async {
      final repository = _FailingSettingsRepository()..failStoragePaths = true;
      final registry = SourceCapabilityRegistry(
        importerDescriptors: importerDescriptors,
        entities: nationalFoodEntities,
      );
      final service = SettingsService(
        repository: repository,
        sourceCapabilities: registry,
      );

      final resolved = await service.effectiveExportDirectory(
        service.defaultSettings(),
      );

      expect(resolved, p.join(Directory.current.path, 'exports'));
      expect(repository.storagePathAttempts, 1);
    },
  );

  test(
    'settings normalize unsafe numeric values at read and write boundaries',
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

      await repository.setAppMeta(
        SettingsService.settingsKey,
        jsonEncode({
          'modelMaxCallsPerMinute': -1,
          'modelTimeoutSeconds': 0,
          'modelMaxTokens': -20,
          'databaseBudgetBytes': -1,
          'artifactBudgetBytes': 0,
          'exportBudgetBytes': -5,
          'cacheBudgetBytes': -10,
        }),
      );
      final loaded = await service.load();

      expect(loaded.modelMaxCallsPerMinute, 6);
      expect(loaded.modelTimeoutSeconds, 3);
      expect(loaded.modelMaxTokens, 256);
      expect(loaded.databaseBudgetBytes, 512 * 1024 * 1024);
      expect(loaded.artifactBudgetBytes, 2 * 1024 * 1024 * 1024);
      expect(loaded.exportBudgetBytes, 1024 * 1024 * 1024);
      expect(loaded.cacheBudgetBytes, 512 * 1024 * 1024);

      final saved = await service.save(
        const AppSettings(
          modelMaxCallsPerMinute: 0,
          modelTimeoutSeconds: -1,
          modelMaxTokens: 0,
          databaseBudgetBytes: -1,
          artifactBudgetBytes: -1,
          exportBudgetBytes: -1,
          cacheBudgetBytes: -1,
        ),
      );
      expect(saved.modelMaxCallsPerMinute, 0);
      expect(saved.modelTimeoutSeconds, 3);
      expect(saved.modelMaxTokens, 256);
      expect(saved.databaseBudgetBytes, 512 * 1024 * 1024);
      expect(saved.artifactBudgetBytes, 2 * 1024 * 1024 * 1024);
      expect(saved.exportBudgetBytes, 1024 * 1024 * 1024);
      expect(saved.cacheBudgetBytes, 512 * 1024 * 1024);
      final persisted =
          jsonDecode(
                (await repository.getAppMeta(SettingsService.settingsKey))!,
              )
              as Map<String, dynamic>;
      expect(persisted['modelMaxCallsPerMinute'], 0);
      expect(persisted['modelTimeoutSeconds'], 3);
      expect(persisted['modelMaxTokens'], 256);
      expect(persisted['databaseBudgetBytes'], 512 * 1024 * 1024);
      expect(persisted['artifactBudgetBytes'], 2 * 1024 * 1024 * 1024);
      expect(persisted['exportBudgetBytes'], 1024 * 1024 * 1024);
      expect(persisted['cacheBudgetBytes'], 512 * 1024 * 1024);
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

  test(
    'AI assist returns model output when suggestion logging fails',
    () async {
      final service = SourceRoutingSuggestionService(
        persistSuggestion: (_) async {
          throw StateError('suggestion log unavailable');
        },
        ollamaClient: _FakeOllamaClient(
          response: '{"orderedImporterIds":["canada-cnf"]}',
        ),
      );

      final route = await service.suggestOrder(
        query: 'salmon',
        candidateImporterIds: const ['usda', 'canada-cnf'],
      );

      expect(route, ['canada-cnf', 'usda']);
    },
  );

  test(
    'AI assist keeps deterministic fallback when failure logging fails',
    () async {
      final service = SourceRoutingSuggestionService(
        persistSuggestion: (_) async {
          throw StateError('suggestion log unavailable');
        },
        ollamaClient: _FakeOllamaClient(error: TimeoutException('timeout')),
      );

      final route = await service.suggestOrder(
        query: 'salmon',
        candidateImporterIds: const ['usda', 'canada-cnf'],
      );

      expect(route, ['usda', 'canada-cnf']);
    },
  );

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

class _FailingSettingsRepository extends MemoryFoodRepository {
  bool failReads = false;
  bool failWrites = false;
  bool failStoragePaths = false;
  int readAttempts = 0;
  int writeAttempts = 0;
  int storagePathAttempts = 0;

  @override
  Future<String?> getAppMeta(String key) async {
    readAttempts += 1;
    if (failReads) {
      throw StateError('settings read failed');
    }
    return super.getAppMeta(key);
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    writeAttempts += 1;
    if (failWrites) {
      throw StateError('settings write failed');
    }
    return super.setAppMeta(key, value);
  }

  @override
  Future<StoragePaths> getStoragePaths() async {
    storagePathAttempts += 1;
    if (failStoragePaths) {
      throw StateError('storage paths unavailable');
    }
    return super.getStoragePaths();
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
