import '../data/food_repository.dart';
import '../models/enrichment_queue_state.dart';
import '../models/fetch_job_entry.dart';
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
    int maxExpansionCacheEntries = 32,
    SourceRoutingSuggestionService? sourceRoutingSuggestionService,
  }) : _repository = repository,
       _foregroundFetchRunner = foregroundFetchRunner,
       _budgetPlanner = budgetPlanner,
       _queryExpansionService = queryExpansionService,
       _enrichmentQueue = enrichmentQueue,
       maxExpansionCacheEntries = _validateMaxExpansionCacheEntries(
         maxExpansionCacheEntries,
       ),
       _sourceRoutingSuggestionService = sourceRoutingSuggestionService;

  final FoodRepository _repository;
  final ForegroundFetchRunner _foregroundFetchRunner;
  final FetchBudgetPlanner _budgetPlanner;
  final QueryExpansionService _queryExpansionService;
  final BackgroundEnrichmentQueue _enrichmentQueue;
  final int maxExpansionCacheEntries;
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
    _cacheExpansion(query, expansion);
    final sourceHints = await _sourceHintsWithRoutingSuggestion(
      query: expansion.primaryQuery,
      sourceHints: expansion.sourceHints,
    );
    final recentFailures = await _recentFailuresBestEffort();
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

    List<FoodItem> refreshedResults;
    var refreshedReadSucceeded = true;
    try {
      refreshedResults = await _repository.searchFoods(query);
    } catch (_) {
      // The fetch result already contains normalized foods; a transient
      // reconciliation read must not turn a successful fetch into a failure.
      refreshedResults = const [];
      refreshedReadSucceeded = false;
    }
    final combinedResults = _merge(
      localResults,
      refreshedReadSucceeded ? refreshedResults : fetchResult.importedFoods,
    );

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

    final expansion = _cachedExpansion(query);
    final resolvedExpansion =
        expansion ?? await _queryExpansionService.expand(query);
    if (expansion == null) {
      _cacheExpansion(query, resolvedExpansion);
    }
    final sourceHints = await _sourceHintsWithRoutingSuggestion(
      query: resolvedExpansion.primaryQuery,
      sourceHints: resolvedExpansion.sourceHints,
    );

    final recentFailures = await _recentFailuresBestEffort();
    final remainingImporterIds = _budgetPlanner.routeRemainingImporters(
      sourceHints: sourceHints,
      alreadyTriedImporterIds: alreadyTriedImporterIds,
      recentFailures: recentFailures,
    );

    await _enrichmentQueue.schedule(
      query: query,
      normalizedQuery: resolvedExpansion.primaryQuery,
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

  Future<List<FetchJobEntry>> _recentFailuresBestEffort() async {
    try {
      return await _repository.getRecentFetchJobs(status: 'failure', limit: 20);
    } catch (_) {
      // Failure history only influences source ordering; it must not block
      // local search, foreground fetching, or background enrichment.
      return const [];
    }
  }

  QueryExpansionResult? _cachedExpansion(String query) {
    final cached = _expansionCache.remove(query);
    if (cached == null) {
      return null;
    }
    _expansionCache[query] = cached;
    return cached;
  }

  void _cacheExpansion(String query, QueryExpansionResult expansion) {
    _expansionCache.remove(query);
    _expansionCache[query] = expansion;
    while (_expansionCache.length > maxExpansionCacheEntries) {
      _expansionCache.remove(_expansionCache.keys.first);
    }
  }

  static int _validateMaxExpansionCacheEntries(int value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        'maxExpansionCacheEntries',
        'must be greater than zero',
      );
    }
    return value;
  }

  List<FoodItem> _merge(List<FoodItem> left, List<FoodItem> right) {
    final merged = <String, FoodItem>{};
    for (final item in [...left, ...right]) {
      merged[item.id] = item;
    }
    return merged.values.toList(growable: false);
  }
}
