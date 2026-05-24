import '../data/food_repository.dart';
import '../models/enrichment_queue_state.dart';
import '../models/food_item.dart';
import '../models/query_expansion_result.dart';
import '../models/search_session_state.dart';
import 'background_enrichment_queue.dart';
import 'fetch_budget_planner.dart';
import 'foreground_fetch_runner.dart';
import 'query_expansion_service.dart';

class SearchOrchestrator {
  SearchOrchestrator({
    required FoodRepository repository,
    required ForegroundFetchRunner foregroundFetchRunner,
    required FetchBudgetPlanner budgetPlanner,
    required QueryExpansionService queryExpansionService,
    required BackgroundEnrichmentQueue enrichmentQueue,
  }) : _repository = repository,
       _foregroundFetchRunner = foregroundFetchRunner,
       _budgetPlanner = budgetPlanner,
       _queryExpansionService = queryExpansionService,
       _enrichmentQueue = enrichmentQueue;

  final FoodRepository _repository;
  final ForegroundFetchRunner _foregroundFetchRunner;
  final FetchBudgetPlanner _budgetPlanner;
  final QueryExpansionService _queryExpansionService;
  final BackgroundEnrichmentQueue _enrichmentQueue;
  final Map<String, QueryExpansionResult> _expansionCache = {};

  Stream<EnrichmentQueueState> get currentEnrichmentState =>
      _enrichmentQueue.states;

  Stream<SearchSessionState> search(String rawQuery) async* {
    final query = rawQuery.trim();
    final localResults = await _repository.searchFoods(query);

    if (query.isEmpty) {
      yield SearchSessionState(
        query: query,
        localResults: localResults,
        foregroundFetchedResults: const [],
        combinedResults: localResults,
        status: SearchStatus.local,
        activeSources: const [],
        message: 'Local results ready.',
      );
      return;
    }

    yield SearchSessionState(
      query: query,
      localResults: localResults,
      foregroundFetchedResults: const [],
      combinedResults: localResults,
      status: SearchStatus.local,
      activeSources: const [],
      message: 'Local results ready.',
    );

    final expansion = await _queryExpansionService.expand(query);
    _expansionCache[query] = expansion;
    final plan = _budgetPlanner.plan(
      query: expansion.primaryQuery,
      localHitCount: localResults.length,
      sourceHints: expansion.sourceHints,
    );

    if (!plan.shouldFetch) {
      yield SearchSessionState(
        query: query,
        localResults: localResults,
        foregroundFetchedResults: const [],
        combinedResults: localResults,
        status: SearchStatus.archived,
        activeSources: const [],
        message: 'Archived into local database.',
      );
      return;
    }

    yield SearchSessionState(
      query: query,
      localResults: localResults,
      foregroundFetchedResults: const [],
      combinedResults: localResults,
      status: SearchStatus.fetching,
      activeSources: plan.importerIds,
      message: 'Fetching official data.',
    );

    final fetchResult = await _foregroundFetchRunner.run(
      query: expansion.primaryQuery,
      importerIds: plan.importerIds,
      limitPerImporter: plan.limitPerImporter,
      persistJob: _repository.upsertFetchJob,
    );

    final refreshedResults = await _repository.searchFoods(query);
    final combinedResults = _merge(localResults, refreshedResults);

    if (fetchResult.succeededSources.isEmpty) {
      yield SearchSessionState(
        query: query,
        localResults: localResults,
        foregroundFetchedResults: const [],
        combinedResults: combinedResults,
        status: SearchStatus.failed,
        activeSources: plan.importerIds,
        message: 'Fetch failed.',
      );
      return;
    }

    yield SearchSessionState(
      query: query,
      localResults: localResults,
      foregroundFetchedResults: fetchResult.importedFoods,
      combinedResults: combinedResults,
      status: SearchStatus.archived,
      activeSources: plan.importerIds,
      message: 'Archived into local database.',
    );
  }

  Future<void> scheduleEnrichment(
    String rawQuery,
    List<String> alreadyTriedImporterIds,
  ) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return;
    }

    final expansion =
        _expansionCache[query] ?? await _queryExpansionService.expand(query);
    _expansionCache[query] = expansion;

    final remainingImporterIds = _remainingImporterIds(
      sourceHints: expansion.sourceHints,
      alreadyTriedImporterIds: alreadyTriedImporterIds,
    );

    await _enrichmentQueue.schedule(
      query: query,
      normalizedQuery: expansion.primaryQuery,
      importerIds: remainingImporterIds,
      limitPerImporter: _budgetPlanner.limitPerImporter,
      persistJob: _repository.upsertFetchJob,
    );
  }

  Future<void> cancelEnrichment(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return;
    }
    await _enrichmentQueue.cancel(query);
  }

  List<FoodItem> _merge(List<FoodItem> left, List<FoodItem> right) {
    final merged = <String, FoodItem>{};
    for (final item in [...left, ...right]) {
      merged[item.id] = item;
    }
    return merged.values.toList(growable: false);
  }

  List<String> _remainingImporterIds({
    required List<String> sourceHints,
    required List<String> alreadyTriedImporterIds,
  }) {
    final alreadyTried = alreadyTriedImporterIds.toSet();
    final hinted = sourceHints
        .where(_budgetPlanner.prioritizedImporters.contains)
        .where((item) => !alreadyTried.contains(item))
        .toList(growable: false);
    return [
      ...hinted,
      ..._budgetPlanner.prioritizedImporters.where(
        (item) => !alreadyTried.contains(item) && !hinted.contains(item),
      ),
    ].toList(growable: false);
  }
}
