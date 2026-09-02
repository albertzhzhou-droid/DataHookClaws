import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/background_enrichment_queue.dart';
import 'package:data_hook_claws/src/domain/fetch_budget_planner.dart';
import 'package:data_hook_claws/src/domain/foreground_fetch_runner.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/ollama_client.dart';
import 'package:data_hook_claws/src/domain/query_expansion_service.dart';
import 'package:data_hook_claws/src/domain/search_orchestrator.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:data_hook_claws/src/models/query_expansion_result.dart';
import 'package:data_hook_claws/src/models/search_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty query only returns local state', () async {
    final repository = MemoryFoodRepository(seedItems: _seedFoods);
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: _FakeForegroundFetchRunner(),
      budgetPlanner: const FetchBudgetPlanner(),
      queryExpansionService: _FakeQueryExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: MemoryFoodRepository(),
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      ),
    );

    final states = await orchestrator.search('').toList();
    expect(states.single.status, SearchStatus.local);
    expect(states.single.combinedResults, hasLength(_seedFoods.length));
  });

  test('skips fetch when local hit threshold is satisfied', () async {
    final repository = MemoryFoodRepository(
      seedItems: List<FoodItem>.generate(
        10,
        (index) => _food('food-$index', 'Salmon $index'),
      ),
    );
    final runner = _FakeForegroundFetchRunner();
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: runner,
      budgetPlanner: const FetchBudgetPlanner(),
      queryExpansionService: _FakeQueryExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: MemoryFoodRepository(),
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      ),
    );

    final states = await orchestrator.search('salmon').toList();
    expect(states.last.status, SearchStatus.archived);
    expect(runner.invocations, 0);
  });

  test('fetches and archives when local hits are low', () async {
    final repository = MemoryFoodRepository(seedItems: const []);
    final runner = _FakeForegroundFetchRunner(
      onRun: ({required query, required repository}) async {
        await repository.upsertFoods([_food('new-salmon', 'Atlantic Salmon')]);
        return ForegroundFetchResult(
          importedFoods: [_food('new-salmon', 'Atlantic Salmon')],
          succeededSources: const ['canada-cnf'],
        );
      },
      repository: repository,
    );
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: runner,
      budgetPlanner: const FetchBudgetPlanner(),
      queryExpansionService: _FakeQueryExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: MemoryFoodRepository(),
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      ),
    );

    final states = await orchestrator.search('salmon').toList();
    expect(states.map((item) => item.status), contains(SearchStatus.fetching));
    expect(states.last.status, SearchStatus.archived);
    expect(states.last.combinedResults.single.name, 'Atlantic Salmon');
  });

  test(
    'returns failed state while preserving local results on fetch failure',
    () async {
      final repository = MemoryFoodRepository(
        seedItems: [_food('seed', 'Tofu')],
      );
      final orchestrator = SearchOrchestrator(
        repository: repository,
        foregroundFetchRunner: _FakeForegroundFetchRunner(
          onRun: ({required query, required repository}) async {
            return const ForegroundFetchResult(
              importedFoods: [],
              succeededSources: [],
            );
          },
          repository: repository,
        ),
        budgetPlanner: const FetchBudgetPlanner(localHitThreshold: 2),
        queryExpansionService: _FakeQueryExpansionService(),
        enrichmentQueue: BackgroundEnrichmentQueue(
          syncUseCase: SyncFoodCatalogUseCase(
            repository: MemoryFoodRepository(),
            importers: const [],
            normalizer: const FoodRecordNormalizer(),
          ),
        ),
      );

      final states = await orchestrator.search('tofu').toList();
      expect(states.last.status, SearchStatus.failed);
      expect(states.last.combinedResults.single.name, 'Tofu');
    },
  );

  test('continues search when recent fetch-job history read fails', () async {
    final repository = _FailingRecentFetchJobsRepository();
    final runner = _FakeForegroundFetchRunner(
      onRun: ({required query, required repository}) async {
        await repository.upsertFoods([
          _food('fetched-$query', 'Fetched $query'),
        ]);
        return ForegroundFetchResult(
          importedFoods: [_food('fetched-$query', 'Fetched $query')],
          succeededSources: const ['canada-cnf'],
        );
      },
      repository: repository,
    );
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: runner,
      budgetPlanner: const FetchBudgetPlanner(localHitThreshold: 2),
      queryExpansionService: _FakeQueryExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: MemoryFoodRepository(),
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      ),
    );

    final states = await orchestrator.search('salmon').toList();

    expect(repository.recentFetchJobsReadAttempts, 1);
    expect(runner.invocations, 1);
    expect(
      states.map((state) => state.status),
      contains(SearchStatus.fetching),
    );
    expect(states.last.status, SearchStatus.archived);
    expect(states.last.combinedResults.single.name, 'Fetched salmon');
  });

  test('preserves fetched foods when post-fetch search read fails', () async {
    final repository = _FailingRefreshedSearchRepository();
    final runner = _FakeForegroundFetchRunner(
      onRun: ({required query, required repository}) async {
        final fetched = _food('fetched-$query', 'Fetched $query');
        await repository.upsertFoods([fetched]);
        return ForegroundFetchResult(
          importedFoods: [fetched],
          succeededSources: const ['canada-cnf'],
        );
      },
      repository: repository,
    );
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: runner,
      budgetPlanner: const FetchBudgetPlanner(localHitThreshold: 2),
      queryExpansionService: _FakeQueryExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: MemoryFoodRepository(),
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      ),
    );

    final states = await orchestrator.search('salmon').toList();

    expect(repository.searchFoodsCalls, 2);
    expect(runner.invocations, 1);
    expect(states.last.status, SearchStatus.archived);
    expect(states.last.combinedResults.single.name, 'Fetched salmon');
  });

  test(
    'bounds expansion cache and re-expands the least recently used query',
    () async {
      final repository = MemoryFoodRepository();
      final expansionService = _CountingQueryExpansionService();
      final orchestrator = SearchOrchestrator(
        repository: repository,
        foregroundFetchRunner: _FakeForegroundFetchRunner(),
        budgetPlanner: const FetchBudgetPlanner(localHitThreshold: 0),
        queryExpansionService: expansionService,
        enrichmentQueue: BackgroundEnrichmentQueue(
          syncUseCase: SyncFoodCatalogUseCase(
            repository: repository,
            importers: const [],
            normalizer: const FoodRecordNormalizer(),
          ),
        ),
        maxExpansionCacheEntries: 2,
      );

      await orchestrator.search('one').drain<void>();
      await orchestrator.search('two').drain<void>();
      await orchestrator.search('three').drain<void>();
      expect(expansionService.calls, 3);

      const allImporters = ['usda', 'canada-cnf', 'uk-mccance', 'jp-standard'];
      await orchestrator.scheduleEnrichment('two', allImporters);
      expect(expansionService.calls, 3);

      await orchestrator.scheduleEnrichment('one', allImporters);
      expect(expansionService.calls, 4);
      expect(expansionService.queries, ['one', 'two', 'three', 'one']);
    },
  );
}

class _FailingRecentFetchJobsRepository extends MemoryFoodRepository {
  int recentFetchJobsReadAttempts = 0;

  @override
  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    String? importerId,
    String? status,
    int limit = 20,
  }) async {
    recentFetchJobsReadAttempts += 1;
    throw StateError('fetch-job history unavailable');
  }
}

class _FailingRefreshedSearchRepository extends MemoryFoodRepository {
  int searchFoodsCalls = 0;

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    searchFoodsCalls += 1;
    if (searchFoodsCalls == 2) {
      throw StateError('post-fetch search read unavailable');
    }
    return super.searchFoods(query);
  }
}

class _FakeForegroundFetchRunner extends ForegroundFetchRunner {
  _FakeForegroundFetchRunner({this.onRun, this.repository})
    : super(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: MemoryFoodRepository(),
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      );

  final Future<ForegroundFetchResult> Function({
    required String query,
    required MemoryFoodRepository repository,
  })?
  onRun;
  final MemoryFoodRepository? repository;
  int invocations = 0;

  @override
  Future<ForegroundFetchResult> run({
    required String query,
    required List<String> importerIds,
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry job) persistJob,
  }) async {
    invocations += 1;
    if (onRun != null && repository != null) {
      return onRun!(query: query, repository: repository!);
    }
    return const ForegroundFetchResult(importedFoods: [], succeededSources: []);
  }
}

class _FakeQueryExpansionService extends QueryExpansionService {
  _FakeQueryExpansionService()
    : super(persistSuggestion: (_) async {}, ollamaClient: _FakeOllamaClient());

  @override
  Future<QueryExpansionResult> expand(String rawQuery) async {
    return QueryExpansionResult(
      primaryQuery: rawQuery.trim(),
      aliases: const ['query alias'],
      translations: const ['翻译'],
      sourceHints: const ['canada-cnf'],
      usedModel: false,
    );
  }
}

class _CountingQueryExpansionService extends QueryExpansionService {
  _CountingQueryExpansionService()
    : super(persistSuggestion: (_) async {}, ollamaClient: _FakeOllamaClient());

  int calls = 0;
  final List<String> queries = [];

  @override
  Future<QueryExpansionResult> expand(String rawQuery) async {
    calls += 1;
    queries.add(rawQuery.trim());
    return QueryExpansionResult(
      primaryQuery: rawQuery.trim(),
      aliases: const [],
      translations: const [],
      sourceHints: const [],
      usedModel: false,
    );
  }
}

class _FakeOllamaClient extends OllamaClient {
  _FakeOllamaClient() : super();

  @override
  Future<String> generateJson({required String prompt}) async {
    return '{}';
  }
}

FoodItem _food(String id, String name) {
  return FoodItem(
    id: id,
    name: name,
    category: 'Seafood',
    country: 'Canada',
    sourceName: 'CNF',
    description: '$name description',
    servingBasis: 'Per 100 g',
    tags: const ['protein'],
    nutrients: const [Nutrient(label: 'Protein', amount: 20, unit: 'g')],
    lastUpdated: DateTime(2026, 5, 23),
  );
}

final _seedFoods = <FoodItem>[_food('seed-salmon', 'Atlantic Salmon')];
