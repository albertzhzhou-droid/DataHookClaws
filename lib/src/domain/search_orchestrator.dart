import '../data/food_repository.dart';
import '../models/enrichment_queue_state.dart';
import '../models/food_item.dart';
import '../models/query_expansion_result.dart';
import '../models/search_session_state.dart';
import 'background_enrichment_queue.dart';
import 'ai_assist_services.dart';
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
    SourceRoutingSuggestionService? sourceRoutingSuggestionService,
  }) : _repository = repository,
       _foregroundFetchRunner = foregroundFetchRunner,
       _budgetPlanner = budgetPlanner,
       _queryExpansionService = queryExpansionService,
       _enrichmentQueue = enrichmentQueue,
       _sourceRoutingSuggestionService = sourceRoutingSuggestionService;

  final FoodRepository _repository;
  final ForegroundFetchRunner _foregroundFetchRunner;
  final FetchBudgetPlanner _budgetPlanner;
  final QueryExpansionService _queryExpansionService;
  final BackgroundEnrichmentQueue _enrichmentQueue;
  final SourceRoutingSuggestionService? _sourceRoutingSuggestionService;
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
    final sourceHints = await _sourceHintsWithRoutingSuggestion(
      query: expansion.primaryQuery,
      sourceHints: expansion.sourceHints,
    );
    final recentFailures = await _repository.getRecentFetchJobs(
      status: 'failure',
      limit: 20,
    );
    final plan = _budgetPlanner.plan(
      query: expansion.primaryQuery,
      localHitCount: localResults.length,
      sourceHints: sourceHints,
      recentFailures: recentFailures,
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
    final sourceHints = await _sourceHintsWithRoutingSuggestion(
      query: expansion.primaryQuery,
      sourceHints: expansion.sourceHints,
    );

    final recentFailures = await _repository.getRecentFetchJobs(
      status: 'failure',
      limit: 20,
    );
    final remainingImporterIds = _budgetPlanner.routeRemainingImporters(
      sourceHints: sourceHints,
      alreadyTriedImporterIds: alreadyTriedImporterIds,
      recentFailures: recentFailures,
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

  Future<List<String>> _sourceHintsWithRoutingSuggestion({
    required String query,
    required List<String> sourceHints,
  }) async {
    final service = _sourceRoutingSuggestionService;
    if (service == null) {
      return sourceHints;
    }
    return service.suggestOrder(
      query: query,
      candidateImporterIds: [
        ...sourceHints,
        ..._budgetPlanner.prioritizedImporters.where(
          (id) => !sourceHints.contains(id),
        ),
      ],
    );
  }

  List<FoodItem> _merge(List<FoodItem> left, List<FoodItem> right) {
    final merged = <String, FoodItem>{};
    for (final item in [...left, ...right]) {
      merged[item.id] = item;
    }
    return merged.values.toList(growable: false);
  }
}
