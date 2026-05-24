import '../models/ai_suggestion_log_entry.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/fetch_job_entry.dart';
import '../models/food_details.dart';
import '../models/food_item.dart';
import '../models/food_summary.dart';
import '../models/import_log_entry.dart';
import '../models/nutrient.dart';
import '../search/food_search_index.dart';
import '../domain/canonical_merge_service.dart';
import 'food_repository.dart';

class MemoryFoodRepository implements FoodRepository {
  MemoryFoodRepository({List<FoodItem>? seedItems})
    : _mergeService = const CanonicalMergeService() {
    final initialItems = List<FoodItem>.from(seedItems ?? const []);
    if (initialItems.isNotEmpty) {
      upsertFoods(initialItems);
    }
  }

  final CanonicalMergeService _mergeService;
  final List<FoodItem> _items = [];
  final Map<String, FoodDetails> _detailsByCanonicalId = {};
  final List<ImportLogEntry> _importLogs = [];
  final List<FetchJobEntry> _fetchJobs = [];
  final List<AiSuggestionLogEntry> _aiSuggestionLogs = [];
  final List<DatasetArtifactEntry> _datasetArtifacts = [];
  final FoodSearchIndex _searchIndex = FoodSearchIndex();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<FoodItem>> getAllFoods() async {
    return List<FoodItem>.unmodifiable(_items);
  }

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return getAllFoods();
    }

    return _searchIndex
        .search(items: _items, query: normalizedQuery)
        .map((match) => match.food)
        .toList(growable: false);
  }

  @override
  Future<List<FoodSummary>> searchFoodSummaries(
    String query, {
    int limit = 20,
  }) async {
    final items = await searchFoods(query);
    return items
        .take(limit)
        .map(
          (item) => FoodSummary(
            id: item.id,
            name: item.name,
            category: item.category,
            country: item.country,
            sourceSummary: item.sourceName,
            description: item.description,
            servingBasis: item.servingBasis,
            lastUpdated: item.lastUpdated,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FoodSummary>> searchFoodSummariesByCountry(
    String country, {
    int limit = 1000,
  }) async {
    final normalized = country.trim().toLowerCase();
    return _detailsByCanonicalId.values
        .where((details) {
          if (details.countryHint.toLowerCase() == normalized) {
            return true;
          }
          return details.sourceRecords.any(
            (source) => source.country.toLowerCase() == normalized,
          );
        })
        .take(limit)
        .map(
          (details) => FoodSummary(
            id: details.id,
            name: details.displayName,
            category: details.category,
            country: details.countryHint,
            sourceSummary: details.sourceRecords.length > 1
                ? 'Merged official sources'
                : (details.sourceRecords.isEmpty
                      ? ''
                      : details.sourceRecords.first.sourceName),
            description: details.description,
            servingBasis: details.servingBasis,
            lastUpdated: details.lastAggregatedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<FoodDetails?> getFoodDetails(String canonicalFoodId) async {
    return _detailsByCanonicalId[canonicalFoodId];
  }

  @override
  Future<int> countFoods() async {
    return _items.length;
  }

  @override
  Future<void> upsertFoods(List<FoodItem> incomingItems) async {
    for (final incoming in incomingItems) {
      final audit = _mergeService.decide(
        item: incoming,
        candidates: _detailsByCanonicalId.values
            .map(
              (details) => CanonicalMergeCandidate(
                canonicalFoodId: details.id,
                categoryKey: _mergeService.categoryKey(details.category),
                servingKey: _mergeService.servingKey(details.servingBasis),
                aliasKeys: details.aliases.map(_mergeService.aliasKey).toSet(),
                nutrients: details.aggregatedNutrients,
              ),
            )
            .toList(growable: false),
      );
      final canonicalId = audit.decision.canonicalFoodId;
      final existing = _detailsByCanonicalId[canonicalId];
      final updated = _mergeDetails(
        canonicalId: canonicalId,
        existing: existing,
        incoming: incoming,
        audit: audit,
      );
      _detailsByCanonicalId[canonicalId] = updated;
      _upsertSnapshot(_snapshotFromDetails(updated));
    }
  }

  FoodDetails _mergeDetails({
    required String canonicalId,
    required FoodDetails? existing,
    required FoodItem incoming,
    required CanonicalMergeAudit audit,
  }) {
    final sourceRecord = SourceRecordView(
      id: incoming.id,
      importerId: incoming.id.split(':').first,
      sourceName: incoming.sourceName,
      sourceRecordId: incoming.id,
      country: incoming.country,
      recordTitle: incoming.name,
      recordDescription: incoming.description,
      fetchedAt: incoming.lastUpdated,
      sourceUpdatedAt: incoming.lastUpdated,
      mergeAudit: MergeAuditView(
        sourceRecordId: incoming.id,
        action: audit.decision.action.name,
        confidence: audit.decision.confidence,
        matchedBy: audit.decision.matchedBy,
        reason: audit.decision.reason,
        itemAliasKey: audit.itemAliasKey,
        itemCategoryKey: audit.itemCategoryKey,
        itemServingKey: audit.itemServingKey,
        candidateEvaluations: audit.candidateEvaluations
            .map(
              (evaluation) => MergeCandidateEvaluationView(
                candidateCanonicalFoodId: evaluation.canonicalFoodId,
                aliasMatched: evaluation.aliasMatched,
                categoryMatched: evaluation.categoryMatched,
                servingMatched: evaluation.servingMatched,
                nutrientSimilarity: evaluation.nutrientSimilarity,
                accepted: evaluation.accepted,
                reason: evaluation.reason,
              ),
            )
            .toList(growable: false),
        createdAt: incoming.lastUpdated,
      ),
    );
    final sourceRecords = <String, SourceRecordView>{
      for (final record
          in existing?.sourceRecords ?? const <SourceRecordView>[])
        record.id: record,
      sourceRecord.id: sourceRecord,
    };
    final observations = [
      ...(existing?.nutrientObservations ?? const <NutrientObservationView>[])
          .where((item) => item.sourceRecordId != sourceRecord.id),
      ...incoming.nutrients.map(
        (nutrient) => NutrientObservationView(
          sourceRecordId: sourceRecord.id,
          label: nutrient.label,
          canonicalLabel: nutrient.label,
          amount: nutrient.amount,
          unit: nutrient.unit,
          originalUnit: nutrient.unit,
        ),
      ),
    ];
    final aliases = {
      ...(existing?.aliases ?? const <String>[]),
      incoming.name,
      ...incoming.tags,
    }.toList(growable: false);
    final aggregatedNutrients = _aggregateNutrients(
      observations: observations,
      sourceRecords: sourceRecords.values.toList(growable: false),
    );

    return FoodDetails(
      id: canonicalId,
      displayName: existing?.displayName ?? incoming.name,
      category: existing?.category ?? incoming.category,
      countryHint: _aggregateCountry(
        sourceRecords.values.map((record) => record.country).toSet(),
      ),
      description: incoming.description.isNotEmpty
          ? incoming.description
          : (existing?.description ?? ''),
      servingBasis: existing?.servingBasis ?? incoming.servingBasis,
      lastAggregatedAt: _latestAggregatedAt(existing, incoming),
      aliases: aliases,
      sourceRecords: sourceRecords.values.toList(growable: false),
      aggregatedNutrients: aggregatedNutrients,
      nutrientObservations: observations,
    );
  }

  List<Nutrient> _aggregateNutrients({
    required List<NutrientObservationView> observations,
    required List<SourceRecordView> sourceRecords,
  }) {
    final fetchedBySource = {
      for (final source in sourceRecords) source.id: source.fetchedAt,
    };
    final grouped = <String, List<NutrientObservationView>>{};
    for (final observation in observations) {
      grouped
          .putIfAbsent(observation.canonicalLabel, () => [])
          .add(observation);
    }

    final nutrients = <Nutrient>[];
    for (final entry in grouped.entries) {
      final ordered = entry.value.toList(growable: false)
        ..sort((left, right) {
          final leftFetched =
              fetchedBySource[left.sourceRecordId] ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final rightFetched =
              fetchedBySource[right.sourceRecordId] ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return rightFetched.compareTo(leftFetched);
        });
      final selected = ordered.first;
      nutrients.add(
        Nutrient(
          label: selected.canonicalLabel,
          amount: selected.amount,
          unit: selected.unit,
        ),
      );
    }

    nutrients.sort((left, right) => left.label.compareTo(right.label));
    return nutrients;
  }

  String _aggregateCountry(Set<String> countries) {
    if (countries.length > 1) {
      return 'Multi-source';
    }
    if (countries.isEmpty) {
      return '';
    }
    return countries.first;
  }

  FoodItem _snapshotFromDetails(FoodDetails details) {
    return FoodItem(
      id: details.id,
      name: details.displayName,
      category: details.category,
      country: details.countryHint,
      sourceName: details.sourceRecords.length > 1
          ? 'Merged official sources'
          : details.sourceRecords.first.sourceName,
      description: details.description,
      servingBasis: details.servingBasis,
      tags: details.aliases,
      nutrients: details.aggregatedNutrients,
      lastUpdated: details.lastAggregatedAt,
    );
  }

  void _upsertSnapshot(FoodItem snapshot) {
    final existingIndex = _items.indexWhere((item) => item.id == snapshot.id);
    if (existingIndex >= 0) {
      _items[existingIndex] = snapshot;
    } else {
      _items.add(snapshot);
    }
  }

  DateTime _latestAggregatedAt(FoodDetails? existing, FoodItem incoming) {
    final previous =
        existing?.lastAggregatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (incoming.lastUpdated.isAfter(previous)) {
      return incoming.lastUpdated;
    }
    return previous;
  }

  @override
  Future<void> addImportLog(ImportLogEntry entry) async {
    _importLogs.add(entry);
    _importLogs.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
  }

  @override
  Future<List<ImportLogEntry>> getImportLogs({int limit = 20}) async {
    return _importLogs.take(limit).toList(growable: false);
  }

  @override
  Future<void> upsertFetchJob(FetchJobEntry entry) async {
    final index = _fetchJobs.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      _fetchJobs[index] = entry;
      return;
    }
    _fetchJobs.add(entry);
  }

  @override
  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    int limit = 20,
  }) async {
    final filtered =
        _fetchJobs
            .where((entry) {
              final matchesQuery = query == null || entry.query == query;
              final matchesPhase = phase == null || entry.phase == phase;
              return matchesQuery && matchesPhase;
            })
            .toList(growable: false)
          ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<FetchJobEntry?> getLatestFetchJobForQuery({
    required String query,
    required String phase,
  }) async {
    final jobs = await getRecentFetchJobs(query: query, phase: phase, limit: 1);
    if (jobs.isEmpty) {
      return null;
    }
    return jobs.first;
  }

  @override
  Future<void> addAiSuggestionLog(AiSuggestionLogEntry entry) async {
    _aiSuggestionLogs.add(entry);
    _aiSuggestionLogs.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
  }

  @override
  Future<List<AiSuggestionLogEntry>> getAiSuggestionLogs({
    int limit = 20,
  }) async {
    return _aiSuggestionLogs.take(limit).toList(growable: false);
  }

  @override
  Future<void> upsertDatasetArtifact(DatasetArtifactEntry entry) async {
    final index = _datasetArtifacts.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      _datasetArtifacts[index] = entry;
      return;
    }
    _datasetArtifacts.add(entry);
  }

  @override
  Future<void> copyDatabaseSnapshot({required String destinationPath}) async {
    throw UnsupportedError(
      'MemoryFoodRepository does not support database snapshot export.',
    );
  }
}
