import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/background_enrichment_queue.dart';
import 'package:data_hook_claws/src/domain/fetch_budget_planner.dart';
import 'package:data_hook_claws/src/domain/foreground_fetch_runner.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/ollama_client.dart';
import 'package:data_hook_claws/src/domain/query_expansion_service.dart';
import 'package:data_hook_claws/src/domain/search_orchestrator.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/importers/food_importer.dart';
import 'package:data_hook_claws/src/models/enrichment_queue_state.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:data_hook_claws/src/models/query_expansion_result.dart';
import 'package:data_hook_claws/src/models/raw_food_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enrichment only runs the sources not tried in foreground', () async {
    final repository = MemoryFoodRepository();
    final useCase = SyncFoodCatalogUseCase(
      repository: repository,
      normalizer: const FoodRecordNormalizer(),
      importers: [
        _FakeImporter(id: 'uk-mccance'),
        _FakeImporter(id: 'jp-standard'),
      ],
    );
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: _ForegroundRunnerThatSeeds(repository),
      budgetPlanner: const FetchBudgetPlanner(),
      queryExpansionService: _HintingExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(syncUseCase: useCase),
    );

    await orchestrator.search('salmon').drain<void>();

    final states = <EnrichmentQueueState>[];
    final subscription = orchestrator.currentEnrichmentState.listen(states.add);
    addTearDown(subscription.cancel);

    await orchestrator.scheduleEnrichment('salmon', const [
      'usda',
      'canada-cnf',
    ]);
    await Future<void>.delayed(Duration.zero);

    final jobs = await repository.getRecentFetchJobs(
      query: 'salmon',
      phase: 'enrichment',
      limit: 10,
    );
    final foods = await repository.searchFoods('salmon');

    expect(jobs.map((job) => job.importerId), ['uk-mccance', 'jp-standard']);
    expect(states.last.status, EnrichmentStatus.completed);
    expect(foods.length, 3);
  });

  test('enrichment reports failed when every remaining source fails', () async {
    final repository = MemoryFoodRepository();
    final useCase = SyncFoodCatalogUseCase(
      repository: repository,
      normalizer: const FoodRecordNormalizer(),
      importers: [
        _FailingImporter(id: 'uk-mccance'),
        _FailingImporter(id: 'jp-standard'),
      ],
    );
    final orchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: _ForegroundRunnerThatSeeds(repository),
      budgetPlanner: const FetchBudgetPlanner(),
      queryExpansionService: _HintingExpansionService(),
      enrichmentQueue: BackgroundEnrichmentQueue(syncUseCase: useCase),
    );

    await orchestrator.search('salmon').drain<void>();

    final states = <EnrichmentQueueState>[];
    final subscription = orchestrator.currentEnrichmentState.listen(states.add);
    addTearDown(subscription.cancel);

    await orchestrator.scheduleEnrichment('salmon', const [
      'usda',
      'canada-cnf',
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(states.last.status, EnrichmentStatus.failed);
  });
}

class _ForegroundRunnerThatSeeds extends ForegroundFetchRunner {
  _ForegroundRunnerThatSeeds(this.repository)
    : super(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: repository,
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      );

  final MemoryFoodRepository repository;

  @override
  Future<ForegroundFetchResult> run({
    required String query,
    required List<String> importerIds,
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry job) persistJob,
  }) async {
    await repository.upsertFoods([
      _food('foreground-$query', '$query foreground'),
    ]);
    return ForegroundFetchResult(
      importedFoods: [_food('foreground-$query', '$query foreground')],
      succeededSources: const ['canada-cnf'],
    );
  }
}

class _HintingExpansionService extends QueryExpansionService {
  _HintingExpansionService()
    : super(persistSuggestion: (_) async {}, ollamaClient: _FakeOllamaClient());

  @override
  Future<QueryExpansionResult> expand(String rawQuery) async {
    return QueryExpansionResult(
      primaryQuery: rawQuery.trim(),
      aliases: const [],
      translations: const [],
      sourceHints: const ['jp-standard'],
      usedModel: false,
    );
  }
}

class _FakeImporter implements FoodImporter {
  _FakeImporter({required this.id});

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  String get country => 'Test';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    return [_record(id, request.query)];
  }
}

class _FailingImporter implements FoodImporter {
  _FailingImporter({required this.id});

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  String get country => 'Test';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) {
    throw Exception('failed $id');
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
    category: 'Test',
    country: 'Test',
    sourceName: 'Test',
    description: '$name description',
    servingBasis: 'Per 100 g',
    tags: const ['tag'],
    nutrients: const [Nutrient(label: 'Protein', amount: 12, unit: 'g')],
    lastUpdated: DateTime(2026, 5, 23),
  );
}

RawFoodRecord _record(String importerId, String query) {
  return RawFoodRecord(
    sourceRecordId: '$importerId-$query',
    name: '$query $importerId',
    category: 'Test',
    country: 'Test',
    sourceName: importerId,
    description: '$query description',
    servingBasis: 'Per 100 g',
    tags: const ['tag'],
    nutrients: const [
      RawNutrientRecord(label: 'Protein', amount: 15, unit: 'g'),
    ],
    lastUpdated: DateTime(2026, 5, 23),
  );
}
