import '../models/ai_suggestion_log_entry.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/export_history_entry.dart';
import '../models/fetch_job_entry.dart';
import '../models/food_details.dart';
import '../models/food_search_query.dart';
import '../models/food_item.dart';
import '../models/food_summary.dart';
import '../models/import_log_entry.dart';
import '../models/manual_governance.dart';
import '../models/merge_review_issue.dart';
import '../models/nutrient.dart';
import '../models/storage_paths.dart';
import '../search/food_search_index.dart';
import '../domain/canonical_merge_service.dart';
import '../domain/food_quality_service.dart';
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
  final FoodQualityService _qualityService = FoodQualityService();
  final List<FoodItem> _items = [];
  final Map<String, FoodDetails> _detailsByCanonicalId = {};
  final List<ImportLogEntry> _importLogs = [];
  final List<FetchJobEntry> _fetchJobs = [];
  final List<AiSuggestionLogEntry> _aiSuggestionLogs = [];
  final List<DatasetArtifactEntry> _datasetArtifacts = [];
  final List<ExportHistoryEntry> _exportHistory = [];
  final List<ManualGovernanceLogEntry> _manualGovernanceLogs = [];
  final Map<String, String> _appMeta = {};
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
  Future<List<FoodItem>> searchFoodsAdvanced(
    FoodSearchQuery query, {
    int limit = 100,
  }) async {
    final matched = <FoodItem>[];
    for (final item in _items) {
      final details = _detailsByCanonicalId[item.id];
      if (_qualityService.matchesAdvancedQuery(
        item: item,
        details: details,
        query: query,
      )) {
        matched.add(item);
      }
      if (matched.length >= limit) {
        break;
      }
    }
    return matched;
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
  Future<List<FoodSummary>> searchFoodSummariesAdvanced(
    FoodSearchQuery query, {
    int limit = 100,
  }) async {
    final items = await searchFoodsAdvanced(query, limit: limit);
    return items.map(_qualityService.summaryFromItem).toList(growable: false);
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
  Future<List<MergeReviewIssue>> getMergeReviewIssues({int limit = 100}) async {
    final issues = <MergeReviewIssue>[];
    for (final details in _detailsByCanonicalId.values) {
      issues.addAll(_qualityService.reviewIssuesForDetails(details));
    }
    issues.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return issues.take(limit).toList(growable: false);
  }

  @override
  Future<void> mergeSourceRecord({
    required String sourceRecordId,
    required String targetCanonicalFoodId,
    required String note,
  }) async {
    final sourceLocation = _findSource(sourceRecordId);
    if (sourceLocation == null) {
      throw StateError('Source record not found: $sourceRecordId');
    }
    final target = _detailsByCanonicalId[targetCanonicalFoodId];
    if (target == null) {
      throw StateError(
        'Target canonical food not found: $targetCanonicalFoodId',
      );
    }
    if (sourceLocation.canonicalId == targetCanonicalFoodId) {
      return;
    }

    final source = sourceLocation.source;
    final observations = sourceLocation.details.nutrientObservations
        .where((item) => item.sourceRecordId == sourceRecordId)
        .toList(growable: false);
    final fromDetails = _removeSourceFromDetails(
      sourceLocation.details,
      sourceRecordId,
    );
    _replaceOrRemoveDetails(sourceLocation.canonicalId, fromDetails);
    final toDetails = _addSourceToDetails(
      target,
      source,
      observations,
      targetCanonicalFoodId,
    );
    _detailsByCanonicalId[targetCanonicalFoodId] = toDetails;
    _upsertSnapshot(_snapshotFromDetails(toDetails));
    _recordGovernance(
      action: 'merge',
      sourceRecordId: sourceRecordId,
      fromCanonicalFoodId: sourceLocation.canonicalId,
      toCanonicalFoodId: targetCanonicalFoodId,
      note: note,
    );
  }

  @override
  Future<void> splitSourceRecord({
    required String sourceRecordId,
    required String note,
  }) async {
    final sourceLocation = _findSource(sourceRecordId);
    if (sourceLocation == null) {
      throw StateError('Source record not found: $sourceRecordId');
    }
    final newCanonicalId = 'manual-split:$sourceRecordId';
    final source = sourceLocation.source;
    final observations = sourceLocation.details.nutrientObservations
        .where((item) => item.sourceRecordId == sourceRecordId)
        .toList(growable: false);

    final fromDetails = _removeSourceFromDetails(
      sourceLocation.details,
      sourceRecordId,
    );
    _replaceOrRemoveDetails(sourceLocation.canonicalId, fromDetails);
    final newDetails = FoodDetails(
      id: newCanonicalId,
      displayName: source.recordTitle,
      category: sourceLocation.details.category,
      countryHint: source.country,
      description: source.recordDescription,
      servingBasis: sourceLocation.details.servingBasis,
      lastAggregatedAt: source.sourceUpdatedAt,
      aliases: [source.recordTitle],
      sourceRecords: [source],
      aggregatedNutrients: _aggregateNutrients(
        observations: observations,
        sourceRecords: [source],
      ),
      nutrientObservations: observations,
    );
    _detailsByCanonicalId[newCanonicalId] = newDetails;
    _upsertSnapshot(_snapshotFromDetails(newDetails));
    _recordGovernance(
      action: 'split',
      sourceRecordId: sourceRecordId,
      fromCanonicalFoodId: sourceLocation.canonicalId,
      toCanonicalFoodId: newCanonicalId,
      note: note,
    );
  }

  @override
  Future<void> overrideCanonicalFood({
    required String canonicalFoodId,
    required CanonicalOverrideFields fields,
    required String note,
  }) async {
    final details = _detailsByCanonicalId[canonicalFoodId];
    if (details == null) {
      throw StateError('Canonical food not found: $canonicalFoodId');
    }
    if (fields.isEmpty) {
      return;
    }
    final updated = FoodDetails(
      id: details.id,
      displayName: fields.displayName?.trim().isNotEmpty == true
          ? fields.displayName!.trim()
          : details.displayName,
      category: fields.category?.trim().isNotEmpty == true
          ? fields.category!.trim()
          : details.category,
      countryHint: fields.countryHint?.trim().isNotEmpty == true
          ? fields.countryHint!.trim()
          : details.countryHint,
      description: fields.description?.trim().isNotEmpty == true
          ? fields.description!.trim()
          : details.description,
      servingBasis: fields.servingBasis?.trim().isNotEmpty == true
          ? fields.servingBasis!.trim()
          : details.servingBasis,
      lastAggregatedAt: DateTime.now(),
      aliases: details.aliases,
      sourceRecords: details.sourceRecords,
      aggregatedNutrients: details.aggregatedNutrients,
      nutrientObservations: details.nutrientObservations,
    );
    _detailsByCanonicalId[canonicalFoodId] = updated;
    _upsertSnapshot(_snapshotFromDetails(updated));
    _recordGovernance(
      action: 'override',
      sourceRecordId: '',
      fromCanonicalFoodId: canonicalFoodId,
      toCanonicalFoodId: canonicalFoodId,
      note: note,
    );
  }

  @override
  Future<List<ManualGovernanceLogEntry>> getManualGovernanceLogs({
    int limit = 50,
  }) async {
    return _manualGovernanceLogs.take(limit).toList(growable: false);
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

  _SourceLocation? _findSource(String sourceRecordId) {
    for (final details in _detailsByCanonicalId.values) {
      for (final source in details.sourceRecords) {
        if (source.id == sourceRecordId) {
          return _SourceLocation(
            canonicalId: details.id,
            details: details,
            source: source,
          );
        }
      }
    }
    return null;
  }

  FoodDetails _removeSourceFromDetails(
    FoodDetails details,
    String sourceRecordId,
  ) {
    final sources = details.sourceRecords
        .where((item) => item.id != sourceRecordId)
        .toList(growable: false);
    final observations = details.nutrientObservations
        .where((item) => item.sourceRecordId != sourceRecordId)
        .toList(growable: false);
    return FoodDetails(
      id: details.id,
      displayName: details.displayName,
      category: details.category,
      countryHint: _aggregateCountry(
        sources.map((item) => item.country).toSet(),
      ),
      description: details.description,
      servingBasis: details.servingBasis,
      lastAggregatedAt: DateTime.now(),
      aliases: details.aliases,
      sourceRecords: sources,
      aggregatedNutrients: _aggregateNutrients(
        observations: observations,
        sourceRecords: sources,
      ),
      nutrientObservations: observations,
    );
  }

  void _replaceOrRemoveDetails(String canonicalId, FoodDetails details) {
    if (details.sourceRecords.isEmpty) {
      _detailsByCanonicalId.remove(canonicalId);
      _items.removeWhere((item) => item.id == canonicalId);
      return;
    }
    _detailsByCanonicalId[canonicalId] = details;
    _upsertSnapshot(_snapshotFromDetails(details));
  }

  FoodDetails _addSourceToDetails(
    FoodDetails details,
    SourceRecordView source,
    List<NutrientObservationView> observations,
    String canonicalId,
  ) {
    final sources = [...details.sourceRecords, source];
    final nextObservations = [
      ...details.nutrientObservations.where(
        (item) => item.sourceRecordId != source.id,
      ),
      ...observations,
    ];
    return FoodDetails(
      id: canonicalId,
      displayName: details.displayName,
      category: details.category,
      countryHint: _aggregateCountry(
        sources.map((item) => item.country).toSet(),
      ),
      description: details.description,
      servingBasis: details.servingBasis,
      lastAggregatedAt: DateTime.now(),
      aliases: {...details.aliases, source.recordTitle}.toList(growable: false),
      sourceRecords: sources,
      aggregatedNutrients: _aggregateNutrients(
        observations: nextObservations,
        sourceRecords: sources,
      ),
      nutrientObservations: nextObservations,
    );
  }

  void _recordGovernance({
    required String action,
    required String sourceRecordId,
    required String fromCanonicalFoodId,
    required String toCanonicalFoodId,
    required String note,
  }) {
    final now = DateTime.now();
    _manualGovernanceLogs.insert(
      0,
      ManualGovernanceLogEntry(
        id: 'manual-${now.microsecondsSinceEpoch}',
        action: action,
        sourceRecordId: sourceRecordId,
        fromCanonicalFoodId: fromCanonicalFoodId,
        toCanonicalFoodId: toCanonicalFoodId,
        note: note,
        createdAt: now,
      ),
    );
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
    String? importerId,
    String? status,
    int limit = 20,
  }) async {
    final filtered =
        _fetchJobs
            .where((entry) {
              final matchesQuery = query == null || entry.query == query;
              final matchesPhase = phase == null || entry.phase == phase;
              final matchesImporter =
                  importerId == null || entry.importerId == importerId;
              final matchesStatus = status == null || entry.status == status;
              return matchesQuery &&
                  matchesPhase &&
                  matchesImporter &&
                  matchesStatus;
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
  Future<String?> getAppMeta(String key) async {
    return _appMeta[key];
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    _appMeta[key] = value;
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
  Future<List<DatasetArtifactEntry>> getDatasetArtifacts({
    int limit = 50,
  }) async {
    final sorted = List<DatasetArtifactEntry>.from(_datasetArtifacts)
      ..sort((left, right) => right.fetchedAt.compareTo(left.fetchedAt));
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<void> markDatasetArtifactRemoved(String id) async {
    final index = _datasetArtifacts.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    final current = _datasetArtifacts[index];
    _datasetArtifacts[index] = DatasetArtifactEntry(
      id: current.id,
      importerId: current.importerId,
      artifactType: current.artifactType,
      localPath: current.localPath,
      sourceUrl: current.sourceUrl,
      sourceVersion: current.sourceVersion,
      fetchedAt: current.fetchedAt,
      status: 'removed',
    );
  }

  @override
  Future<StoragePaths> getStoragePaths() async {
    return const StoragePaths(
      databasePath: '',
      documentsPath: '',
      exportsPath: '',
      cachePath: '',
    );
  }

  @override
  Future<void> copyDatabaseSnapshot({required String destinationPath}) async {
    throw UnsupportedError(
      'MemoryFoodRepository does not support database snapshot export.',
    );
  }

  @override
  Future<void> addExportHistory(ExportHistoryEntry entry) async {
    _exportHistory.removeWhere((item) => item.id == entry.id);
    _exportHistory.add(entry);
    _exportHistory.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
  }

  @override
  Future<List<ExportHistoryEntry>> getExportHistory({int limit = 20}) async {
    return _exportHistory.take(limit).toList(growable: false);
  }
}

class _SourceLocation {
  const _SourceLocation({
    required this.canonicalId,
    required this.details,
    required this.source,
  });

  final String canonicalId;
  final FoodDetails details;
  final SourceRecordView source;
}
