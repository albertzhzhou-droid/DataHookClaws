import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/export_models.dart';
import '../../api/food_catalog_export_service.dart';
import '../../data/food_repository.dart';
import '../../data/importer_registry.dart';
import '../../data/national_food_sources.dart';
import '../../domain/activity_trace_store.dart';
import '../../domain/app_meta_payload_budget.dart';
import '../../domain/app_meta_write_queue.dart';
import '../../domain/export_share_service.dart';
import '../../domain/normalization/nutrient_comparison_units.dart';
import '../../domain/search_orchestrator.dart';
import '../../models/enrichment_queue_state.dart';
import '../../models/export_history_entry.dart';
import '../../models/food_details.dart';
import '../../domain/sync_food_catalog_use_case.dart';
import '../../models/food_item.dart';
import '../../models/nutrient.dart';
import '../../models/food_search_query.dart';
import '../../models/import_log_entry.dart';
import '../../models/import_models.dart';
import '../../models/search_session_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.syncUseCase,
    required this.searchOrchestrator,
    required this.exportService,
    required this.entities,
    required this.importerDescriptors,
    required this.exportShareService,
    required this.onOpenOperations,
    required this.onOpenSettings,
  });

  final FoodRepository repository;
  final SyncFoodCatalogUseCase syncUseCase;
  final SearchOrchestrator searchOrchestrator;
  final FoodCatalogExportService exportService;
  final List<AdministrativeFoodEntity> entities;
  final List<ImporterDescriptor> importerDescriptors;
  final ExportShareService exportShareService;
  final VoidCallback onOpenOperations;
  final VoidCallback onOpenSettings;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _CompareReplayDraftPromptTrigger {
  urgentPrompt('urgent_prompt'),
  manual('manual');

  const _CompareReplayDraftPromptTrigger(this.value);

  final String value;
}

enum _CompareReplayDraftPromptDismissReason {
  unmounted('unmounted'),
  dismissedByNavigation('dismissed_by_navigation'),
  dismissedByBackground('dismissed_by_background');

  const _CompareReplayDraftPromptDismissReason(this.value);

  final String value;
}

enum _CompareReplayDraftPromptDialogResult {
  clearNow('clear_now'),
  remindLater('remind_later'),
  dismissedByUser('dismissed'),
  dismissedByNavigation('dismissed_by_navigation'),
  dismissedByBackground('dismissed_by_background');

  const _CompareReplayDraftPromptDialogResult(this.value);

  final String value;
}

enum _CompareReplayDraftPromptUserAction {
  suppressed('suppressed'),
  shown('shown'),
  abortedUnmounted('aborted_unmounted'),
  remindLater('remind_later'),
  dismissedNoAction('dismissed_no_action'),
  dismissedByUser('dismissed_by_user'),
  clearFromPrompt('clear_from_prompt'),
  manualClear('manual_clear');

  const _CompareReplayDraftPromptUserAction(this.value);

  final String value;
}

class _CompareReplayDraftPromptConfig {
  const _CompareReplayDraftPromptConfig({
    required this.version,
    required this.title,
    required this.bodyTemplate,
    required this.dismissButtonLabel,
    required this.remindLaterButtonLabel,
    required this.clearNowButtonLabel,
    required this.urgentThreshold,
    required this.snooze,
    required this.maxCountPerSession,
    this.experimentVariant,
  });

  final String version;
  final String title;
  final String bodyTemplate;
  final String dismissButtonLabel;
  final String remindLaterButtonLabel;
  final String clearNowButtonLabel;
  final Duration urgentThreshold;
  final Duration snooze;
  final int maxCountPerSession;
  final String? experimentVariant;

  String buildBody({required String scopeLabel, required String remaining}) =>
      bodyTemplate
          .replaceAll('{scope}', scopeLabel)
          .replaceAll('{remaining}', remaining);

  int get effectiveCooldownMs => snooze.inMilliseconds;
}

class _HomePageState extends State<HomePage> {
  static const String _recentSearchesMetaKey = 'recent_searches_v1';
  static const String _favoriteFoodsMetaKey = 'favorite_foods_v1';
  static const String _favoriteFiltersMetaKey = 'favorite_filters_v1';
  static const String _favoriteTemplatesMetaKey = 'favorite_templates_v1';
  static const String _compareReplayDraftPromptConfigMetaKey =
      'compare_replay_draft_prompt_config_v1';
  static const int _activityTraceCompareReplayDraftPromptSchemaVersion = 1;
  static const String _recentExportRecallsMetaKey = 'recent_export_recalls_v1';
  static const String _recentExportReplayStatusesMetaKey =
      'recent_export_replay_statuses_v1';
  static const String _recentExportReplayDraftsMetaKey =
      'recent_export_replay_drafts_v1';
  static const int _maxRecentSearches = 12;
  static const int _maxFavoriteFoods = 80;
  static const int _maxFavoriteTemplates = 6;
  static const int _maxFavoriteCountryFilters = 12;
  static const int _maxFavoriteDimensionFilterOptions = 12;
  static const int _maxAppMetaValueLength = 1048576;
  static const int _maxCompareFoods = 3;
  static const int _maxCompareReplayRetryAttempts = 3;
  static const Duration _compareReplayDraftRetention = Duration(days: 30);
  static const Duration _activityTraceSessionGap = Duration(minutes: 20);
  static const _CompareReplayDraftPromptConfig
  _defaultCompareReplayDraftUrgentPromptConfig =
      _CompareReplayDraftPromptConfig(
        version: 'urgent_prompt_v1',
        title: 'Compare replay draft expiring',
        bodyTemplate:
            'Draft for {scope} expires soon. Remaining time: {remaining}. '
            'You can resume later or clear this draft now.',
        dismissButtonLabel: 'Dismiss',
        remindLaterButtonLabel: 'Remind me later',
        clearNowButtonLabel: 'Clear draft now',
        urgentThreshold: Duration(hours: 24),
        snooze: Duration(hours: 4),
        maxCountPerSession: 2,
        experimentVariant: null,
      );
  _CompareReplayDraftPromptConfig _compareReplayDraftUrgentPromptConfig =
      _defaultCompareReplayDraftUrgentPromptConfig;
  List<String> _compareReplayDraftUrgentPromptConfigFallbackReasons =
      const <String>[];
  static const int _maxRecentExportSearches = 12;
  static const String _compareReplayStatusUnavailable = 'Unavailable';
  static const String _compareReplayStatusManualRebuildRequired =
      'Unavailable (manual rebuild required)';
  static const String _compareReplayStatusManualDraft =
      'Draft (manual rebuild)';
  static const String _localResultsUnavailableMessage =
      'Local results are unavailable. Submit a search to retry.';
  static const String _searchUnavailableMessage =
      'Search could not be completed. Retry to try again.';
  static const List<String> _activityTraceActionOrder = [
    'search',
    'import',
    'favorite',
    'compare',
    'export',
    'governance',
    'other',
  ];

  final _searchController = TextEditingController();
  final _limitController = TextEditingController(text: '20');
  final _countryFilterController = TextEditingController();
  final _sourceFilterController = TextEditingController();
  final _categoryFilterController = TextEditingController();
  final _nutrientMinController = TextEditingController();
  final _nutrientMaxController = TextEditingController();
  final _favoriteTemplateNameController = TextEditingController();
  final Map<String, TextEditingController> _apiKeyControllers = {};
  final Map<String, TextEditingController> _queryControllers = {};
  final Map<String, TextEditingController> _pathControllers = {};
  final Map<String, bool> _isImportingById = {};
  late final AppMetaWriteQueue _appMetaWriteQueue;

  List<FoodItem> _results = const [];
  List<ImportLogEntry> _importLogs = const [];
  int _foodCount = 0;
  bool _isLoading = true;
  String? _resultsLoadError;
  String? _searchErrorMessage;
  String? _failedSearchQuery;
  int _searchRequestGeneration = 0;
  bool _isExportingSummaryJson = false;
  bool _isExportingDetailedCsv = false;
  bool _isExportingSnapshot = false;
  bool _isExportingCompareSummaryJson = false;
  bool _isExportingCompareDetailedCsv = false;
  bool _isSharingExport = false;
  bool _showAdvancedFilters = false;
  List<String> _recentSearches = const [];
  List<_ExportRecallCandidate> _recentExportRecalls = const [];
  final Map<String, String> _compareReplayStatuses = {};
  List<String> _lastCompareReplayMissingIds = const [];
  String? _lastCompareReplayStatusKey;
  final Map<String, int> _compareReplayRetryAttempts = {};
  final Map<String, int> _compareReplayDraftTimestamps = {};
  final Map<String, int> _compareReplayDraftUrgentPromptCounts = {};
  final Map<String, int> _compareReplayDraftUrgentPromptCooldownMs = {};
  Timer? _compareReplayDraftUrgentPromptDeferredTimer;
  int _compareReplayDraftUrgentPromptSessionIndex = 0;
  String? _compareReplayDraftUrgentPromptPriorityKey;
  final List<_FavoriteFoodRef> _favoriteFoods = [];
  final List<_FavoriteTemplate> _favoriteTemplates = [];
  final List<String> _compareFoodIds = [];
  final Map<String, FoodItem> _compareFoodItemsById = {};
  final List<_ActivityTraceEntry> _activityTrace = [];
  String _selectedActivityTraceAction = 'all';
  String? _favoriteCountryFilter;
  String? _favoriteSourceFilter;
  String? _favoriteCategoryFilter;
  _FavoriteSortMode _favoriteSortMode = _FavoriteSortMode.recent;
  String? _activeFavoriteTemplateId;
  String? _statusMessage;
  String? _exportStatusMessage;
  ExportArtifact? _latestExportArtifact;
  NutrientPreset? _selectedNutrientPreset;
  SearchSessionState _searchState = SearchSessionState.idle();
  EnrichmentQueueState _enrichmentState = EnrichmentQueueState.idle();
  StreamSubscription<EnrichmentQueueState>? _enrichmentSubscription;
  StreamSubscription<List<Map<String, Object?>>>? _activityTraceSubscription;
  Timer? _enrichmentTimer;
  bool _isShowingCompareReplayDraftUrgentPrompt = false;
  Timer? _compareUndoTimer;
  List<String> _compareUndoSnapshot = const [];

  @override
  void initState() {
    super.initState();
    _appMetaWriteQueue = AppMetaWriteQueue(widget.repository.setAppMeta);
    for (final descriptor in widget.importerDescriptors) {
      _apiKeyControllers[descriptor.importerId] = TextEditingController();
      _queryControllers[descriptor.importerId] = TextEditingController(
        text: descriptor.defaultQuery,
      );
      _pathControllers[descriptor.importerId] = TextEditingController();
      _isImportingById[descriptor.importerId] = false;
    }
    _enrichmentSubscription = widget.searchOrchestrator.currentEnrichmentState
        .listen(_handleEnrichmentState);
    _activityTraceSubscription = ActivityTraceStore(
      widget.repository,
    ).changes.listen(_replaceActivityTraceRecords);
    unawaited(_loadRecentSearches());
    unawaited(_loadRecentExportSearches());
    unawaited(_loadFavoritePersistence());
    unawaited(_loadActivityTrace());
    unawaited(_loadInitialResultsSafely());
  }

  @override
  void dispose() {
    _enrichmentTimer?.cancel();
    _compareReplayDraftUrgentPromptDeferredTimer?.cancel();
    _compareUndoTimer?.cancel();
    _enrichmentSubscription?.cancel();
    _activityTraceSubscription?.cancel();
    widget.searchOrchestrator.cancelEnrichment(_searchState.query);
    _searchController.dispose();
    _countryFilterController.dispose();
    _sourceFilterController.dispose();
    _categoryFilterController.dispose();
    _nutrientMinController.dispose();
    _nutrientMaxController.dispose();
    for (final controller in _apiKeyControllers.values) {
      controller.dispose();
    }
    for (final controller in _queryControllers.values) {
      controller.dispose();
    }
    for (final controller in _pathControllers.values) {
      controller.dispose();
    }
    _favoriteTemplateNameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _refreshResults([
    String? query,
    int? expectedSearchGeneration,
  ]) async {
    final refreshGeneration =
        expectedSearchGeneration ?? _searchRequestGeneration;
    if (!_isCurrentSearch(refreshGeneration)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _resultsLoadError = null;
    });

    final effectiveQuery = query ?? _searchController.text;
    final results = await widget.repository.searchFoods(effectiveQuery);
    if (!_isCurrentSearch(refreshGeneration)) {
      return;
    }
    final importLogs = await _loadImportLogsSafely();
    if (!_isCurrentSearch(refreshGeneration)) {
      return;
    }
    final count = await _loadFoodCountSafely();
    if (!_isCurrentSearch(refreshGeneration)) {
      return;
    }
    final nextCompareIds = _resolveCompareFoodIdsForResults(results);

    if (!_isCurrentSearch(refreshGeneration)) {
      return;
    }

    setState(() {
      _results = results;
      _importLogs = importLogs;
      if (count != null) {
        _foodCount = count;
      }
      _compareFoodIds
        ..clear()
        ..addAll(nextCompareIds);
      _isLoading = false;
    });

    if (nextCompareIds.isNotEmpty) {
      unawaited(_loadCompareFoodItemsForIds(nextCompareIds));
    }
  }

  Future<void> _loadInitialResultsSafely() async {
    try {
      await _refreshResults();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _resultsLoadError = _localResultsUnavailableMessage;
      });
    }
  }

  void _retryInitialResults() {
    unawaited(_loadInitialResultsSafely());
  }

  Future<void> _runImporter(ImporterDescriptor descriptor) async {
    final refreshGeneration = _searchRequestGeneration;
    final limit = int.tryParse(_limitController.text.trim()) ?? 20;
    final request = _buildImportRequest(descriptor, limit);
    unawaited(
      _appendActivityTrace(
        action: 'import',
        summary: 'Started import: ${descriptor.displayName}',
        details: {
          'importerId': descriptor.importerId,
          'query': request.query,
          'limit': limit,
        },
      ),
    );
    setState(() {
      _isImportingById[descriptor.importerId] = true;
      _statusMessage = null;
    });

    try {
      final summary = await widget.syncUseCase.syncSource(
        importerId: descriptor.importerId,
        request: request,
      );
      await _refreshResults(null, refreshGeneration);
      if (!mounted) {
        return;
      }
      unawaited(
        _appendActivityTrace(
          action: 'import',
          summary:
              'Imported ${summary.importedItems} from ${descriptor.displayName}',
          details: {
            'importerId': descriptor.importerId,
            'status': 'success',
            'imported': summary.importedItems,
            'query': request.query,
          },
        ),
      );
      setState(() {
        _statusMessage = summary.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      unawaited(
        _appendActivityTrace(
          action: 'import',
          summary: 'Import failed: ${descriptor.displayName}',
          details: {
            'importerId': descriptor.importerId,
            'status': 'failed',
            'query': request.query,
            'error': error.toString(),
          },
        ),
      );
      setState(() {
        _statusMessage = '${descriptor.displayName} import failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImportingById[descriptor.importerId] = false;
        });
      }
    }
  }

  ImportRequest _buildImportRequest(ImporterDescriptor descriptor, int limit) {
    return ImportRequest(
      query: _queryControllers[descriptor.importerId]?.text.trim() ?? '',
      apiKey: descriptor.requiresApiKey
          ? _apiKeyControllers[descriptor.importerId]?.text.trim()
          : null,
      datasetPath: descriptor.supportsDatasetPath
          ? _pathControllers[descriptor.importerId]?.text.trim()
          : null,
      limit: limit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredActivityTrace = _filteredActivityTrace;
    final activityTraceSessions = _activityTraceSessions(filteredActivityTrace);
    final activityTraceFilterOptions = _activityTraceFilterOptions;
    final recentExportRecalls = _recentExportRecalls;
    final sources = widget.entities
        .expand((entity) => entity.sources)
        .toList(growable: false);
    final recentSearches = _recentSearches;
    final comparedFoods = _selectedCompareFoods();
    final favoriteCountryOptions = _favoriteCountryFilterOptions;
    final favoriteSourceOptions = _favoriteSourceFilterOptions;
    final favoriteCategoryOptions = _favoriteCategoryFilterOptions;
    final favoriteTemplates = _favoriteTemplates;
    final filteredFavoriteFoods = _filteredFavoriteFoods();
    final groupedFavoriteFoods = _groupFavoritesByCountry(
      filteredFavoriteFoods,
    );
    final compareReplayStatus = _lastCompareReplayStatusKey == null
        ? null
        : _compareReplayStatuses[_lastCompareReplayStatusKey!]?.trim();
    final isCompareReplayDraft = _isCompareReplayDraftStatus(
      compareReplayStatus,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroPanel(foodCount: _foodCount),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Settings'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenOperations,
                      icon: const Icon(Icons.monitor_heart_outlined),
                      label: const Text('Operations'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: _handleSearchChanged,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: 'Search local database and official sources',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (recentSearches.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Recent searches',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearRecentSearches,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentSearches
                      .map(
                        (item) => InputChip(
                          label: Text(item),
                          onPressed: () => _loadRecentSearch(item),
                          onDeleted: () => _removeRecentSearch(item),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
              ],
              if (recentExportRecalls.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Recent export recalls',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_hasDraftCompareRecalls)
                      Semantics(
                        button: true,
                        label: 'Clear draft compare recalls',
                        child: TextButton(
                          onPressed: _clearDraftCompareRecalls,
                          child: const Text('Clear draft'),
                        ),
                      ),
                    if (_hasUnavailableCompareRecalls)
                      Semantics(
                        button: true,
                        label: 'Clear unavailable compare recalls',
                        child: TextButton(
                          onPressed: _clearUnavailableCompareRecalls,
                          child: const Text('Clear unavailable'),
                        ),
                      ),
                    Semantics(
                      button: true,
                      label: 'Clear all recent export recalls',
                      child: TextButton(
                        onPressed: _clearRecentExportRecalls,
                        child: const Text('Clear all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentExportRecalls
                      .map((entry) {
                        final replayChipLabel = _exportReplayLabel(entry);
                        return Semantics(
                          button: true,
                          liveRegion:
                              entry.scopeType == _ExportRecallScopeType.compare,
                          label: 'Recent export replay: $replayChipLabel',
                          child: InputChip(
                            avatar: Icon(_exportRecallIcon(entry.scopeType)),
                            label: Text(replayChipLabel),
                            onDeleted: () => _removeRecentExportRecall(entry),
                            onPressed: () => _replayExportRecall(entry),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
              ],
              if (_favoriteFoods.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Favorites',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearFavoriteFoods,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Favorite templates',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _favoriteTemplateNameController,
                            decoration: const InputDecoration(
                              hintText: 'Template name',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saveFavoriteTemplate,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                    if (favoriteTemplates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: favoriteTemplates
                            .map(
                              (template) => InputChip(
                                label: Text(template.name),
                                selected:
                                    _activeFavoriteTemplateId == template.id,
                                onSelected: (_) =>
                                    _applyFavoriteTemplate(template),
                                onDeleted: () =>
                                    _removeFavoriteTemplate(template.id),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (filteredFavoriteFoods.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              filteredFavoriteFoods.isNotEmpty &&
                                  !_isExportingCompareSummaryJson
                              ? () => _applyFavoriteFilterToCompare(
                                  filteredFavoriteFoods,
                                )
                              : null,
                          icon: const Icon(Icons.compare_arrows),
                          label: Text(
                            filteredFavoriteFoods.length >= _maxCompareFoods
                                ? 'Use top $_maxCompareFoods filtered favorites for compare'
                                : 'Use all filtered favorites for compare',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (favoriteCountryOptions.isNotEmpty) ...[
                  Text('Filter by country', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _favoriteCountryFilter == null,
                        onSelected: (selected) {
                          if (!selected) {
                            return;
                          }
                          setState(() {
                            _favoriteCountryFilter = null;
                            _activeFavoriteTemplateId = null;
                          });
                          unawaited(_persistFavoriteFilterState());
                        },
                      ),
                      ...favoriteCountryOptions
                          .take(_maxFavoriteCountryFilters)
                          .map(
                            (country) => ChoiceChip(
                              label: Text(country),
                              selected: _favoriteCountryFilter == country,
                              onSelected: (selected) {
                                setState(() {
                                  if (!selected ||
                                      _favoriteCountryFilter == country) {
                                    _favoriteCountryFilter = null;
                                  } else {
                                    _favoriteCountryFilter = country;
                                  }
                                  _activeFavoriteTemplateId = null;
                                });
                                unawaited(_persistFavoriteFilterState());
                              },
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (favoriteSourceOptions.isNotEmpty) ...[
                  Text('Filter by source', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _favoriteSourceFilter == null,
                        onSelected: (selected) {
                          if (!selected) {
                            return;
                          }
                          setState(() {
                            _favoriteSourceFilter = null;
                            _activeFavoriteTemplateId = null;
                          });
                          unawaited(_persistFavoriteFilterState());
                        },
                      ),
                      ...favoriteSourceOptions
                          .take(_maxFavoriteDimensionFilterOptions)
                          .map(
                            (source) => ChoiceChip(
                              label: Text(source),
                              selected: _favoriteSourceFilter == source,
                              onSelected: (selected) {
                                setState(() {
                                  if (!selected ||
                                      _favoriteSourceFilter == source) {
                                    _favoriteSourceFilter = null;
                                  } else {
                                    _favoriteSourceFilter = source;
                                  }
                                  _activeFavoriteTemplateId = null;
                                });
                                unawaited(_persistFavoriteFilterState());
                              },
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (favoriteCategoryOptions.isNotEmpty) ...[
                  Text('Filter by category', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _favoriteCategoryFilter == null,
                        onSelected: (selected) {
                          if (!selected) {
                            return;
                          }
                          setState(() {
                            _favoriteCategoryFilter = null;
                            _activeFavoriteTemplateId = null;
                          });
                          unawaited(_persistFavoriteFilterState());
                        },
                      ),
                      ...favoriteCategoryOptions
                          .take(_maxFavoriteDimensionFilterOptions)
                          .map(
                            (category) => ChoiceChip(
                              label: Text(category),
                              selected: _favoriteCategoryFilter == category,
                              onSelected: (selected) {
                                setState(() {
                                  if (!selected ||
                                      _favoriteCategoryFilter == category) {
                                    _favoriteCategoryFilter = null;
                                  } else {
                                    _favoriteCategoryFilter = category;
                                  }
                                  _activeFavoriteTemplateId = null;
                                });
                                unawaited(_persistFavoriteFilterState());
                              },
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('Sort', style: theme.textTheme.bodyMedium),
                    ChoiceChip(
                      label: const Text('Recent'),
                      selected: _favoriteSortMode == _FavoriteSortMode.recent,
                      onSelected: (selected) {
                        if (!selected) {
                          return;
                        }
                        setState(() {
                          _favoriteSortMode = _FavoriteSortMode.recent;
                          _activeFavoriteTemplateId = null;
                        });
                        unawaited(_persistFavoriteFilterState());
                      },
                    ),
                    ChoiceChip(
                      label: const Text('A → Z'),
                      selected: _favoriteSortMode == _FavoriteSortMode.alpha,
                      onSelected: (selected) {
                        if (!selected) {
                          return;
                        }
                        setState(() {
                          _favoriteSortMode = _FavoriteSortMode.alpha;
                          _activeFavoriteTemplateId = null;
                        });
                        unawaited(_persistFavoriteFilterState());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filteredFavoriteFoods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('No favorites match this filter'),
                  )
                else
                  ...groupedFavoriteFoods.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value
                                .map(
                                  (favorite) => InputChip(
                                    avatar: const Icon(Icons.star, size: 16),
                                    label: Text(
                                      favorite.sourceName.isEmpty
                                          ? favorite.name
                                          : '${favorite.name} • ${favorite.sourceName}',
                                    ),
                                    onPressed: () => _replayFavorite(favorite),
                                    onDeleted: () =>
                                        _removeFavoriteById(favorite.foodId),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              if (_compareFoodIds.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Comparison (${_compareFoodIds.length}/$_maxCompareFoods)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_compareFoodIds.length >= 2) ...[
                      FilledButton(
                        onPressed: _isExportingCompareSummaryJson
                            ? null
                            : _exportFavoriteComparisonSummaryJson,
                        child: _isExportingCompareSummaryJson
                            ? const SizedBox(
                                height: 20,
                                width: 104,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : const Text('Export JSON'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isExportingCompareDetailedCsv
                            ? null
                            : _exportFavoriteComparisonDetailedCsv,
                        child: _isExportingCompareDetailedCsv
                            ? const SizedBox(
                                height: 20,
                                width: 104,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : const Text('Export CSV'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: _clearCompareSelection,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildComparisonPanel(context, comparedFoods),
                const SizedBox(height: 20),
              ],
              if (_activityTrace.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Activity trace',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearActivityTrace,
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activityTraceSessions.length > 1)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activityTraceSessions
                        .map(
                          (session) => _buildActivityTraceSessionSummaryChip(
                            context,
                            session,
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (activityTraceSessions.length > 1) const SizedBox(height: 8),
                ...activityTraceSessions.map(
                  (session) => _buildActivityTraceSession(context, session),
                ),
                if (activityTraceSessions.isEmpty) ...[
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.filter_alt_off_outlined),
                      title: Text('No matching activity traces'),
                      subtitle: Text('Try another activity action filter.'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (activityTraceFilterOptions.length > 1)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activityTraceFilterOptions
                        .map(
                          (action) => ChoiceChip(
                            label: Text(_activityTraceActionLabel(action)),
                            selected: _selectedActivityTraceAction == action,
                            onSelected: (_) {
                              setState(() {
                                _selectedActivityTraceAction = action;
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 8),
                if (filteredActivityTrace.isNotEmpty)
                  ...filteredActivityTrace.map(
                    (entry) => _buildActivityTraceItem(context, entry),
                  )
                else
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.filter_alt_off_outlined),
                      title: Text('No matching activity traces'),
                      subtitle: Text('Try another activity action filter.'),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              _AdvancedFiltersCard(
                expanded: _showAdvancedFilters,
                selectedPreset: _selectedNutrientPreset,
                countryController: _countryFilterController,
                sourceController: _sourceFilterController,
                categoryController: _categoryFilterController,
                minController: _nutrientMinController,
                maxController: _nutrientMaxController,
                onToggle: () {
                  setState(() {
                    _showAdvancedFilters = !_showAdvancedFilters;
                  });
                },
                onPresetChanged: (preset) {
                  setState(() {
                    _selectedNutrientPreset = preset;
                  });
                },
                onApply: () => _runSearch(_searchController.text),
                onClear: _clearAdvancedFilters,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    title: 'Persisted foods',
                    value: '$_foodCount',
                    subtitle: 'Stored in local SQLite',
                  ),
                  _StatCard(
                    title: 'Sources ready',
                    value:
                        '${sources.where((source) => source.isIntegrated).length}',
                    subtitle: '${sources.length} sources tracked',
                  ),
                  _StatCard(
                    title: 'Visible results',
                    value: '${_results.length}',
                    subtitle: _searchState.query.isEmpty
                        ? 'No query submitted'
                        : 'Query: ${_searchState.query}',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: const Color(0xFFF3FBFD),
                child: ListTile(
                  leading: const Icon(Icons.travel_explore),
                  title: const Text('Search status'),
                  subtitle: Text(_searchStatusText()),
                ),
              ),
              if (_searchErrorMessage != null) ...[
                const SizedBox(height: 12),
                Card(
                  key: const ValueKey('home_search_error'),
                  color: const Color(0xFFFFF4F2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Search unavailable',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_searchErrorMessage!),
                        if (_failedSearchQuery != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _retryFailedSearch,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry search'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (_enrichmentState.status != EnrichmentStatus.idle) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFEAF7EF),
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_motion_outlined),
                    title: const Text('Background enrichment'),
                    subtitle: Text(_enrichmentStatusText()),
                  ),
                ),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFFE2F8F5),
                  child: ListTile(
                    leading: const Icon(Icons.sync_alt),
                    title: const Text('Last import status'),
                    subtitle: Text(_statusMessage!),
                  ),
                ),
              ],
              if (_exportStatusMessage != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFF4F8FF),
                  child: ListTile(
                    leading: const Icon(Icons.file_download_done_outlined),
                    title: const Text('Last export status'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          container: true,
                          liveRegion: true,
                          label:
                              'Export status message: ${_exportStatusMessage!}',
                          child: Text(_exportStatusMessage!),
                        ),
                        if (_lastCompareReplayMissingIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            liveRegion: true,
                            container: true,
                            label:
                                'Missing IDs for compare replay: ${_lastCompareReplayMissingIds.join(", ")}',
                            child: Text(
                              'Missing IDs: ${_lastCompareReplayMissingIds.join(", ")}',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              button: true,
                              enabled:
                                  !_isCompareReplayRetryLimitReached() &&
                                  !isCompareReplayDraft,
                              label: isCompareReplayDraft
                                  ? 'Compare replay draft mode active'
                                  : _isCompareReplayRetryLimitReached()
                                  ? 'Retry limit reached'
                                  : 'Retry missing compare items',
                              child: TextButton(
                                onPressed:
                                    _isCompareReplayRetryLimitReached() ||
                                        isCompareReplayDraft
                                    ? null
                                    : _retryMissingCompareReplayItems,
                                child: Text(
                                  isCompareReplayDraft
                                      ? 'Draft mode active'
                                      : _isCompareReplayRetryLimitReached()
                                      ? 'Retry limit reached'
                                      : 'Retry missing items '
                                            '(${_compareReplayRetryCountForCurrent()}/$_maxCompareReplayRetryAttempts)',
                                ),
                              ),
                            ),
                          ),
                          if (_isCompareReplayRetryLimitReached() ||
                              isCompareReplayDraft) ...[
                            const SizedBox(height: 8),
                            if (isCompareReplayDraft &&
                                _lastCompareReplayStatusKey != null &&
                                _isCompareReplayDraftUrgent(
                                  _lastCompareReplayStatusKey!,
                                )) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Semantics(
                                  liveRegion: true,
                                  label:
                                      'Compare replay draft urgent warning: this draft expires within 24 hours.',
                                  child: Text(
                                    'Urgent: this draft expires within 24 hours.',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (isCompareReplayDraft &&
                                _lastCompareReplayStatusKey != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Semantics(
                                  liveRegion: true,
                                  label:
                                      'Compare replay draft remaining time: ${_compareReplayDraftRemainingLabel(_lastCompareReplayStatusKey!)}',
                                  child: Text(
                                    'Draft remaining: ${_compareReplayDraftRemainingLabel(_lastCompareReplayStatusKey!)}',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Semantics(
                                  button: true,
                                  label: 'Resume compare replay draft',
                                  child: TextButton(
                                    onPressed: _resumeCompareReplayDraft,
                                    child: const Text('Resume draft'),
                                  ),
                                ),
                              ),
                              if (_isCompareReplayDraftUrgent(
                                _lastCompareReplayStatusKey!,
                              )) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Semantics(
                                    button: true,
                                    label: 'Clear compare replay draft now',
                                    child: TextButton(
                                      onPressed:
                                          _clearCurrentCompareReplayDraftNow,
                                      child: const Text('Clear draft now'),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Semantics(
                                button: true,
                                label: 'Reset compare replay retry limit',
                                child: TextButton(
                                  onPressed: _resetCompareReplayRetryLimit,
                                  child: const Text('Reset retry limit'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Semantics(
                                button: true,
                                label: 'Rebuild compare manually',
                                child: TextButton(
                                  onPressed:
                                      _confirmRebuildCompareReplayManually,
                                  child: const Text('Rebuild compare manually'),
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (isCompareReplayDraft &&
                            _lastCompareReplayMissingIds.isEmpty &&
                            _lastCompareReplayStatusKey != null) ...[
                          const SizedBox(height: 8),
                          if (_isCompareReplayDraftUrgent(
                            _lastCompareReplayStatusKey!,
                          ))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Semantics(
                                liveRegion: true,
                                label:
                                    'Compare replay draft urgent warning: this draft expires within 24 hours.',
                                child: Text(
                                  'Urgent: this draft expires within 24 hours.',
                                ),
                              ),
                            ),
                          if (_isCompareReplayDraftUrgent(
                            _lastCompareReplayStatusKey!,
                          ))
                            const SizedBox(height: 8),
                          Semantics(
                            liveRegion: true,
                            label:
                                'Draft remaining after draft recovery: ${_compareReplayDraftRemainingLabel(_lastCompareReplayStatusKey!)}',
                            child: Text(
                              'Draft remaining: ${_compareReplayDraftRemainingLabel(_lastCompareReplayStatusKey!)}',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              button: true,
                              label: 'Resume compare replay draft',
                              child: TextButton(
                                onPressed: _resumeCompareReplayDraft,
                                child: const Text('Resume draft'),
                              ),
                            ),
                          ),
                          if (_isCompareReplayDraftUrgent(
                            _lastCompareReplayStatusKey!,
                          )) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Semantics(
                                button: true,
                                label: 'Clear compare replay draft now',
                                child: TextButton(
                                  onPressed: _clearCurrentCompareReplayDraftNow,
                                  child: const Text('Clear draft now'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Source controls',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.importerDescriptors.map(
                (descriptor) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildImporterCard(descriptor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Import history',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_importLogs.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('No imports recorded yet'),
                    subtitle: Text(
                      'Each successful or failed import attempt will appear here.',
                    ),
                  ),
                )
              else
                ..._importLogs.map((entry) => _ImportLogCard(entry: entry)),
              const SizedBox(height: 24),
              Text(
                'Source roadmap',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.entities.map(
                (entity) => _AdministrativeEntityCard(entity: entity),
              ),
              const SizedBox(height: 24),
              Text(
                'Local search results',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ExportCard(
                onExportSummaryJson: _isExportingSummaryJson
                    ? null
                    : _exportSearchSummaryJson,
                onExportDetailedCsv: _isExportingDetailedCsv
                    ? null
                    : _exportSearchDetailedCsv,
                onExportSnapshot: _isExportingSnapshot
                    ? null
                    : _exportDatabaseSnapshot,
                isExportingSummaryJson: _isExportingSummaryJson,
                isExportingDetailedCsv: _isExportingDetailedCsv,
                isExportingSnapshot: _isExportingSnapshot,
                latestArtifact: _latestExportArtifact,
                isSharing: _isSharingExport,
                onShareLatest: _latestExportArtifact == null || _isSharingExport
                    ? null
                    : _shareLatestExport,
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_resultsLoadError != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Local results unavailable',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_resultsLoadError!),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _retryInitialResults,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry local results'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_results.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Local database is empty'),
                    subtitle: Text(
                      'Run an importer first, then search the persisted results here.',
                    ),
                  ),
                )
              else
                ..._results.map(
                  (food) => _FoodCard(
                    food: food,
                    onTap: () => _showFoodDetails(food.id),
                    isFavorite: _isFavorite(food.id),
                    onToggleFavorite: () => _toggleFavorite(food),
                    isCompared: _isCompared(food.id),
                    onToggleCompare: () => _isCompared(food.id)
                        ? _removeCompareWithUndo(context: context, food: food)
                        : _toggleCompare(food),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSearch(String rawQuery) async {
    final trimmedQuery = rawQuery.trim();
    final searchGeneration = ++_searchRequestGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _resultsLoadError = null;
        _searchErrorMessage = null;
        _failedSearchQuery = null;
        _enrichmentState = EnrichmentQueueState.idle();
      });
    }

    try {
      unawaited(
        _appendActivityTrace(
          action: 'search',
          summary: trimmedQuery.isEmpty
              ? 'Search skipped: empty query'
              : 'Search: $trimmedQuery',
          details: {
            'query': trimmedQuery,
            'mode': _hasAdvancedFilters ? 'advanced' : 'standard',
            'limit': int.tryParse(_limitController.text.trim()) ?? 20,
          },
        ),
      );
      await _recordRecentSearch(rawQuery);
      if (!_isCurrentSearch(searchGeneration)) {
        return;
      }

      _enrichmentTimer?.cancel();
      await widget.searchOrchestrator.cancelEnrichment(_searchState.query);
      if (!_isCurrentSearch(searchGeneration)) {
        return;
      }
      if (_hasAdvancedFilters) {
        await _runAdvancedSearch(rawQuery, searchGeneration);
        return;
      }

      await for (final state in widget.searchOrchestrator.search(rawQuery)) {
        final importLogs = await _loadImportLogsSafely();
        final count = await _loadFoodCountSafely();
        if (!_isCurrentSearch(searchGeneration)) {
          return;
        }
        setState(() {
          _searchState = state;
          _results = state.combinedResults;
          _importLogs = importLogs;
          if (count != null) {
            _foodCount = count;
          }
          _compareFoodIds
            ..clear()
            ..addAll(_resolveCompareFoodIdsForResults(state.combinedResults));
          _isLoading = state.status == SearchStatus.fetching;
        });
        _scheduleEnrichmentIfNeeded(state);
      }
    } catch (error) {
      if (!_isCurrentSearch(searchGeneration)) {
        return;
      }
      unawaited(
        _appendActivityTrace(
          action: 'search',
          summary: 'Search failed: $trimmedQuery',
          details: {'query': trimmedQuery, 'error': error.toString()},
        ),
      );
      setState(() {
        _isLoading = false;
        _enrichmentState = EnrichmentQueueState.idle();
        _searchErrorMessage = _searchUnavailableMessage;
        _failedSearchQuery = trimmedQuery;
        _searchState = SearchSessionState(
          query: trimmedQuery,
          localResults: _results,
          foregroundFetchedResults: const [],
          combinedResults: _results,
          status: SearchStatus.failed,
          activeSources: const [],
          message: 'Search failed.',
        );
      });
    }
  }

  bool get _hasAdvancedFilters {
    return _countryFilterController.text.trim().isNotEmpty ||
        _sourceFilterController.text.trim().isNotEmpty ||
        _categoryFilterController.text.trim().isNotEmpty ||
        _selectedNutrientPreset != null ||
        _nutrientMinController.text.trim().isNotEmpty ||
        _nutrientMaxController.text.trim().isNotEmpty;
  }

  Future<List<ImportLogEntry>> _loadImportLogsSafely() async {
    try {
      return await widget.repository.getImportLogs(limit: 10);
    } catch (_) {
      // Import-log history is supplemental; preserve the last visible state.
      return _importLogs;
    }
  }

  Future<int?> _loadFoodCountSafely() async {
    try {
      return await widget.repository.countFoods();
    } catch (_) {
      // The count card is supplemental; preserve the last known value.
      return null;
    }
  }

  Future<void> _runAdvancedSearch(String rawQuery, int searchGeneration) async {
    if (!_isCurrentSearch(searchGeneration)) {
      return;
    }
    setState(() {
      _isLoading = true;
      _enrichmentState = EnrichmentQueueState.idle();
    });
    final query = _advancedQuery(rawQuery);
    final results = await widget.repository.searchFoodsAdvanced(query);
    final importLogs = await _loadImportLogsSafely();
    final count = await _loadFoodCountSafely();
    if (!_isCurrentSearch(searchGeneration)) {
      return;
    }
    setState(() {
      _searchState = SearchSessionState(
        query: rawQuery.trim(),
        localResults: results,
        foregroundFetchedResults: const [],
        combinedResults: results,
        status: SearchStatus.local,
        activeSources: const [],
        message: 'Advanced local filters applied.',
      );
      _results = results;
      _importLogs = importLogs;
      if (count != null) {
        _foodCount = count;
      }
      _compareFoodIds
        ..clear()
        ..addAll(_resolveCompareFoodIdsForResults(results));
      _isLoading = false;
      _searchErrorMessage = null;
      _failedSearchQuery = null;
    });
  }

  bool _isCurrentSearch(int searchGeneration) {
    return mounted && searchGeneration == _searchRequestGeneration;
  }

  FoodSearchQuery _advancedQuery(String rawQuery) {
    final preset = _selectedNutrientPreset;
    final ranges = <NutrientRangeFilter>[
      if (preset != null)
        NutrientRangeFilter(
          canonicalLabel: preset.canonicalLabel,
          unit: preset.unit,
          min: double.tryParse(_nutrientMinController.text.trim()),
          max: double.tryParse(_nutrientMaxController.text.trim()),
        ),
    ];
    return FoodSearchQuery(
      text: rawQuery.trim(),
      countries: _splitFilter(_countryFilterController.text),
      importerIds: _splitFilter(_sourceFilterController.text),
      categories: _splitFilter(_categoryFilterController.text),
      nutrientRanges: ranges,
    );
  }

  List<String> _splitFilter(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void _clearAdvancedFilters() {
    setState(() {
      _countryFilterController.clear();
      _sourceFilterController.clear();
      _categoryFilterController.clear();
      _nutrientMinController.clear();
      _nutrientMaxController.clear();
      _selectedNutrientPreset = null;
    });
  }

  Future<void> _loadRecentSearches() async {
    String? rawValue;
    try {
      rawValue = await widget.repository.getAppMeta(_recentSearchesMetaKey);
    } catch (_) {
      // A recent-search metadata read must not fail HomePage startup.
      return;
    }
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List<dynamic>) {
        return;
      }
      final normalized = <String>[];
      for (final value in decoded) {
        if (value is! String) {
          continue;
        }
        final query = value.trim();
        if (query.isEmpty) {
          continue;
        }
        normalized.add(query);
      }
      final deduped = <String>[];
      for (final query in normalized) {
        final isDuplicate = deduped.any(
          (item) => item.toLowerCase() == query.toLowerCase(),
        );
        if (!isDuplicate) {
          deduped.add(query);
        }
      }

      final limited = deduped.take(_maxRecentSearches).toList(growable: false);
      if (mounted) {
        setState(() {
          _recentSearches = limited;
        });
      }
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  Future<void> _loadRecentExportSearches() async {
    await _loadCompareReplayDraftPromptConfig();
    String? storedRaw;
    try {
      storedRaw = await widget.repository.getAppMeta(
        _recentExportRecallsMetaKey,
      );
    } catch (_) {
      // Treat an unavailable recall cache as a miss and use export history.
    }
    if (storedRaw != null) {
      final storedRecalls = _loadExportRecallsFromMeta(storedRaw);
      if (storedRecalls != null) {
        if (mounted) {
          setState(() {
            _recentExportRecalls = storedRecalls;
            _compareReplayStatuses.clear();
          });
        }
        await _loadRecentExportReplayDraftTimestamps(storedRecalls);
        await _loadRecentExportReplayStatuses(storedRecalls);
        await _archiveExpiredCompareReplayDraftStatuses();
        _resetUrgentCompareReplayDraftPromptScheduler();
        return;
      }
    }

    List<ExportHistoryEntry> exportHistory;
    try {
      exportHistory = await widget.repository.getExportHistory(
        limit: _maxRecentExportSearches,
      );
    } catch (_) {
      // Export history is an optional fallback; keep HomePage startup healthy.
      return;
    }
    if (!mounted) {
      return;
    }
    final recalls = <_ExportRecallCandidate>[];
    for (final entry in exportHistory) {
      final recall = _extractExportRecallFromScope(entry.scopeLabel);
      if (recall == null) {
        continue;
      }
      final duplicate = recalls.any(
        (item) =>
            item.scopeType == recall.scopeType &&
            item.scopeValue.toLowerCase() == recall.scopeValue.toLowerCase(),
      );
      if (duplicate) {
        continue;
      }
      recalls.add(recall);
      if (recalls.length >= _maxRecentExportSearches) {
        break;
      }
    }

    setState(() {
      _recentExportRecalls = recalls;
    });
    await _persistRecentExportRecalls(recalls);
    await _loadRecentExportReplayDraftTimestamps(recalls);
    await _loadRecentExportReplayStatuses(recalls);
    await _archiveExpiredCompareReplayDraftStatuses();
    _resetUrgentCompareReplayDraftPromptScheduler();
  }

  void _scheduleUrgentCompareReplayDraftPrompt() {
    if (!mounted || _isShowingCompareReplayDraftUrgentPrompt) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showUrgentCompareReplayDraftPrompt());
    });
  }

  Future<void> _showUrgentCompareReplayDraftPrompt() async {
    if (!mounted || _isShowingCompareReplayDraftUrgentPrompt) {
      return;
    }
    final statusKey = _firstUrgentCompareReplayDraftStatusKey();
    if (statusKey == null) {
      return;
    }
    final promptSessionIndex = ++_compareReplayDraftUrgentPromptSessionIndex;
    final suppressReason = _urgentCompareReplayDraftPromptSuppressReason(
      statusKey,
    );
    if (suppressReason != null) {
      unawaited(
        _appendActivityTrace(
          action: 'compare',
          summary: 'Suppressed compare replay draft expiry prompt',
          details: _compareReplayDraftPromptTraceDetails(
            scopeKey: statusKey,
            userAction: _CompareReplayDraftPromptUserAction.suppressed,
            remainingMs: _compareReplayDraftRemainingMs(statusKey),
            suppressReason: suppressReason,
            shownCount: _compareReplayDraftUrgentPromptCounts[statusKey],
            cooldownMs: _compareReplayDraftUrgentPromptCooldownMs[statusKey],
            promptConfigVersion: _compareReplayDraftUrgentPromptConfig.version,
            promptExperimentVariant:
                _compareReplayDraftUrgentPromptConfig.experimentVariant,
            promptSessionIndex: promptSessionIndex,
            trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
          ),
        ),
      );
      return;
    }
    _recordUrgentCompareReplayDraftPromptShown(statusKey);
    final promptTimestampMs = DateTime.now().millisecondsSinceEpoch;
    final promptInstanceId =
        '${statusKey}_${promptTimestampMs}_$promptSessionIndex';
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Showed compare replay draft expiry prompt',
        details: _compareReplayDraftPromptTraceDetails(
          scopeKey: statusKey,
          userAction: _CompareReplayDraftPromptUserAction.shown,
          remainingMs: _compareReplayDraftRemainingMs(statusKey),
          shownCount: _compareReplayDraftUrgentPromptCounts[statusKey],
          promptInstanceId: promptInstanceId,
          promptConfigVersion: _compareReplayDraftUrgentPromptConfig.version,
          promptExperimentVariant:
              _compareReplayDraftUrgentPromptConfig.experimentVariant,
          promptSessionIndex: promptSessionIndex,
          trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
        ),
      ),
    );
    _isShowingCompareReplayDraftUrgentPrompt = true;
    try {
      final scopeLabel = _compareReplayDraftScopeLabel(statusKey);
      final remaining = _compareReplayDraftRemainingLabel(statusKey);
      final dismissResult =
          await showDialog<_CompareReplayDraftPromptDialogResult>(
            context: context,
            builder: (dialogContext) => PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _CompareReplayDraftPromptDialogResult.dismissedByNavigation,
                );
              },
              child: AlertDialog(
                title: Text(_compareReplayDraftUrgentPromptConfig.title),
                content: Text(
                  _compareReplayDraftUrgentPromptConfig.buildBody(
                    scopeLabel: scopeLabel,
                    remaining: remaining,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _CompareReplayDraftPromptDialogResult.dismissedByUser,
                    ),
                    child: Text(
                      _compareReplayDraftUrgentPromptConfig.dismissButtonLabel,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _CompareReplayDraftPromptDialogResult.remindLater,
                    ),
                    child: Text(
                      _compareReplayDraftUrgentPromptConfig
                          .remindLaterButtonLabel,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _CompareReplayDraftPromptDialogResult.clearNow,
                    ),
                    child: Text(
                      _compareReplayDraftUrgentPromptConfig.clearNowButtonLabel,
                    ),
                  ),
                ],
              ),
            ),
          );
      if (!mounted) {
        unawaited(
          _appendActivityTrace(
            action: 'compare',
            summary: 'Compare replay draft expiry prompt aborted',
            details: _compareReplayDraftPromptTraceDetails(
              scopeKey: statusKey,
              userAction: _CompareReplayDraftPromptUserAction.abortedUnmounted,
              remainingMs: _compareReplayDraftRemainingMs(statusKey),
              reason: _CompareReplayDraftPromptDismissReason.unmounted,
              promptInstanceId: promptInstanceId,
              promptConfigVersion:
                  _compareReplayDraftUrgentPromptConfig.version,
              promptExperimentVariant:
                  _compareReplayDraftUrgentPromptConfig.experimentVariant,
              promptSessionIndex: promptSessionIndex,
              trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
            ),
          ),
        );
        return;
      }

      if (dismissResult == _CompareReplayDraftPromptDialogResult.clearNow) {
        await _clearCompareReplayDraftNowByKey(
          statusKey,
          fromUrgentPrompt: true,
          promptInstanceId: promptInstanceId,
          promptSessionIndex: promptSessionIndex,
        );
        return;
      }

      if (dismissResult == _CompareReplayDraftPromptDialogResult.remindLater) {
        _deferUrgentCompareReplayDraftPrompt(statusKey);
        unawaited(
          _appendActivityTrace(
            action: 'compare',
            summary: 'Deferred compare replay draft expiry prompt',
            details: _compareReplayDraftPromptTraceDetails(
              scopeKey: statusKey,
              userAction: _CompareReplayDraftPromptUserAction.remindLater,
              remainingMs: _compareReplayDraftRemainingMs(statusKey),
              deferCount: _compareReplayDraftUrgentPromptCounts[statusKey],
              promptInstanceId: promptInstanceId,
              promptConfigVersion:
                  _compareReplayDraftUrgentPromptConfig.version,
              promptExperimentVariant:
                  _compareReplayDraftUrgentPromptConfig.experimentVariant,
              promptSessionIndex: promptSessionIndex,
              trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
            ),
          ),
        );
        return;
      }
      if (dismissResult ==
          _CompareReplayDraftPromptDialogResult.dismissedByUser) {
        _deferUrgentCompareReplayDraftPrompt(statusKey);
        unawaited(
          _appendActivityTrace(
            action: 'compare',
            summary: 'Dismissed compare replay draft expiry prompt',
            details: _compareReplayDraftPromptTraceDetails(
              scopeKey: statusKey,
              userAction: _CompareReplayDraftPromptUserAction.dismissedByUser,
              remainingMs: _compareReplayDraftRemainingMs(statusKey),
              deferCount: _compareReplayDraftUrgentPromptCounts[statusKey],
              promptInstanceId: promptInstanceId,
              promptConfigVersion:
                  _compareReplayDraftUrgentPromptConfig.version,
              promptExperimentVariant:
                  _compareReplayDraftUrgentPromptConfig.experimentVariant,
              promptSessionIndex: promptSessionIndex,
              trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
            ),
          ),
        );
        return;
      }
      if (dismissResult ==
          _CompareReplayDraftPromptDialogResult.dismissedByNavigation) {
        _deferUrgentCompareReplayDraftPrompt(statusKey);
        unawaited(
          _appendActivityTrace(
            action: 'compare',
            summary: 'Dismissed compare replay draft expiry prompt',
            details: _compareReplayDraftPromptTraceDetails(
              scopeKey: statusKey,
              userAction: _CompareReplayDraftPromptUserAction.dismissedNoAction,
              remainingMs: _compareReplayDraftRemainingMs(statusKey),
              deferCount: _compareReplayDraftUrgentPromptCounts[statusKey],
              reason:
                  _CompareReplayDraftPromptDismissReason.dismissedByNavigation,
              promptInstanceId: promptInstanceId,
              promptConfigVersion:
                  _compareReplayDraftUrgentPromptConfig.version,
              promptExperimentVariant:
                  _compareReplayDraftUrgentPromptConfig.experimentVariant,
              promptSessionIndex: promptSessionIndex,
              trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
            ),
          ),
        );
        return;
      }
      if (dismissResult == null ||
          dismissResult ==
              _CompareReplayDraftPromptDialogResult.dismissedByBackground) {
        _deferUrgentCompareReplayDraftPrompt(statusKey);
        unawaited(
          _appendActivityTrace(
            action: 'compare',
            summary: 'Dismissed compare replay draft expiry prompt',
            details: _compareReplayDraftPromptTraceDetails(
              scopeKey: statusKey,
              userAction: _CompareReplayDraftPromptUserAction.dismissedNoAction,
              remainingMs: _compareReplayDraftRemainingMs(statusKey),
              deferCount: _compareReplayDraftUrgentPromptCounts[statusKey],
              reason:
                  _CompareReplayDraftPromptDismissReason.dismissedByBackground,
              promptInstanceId: promptInstanceId,
              promptConfigVersion:
                  _compareReplayDraftUrgentPromptConfig.version,
              promptExperimentVariant:
                  _compareReplayDraftUrgentPromptConfig.experimentVariant,
              promptSessionIndex: promptSessionIndex,
              trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
            ),
          ),
        );
        return;
      }
      _deferUrgentCompareReplayDraftPrompt(statusKey);
      unawaited(
        _appendActivityTrace(
          action: 'compare',
          summary: 'Dismissed compare replay draft expiry prompt',
          details: _compareReplayDraftPromptTraceDetails(
            scopeKey: statusKey,
            userAction: _CompareReplayDraftPromptUserAction.dismissedNoAction,
            remainingMs: _compareReplayDraftRemainingMs(statusKey),
            deferCount: _compareReplayDraftUrgentPromptCounts[statusKey],
            reason:
                _CompareReplayDraftPromptDismissReason.dismissedByBackground,
            promptInstanceId: promptInstanceId,
            promptConfigVersion: _compareReplayDraftUrgentPromptConfig.version,
            promptExperimentVariant:
                _compareReplayDraftUrgentPromptConfig.experimentVariant,
            trigger: _CompareReplayDraftPromptTrigger.urgentPrompt,
          ),
        ),
      );
    } finally {
      _isShowingCompareReplayDraftUrgentPrompt = false;
    }
  }

  String? _firstUrgentCompareReplayDraftStatusKey() {
    final urgentKeys = _orderedUrgentCompareReplayDraftStatusKeys();
    if (urgentKeys.isEmpty) {
      _compareReplayDraftUrgentPromptPriorityKey = null;
      return null;
    }
    final priorityKey = _compareReplayDraftUrgentPromptPriorityKey;
    final selectedKey = priorityKey != null && urgentKeys.contains(priorityKey)
        ? priorityKey
        : urgentKeys.first;
    _compareReplayDraftUrgentPromptPriorityKey = selectedKey;
    return selectedKey;
  }

  bool _isEligibleUrgentCompareReplayDraftStatusKey(String statusKey) {
    return _isCompareReplayDraftStatus(_compareReplayStatuses[statusKey]) &&
        _isCompareReplayDraftUrgent(statusKey);
  }

  List<String> _orderedUrgentCompareReplayDraftStatusKeys() {
    final keys = <String>[];
    if (_lastCompareReplayStatusKey != null &&
        _isEligibleUrgentCompareReplayDraftStatusKey(
          _lastCompareReplayStatusKey!,
        )) {
      keys.add(_lastCompareReplayStatusKey!);
    }
    for (final recall in _recentExportRecalls) {
      if (recall.scopeType != _ExportRecallScopeType.compare) {
        continue;
      }
      final statusKey = _recentExportRecallKey(recall);
      if (statusKey == _lastCompareReplayStatusKey) {
        continue;
      }
      if (_isEligibleUrgentCompareReplayDraftStatusKey(statusKey)) {
        keys.add(statusKey);
      }
    }
    return keys;
  }

  String _compareReplayDraftScopeLabel(String statusKey) {
    for (final recall in _recentExportRecalls) {
      if (_recentExportRecallKey(recall) == statusKey) {
        return _exportReplayLabel(recall);
      }
    }
    return 'compare replay draft';
  }

  Future<void> _loadCompareReplayDraftPromptConfig() async {
    String? rawValue;
    try {
      rawValue = await widget.repository.getAppMeta(
        _compareReplayDraftPromptConfigMetaKey,
      );
    } catch (_) {
      // Keep the in-memory default when configuration storage is unavailable.
      return;
    }
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    final normalizedRawValue = rawValue.trim();
    if (AppMetaPayloadBudget.utf8ByteLength(normalizedRawValue) >
        _maxAppMetaValueLength) {
      const fallbackReasons = [
        'compare_replay_draft_prompt_config exceeds max app_meta payload length; '
            'fallback to default',
      ];
      if (!mounted) {
        return;
      }
      setState(() {
        _compareReplayDraftUrgentPromptConfig =
            _defaultCompareReplayDraftUrgentPromptConfig;
        _compareReplayDraftUrgentPromptConfigFallbackReasons =
            List<String>.from(fallbackReasons);
      });
      _appendCompareReplayDraftPromptConfigFallbackTrace(
        promptConfigVersion:
            _defaultCompareReplayDraftUrgentPromptConfig.version,
        fallbackReasons: fallbackReasons,
      );
      return;
    }
    try {
      final decoded = jsonDecode(normalizedRawValue);
      if (decoded is! Map) {
        throw const FormatException(
          'compare_replay_draft_prompt_config must be an object',
        );
      }
      final fallbackReasons = <String>[];
      final parsedConfig = _parseCompareReplayDraftPromptConfig(
        decoded,
        fallbackReasons: fallbackReasons,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _compareReplayDraftUrgentPromptConfig = parsedConfig;
        _compareReplayDraftUrgentPromptConfigFallbackReasons =
            List<String>.from(fallbackReasons);
      });
      if (fallbackReasons.isNotEmpty) {
        _appendCompareReplayDraftPromptConfigFallbackTrace(
          promptConfigVersion: parsedConfig.version,
          fallbackReasons: fallbackReasons,
        );
      }
    } catch (_) {
      const fallbackReasons = [
        'compare_replay_draft_prompt_config malformed; fallback to default',
      ];
      if (!mounted) {
        return;
      }
      setState(() {
        _compareReplayDraftUrgentPromptConfig =
            _defaultCompareReplayDraftUrgentPromptConfig;
        _compareReplayDraftUrgentPromptConfigFallbackReasons =
            List<String>.from(fallbackReasons);
      });
      _appendCompareReplayDraftPromptConfigFallbackTrace(
        promptConfigVersion:
            _defaultCompareReplayDraftUrgentPromptConfig.version,
        fallbackReasons: fallbackReasons,
      );
    }
  }

  void _appendCompareReplayDraftPromptConfigFallbackTrace({
    required String promptConfigVersion,
    required List<String> fallbackReasons,
  }) {
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Compare replay draft prompt config fallback applied',
        details: {
          'activityTraceSchemaVersion':
              _activityTraceCompareReplayDraftPromptSchemaVersion,
          'promptConfigVersion': promptConfigVersion,
          'promptConfigFallback': true,
          'promptConfigFallbackReasons': List<String>.from(fallbackReasons),
        },
      ),
    );
  }

  _CompareReplayDraftPromptConfig _parseCompareReplayDraftPromptConfig(
    Map source, {
    required List<String> fallbackReasons,
  }) {
    final sourceMap = Map<String, Object?>.fromEntries(
      source.entries
          .where((entry) => entry.key?.toString().trim().isNotEmpty == true)
          .map((entry) => MapEntry(entry.key.toString().trim(), entry.value)),
    );
    final nestedUrgentPrompt = sourceMap['urgentPrompt'];
    if (nestedUrgentPrompt is Map) {
      final nestedMap = Map<String, Object?>.fromEntries(
        nestedUrgentPrompt.entries
            .where((entry) => entry.key?.toString().trim().isNotEmpty == true)
            .map((entry) => MapEntry(entry.key.toString().trim(), entry.value)),
      );
      sourceMap.addAll(nestedMap);
    }
    final version =
        _extractString(sourceMap, 'version') ??
        _defaultCompareReplayDraftUrgentPromptConfig.version;
    final maxCountPerSession = _extractPositiveInt(
      sourceMap['maxCountPerSession'],
    );
    if (maxCountPerSession == null &&
        sourceMap.containsKey('maxCountPerSession')) {
      fallbackReasons.add(
        'maxCountPerSession must be a positive integer; fallback to default',
      );
    }
    return _CompareReplayDraftPromptConfig(
      version: version,
      title:
          _extractString(sourceMap, 'title') ??
          _defaultCompareReplayDraftUrgentPromptConfig.title,
      bodyTemplate:
          _extractString(sourceMap, 'bodyTemplate') ??
          _defaultCompareReplayDraftUrgentPromptConfig.bodyTemplate,
      dismissButtonLabel:
          _extractString(sourceMap, 'dismissButtonLabel') ??
          _defaultCompareReplayDraftUrgentPromptConfig.dismissButtonLabel,
      remindLaterButtonLabel:
          _extractString(sourceMap, 'remindLaterButtonLabel') ??
          _defaultCompareReplayDraftUrgentPromptConfig.remindLaterButtonLabel,
      clearNowButtonLabel:
          _extractString(sourceMap, 'clearNowButtonLabel') ??
          _defaultCompareReplayDraftUrgentPromptConfig.clearNowButtonLabel,
      experimentVariant:
          _extractString(sourceMap, 'experimentVariant') ??
          _defaultCompareReplayDraftUrgentPromptConfig.experimentVariant,
      urgentThreshold: _parseDurationFromConfig(
        minutes: sourceMap['urgentThresholdMinutes'],
        hours: sourceMap['urgentThresholdHours'],
        fallback: _defaultCompareReplayDraftUrgentPromptConfig.urgentThreshold,
        configField: 'urgentThreshold',
        fallbackReasons: fallbackReasons,
      ),
      snooze: _parseDurationFromConfig(
        minutes: sourceMap['snoozeMinutes'],
        hours: sourceMap['snoozeHours'],
        fallback: _defaultCompareReplayDraftUrgentPromptConfig.snooze,
        configField: 'snooze',
        fallbackReasons: fallbackReasons,
      ),
      maxCountPerSession:
          maxCountPerSession ??
          _defaultCompareReplayDraftUrgentPromptConfig.maxCountPerSession,
    );
  }

  Duration _parseDurationFromConfig({
    required Object? minutes,
    required Object? hours,
    required String configField,
    required List<String> fallbackReasons,
    required Duration fallback,
  }) {
    var shouldFallback = false;

    if (minutes != null) {
      final minutesValue = _extractPositiveInt(minutes);
      if (minutesValue != null) {
        return Duration(minutes: minutesValue);
      }
      shouldFallback = true;
      fallbackReasons.add('$configField.minutes must be a positive integer');
    }

    if (hours != null) {
      final hoursValue = _extractPositiveInt(hours);
      if (hoursValue != null) {
        return Duration(hours: hoursValue);
      }
      shouldFallback = true;
      fallbackReasons.add('$configField.hours must be a positive integer');
    }

    if (shouldFallback) {
      fallbackReasons.add('$configField fallback to default');
    }

    return fallback;
  }

  int? _extractPositiveInt(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw > 0 ? raw : null;
    }
    if (raw is num) {
      return raw > 0 ? raw.toInt() : null;
    }
    final parsed = int.tryParse(raw.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String? _extractString(Map<String, Object?> map, String key) {
    final raw = map[key];
    if (raw is! String) {
      return null;
    }
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> _loadRecentExportReplayStatuses(
    List<_ExportRecallCandidate> recalls,
  ) async {
    String? rawValue;
    try {
      rawValue = await widget.repository.getAppMeta(
        _recentExportReplayStatusesMetaKey,
      );
    } catch (_) {
      // Status metadata is optional; keep the recall chip without a status.
      return;
    }
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return;
      }

      final validKeys = {
        for (final recall in recalls) _recentExportRecallKey(recall),
      };
      final nextStatuses = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final normalizedKey = key.trim().toLowerCase();
        if (!validKeys.contains(normalizedKey)) {
          continue;
        }
        final value = entry.value;
        if (value is! String) {
          continue;
        }
        final status = value.trim();
        if (status.isNotEmpty) {
          nextStatuses[normalizedKey] = status;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _compareReplayStatuses.clear();
        _compareReplayStatuses.addAll(nextStatuses);
      });
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  Future<void> _loadRecentExportReplayDraftTimestamps(
    List<_ExportRecallCandidate> recalls,
  ) async {
    _compareReplayDraftTimestamps.clear();
    String? rawValue;
    try {
      rawValue = await widget.repository.getAppMeta(
        _recentExportReplayDraftsMetaKey,
      );
    } catch (_) {
      // Draft timestamps are optional; let status restoration and archival run.
      return;
    }
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return;
      }

      final validKeys = {
        for (final recall in recalls)
          if (recall.scopeType == _ExportRecallScopeType.compare)
            _recentExportRecallKey(recall),
      };
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        if (key.isEmpty || !validKeys.contains(key)) {
          continue;
        }
        final rawStartedAt = entry.value;
        final startedAt = _parsePersistedInteger(rawStartedAt);
        if (startedAt == null || startedAt <= 0) {
          continue;
        }
        _compareReplayDraftTimestamps[key] = startedAt;
      }
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  int? _parsePersistedInteger(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      if (!raw.isFinite || raw != raw.truncate()) {
        return null;
      }
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw.trim());
    }
    return null;
  }

  Future<void> _persistRecentExportReplayDraftTimestamps() async {
    try {
      final filteredTimestamps = <String, int>{};
      for (final recall in _recentExportRecalls) {
        if (recall.scopeType != _ExportRecallScopeType.compare) {
          continue;
        }
        final key = _recentExportRecallKey(recall);
        final value = _compareReplayDraftTimestamps[key];
        if (value != null && value > 0) {
          filteredTimestamps[key] = value;
        }
      }

      var payload = jsonEncode(filteredTimestamps);
      if (AppMetaPayloadBudget.utf8ByteLength(payload) <=
          _maxAppMetaValueLength) {
        await _appMetaWriteQueue.enqueue(
          _recentExportReplayDraftsMetaKey,
          payload,
        );
        return;
      }

      final compactKeys = filteredTimestamps.keys.toList(growable: false);
      var candidateKeys = List<String>.from(compactKeys);
      while (candidateKeys.isNotEmpty) {
        candidateKeys.removeLast();
        final candidatePayload = jsonEncode({
          for (final key in candidateKeys)
            if (filteredTimestamps.containsKey(key))
              key: filteredTimestamps[key],
        });
        if (AppMetaPayloadBudget.utf8ByteLength(candidatePayload) <=
            _maxAppMetaValueLength) {
          await _appMetaWriteQueue.enqueue(
            _recentExportReplayDraftsMetaKey,
            candidatePayload,
          );
          return;
        }
      }
      await _appMetaWriteQueue.enqueue(_recentExportReplayDraftsMetaKey, '{}');
    } catch (_) {
      // Replay draft timestamps are supplemental; keep the live replay usable.
    }
  }

  void _clearCompareReplayDraftState(String statusKey) {
    _compareReplayDraftTimestamps.remove(statusKey);
    _compareReplayRetryAttempts.remove(statusKey);
    if (_compareReplayDraftUrgentPromptPriorityKey == statusKey) {
      _compareReplayDraftUrgentPromptPriorityKey = null;
    }
    _clearUrgentCompareReplayDraftPromptState(statusKey);
  }

  void _clearUrgentCompareReplayDraftPromptState(String statusKey) {
    _compareReplayDraftUrgentPromptCounts.remove(statusKey);
    _compareReplayDraftUrgentPromptCooldownMs.remove(statusKey);
  }

  String? _urgentCompareReplayDraftPromptSuppressReason(String statusKey) {
    if (!_isCompareReplayDraftStatus(_compareReplayStatuses[statusKey])) {
      return 'not_draft';
    }
    final shownCount = _compareReplayDraftUrgentPromptCounts[statusKey] ?? 0;
    if (shownCount >=
        _compareReplayDraftUrgentPromptConfig.maxCountPerSession) {
      return 'max_count_reached';
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cooldownMs = _compareReplayDraftUrgentPromptCooldownMs[statusKey];
    if (cooldownMs != null && cooldownMs > nowMs) {
      return 'cooldown_active';
    }
    return null;
  }

  void _recordUrgentCompareReplayDraftPromptShown(String statusKey) {
    _compareReplayDraftUrgentPromptCounts[statusKey] =
        (_compareReplayDraftUrgentPromptCounts[statusKey] ?? 0) + 1;
  }

  void _scheduleUrgentCompareReplayDraftPromptAfterDelay(int delayMs) {
    _resetUrgentCompareReplayDraftPromptScheduler(shouldReschedule: false);
    if (delayMs <= 0) {
      _scheduleUrgentCompareReplayDraftPrompt();
      return;
    }
    _compareReplayDraftUrgentPromptDeferredTimer = Timer(
      Duration(milliseconds: delayMs),
      () {
        if (!mounted) {
          return;
        }
        _scheduleUrgentCompareReplayDraftPrompt();
      },
    );
  }

  void _deferUrgentCompareReplayDraftPrompt(String statusKey) {
    final shownCount = _compareReplayDraftUrgentPromptCounts[statusKey] ?? 0;
    if (shownCount >=
        _compareReplayDraftUrgentPromptConfig.maxCountPerSession) {
      _compareReplayDraftUrgentPromptCooldownMs[statusKey] =
          DateTime.now().millisecondsSinceEpoch + 1;
      _resetUrgentCompareReplayDraftPromptScheduler(shouldReschedule: false);
      return;
    }
    final delayMs = _compareReplayDraftUrgentPromptConfig.snooze.inMilliseconds;
    _compareReplayDraftUrgentPromptCooldownMs[statusKey] =
        DateTime.now().millisecondsSinceEpoch +
        _compareReplayDraftUrgentPromptConfig.snooze.inMilliseconds;
    _scheduleUrgentCompareReplayDraftPromptAfterDelay(delayMs);
  }

  void _resetUrgentCompareReplayDraftPromptScheduler({
    bool shouldReschedule = true,
  }) {
    _compareReplayDraftUrgentPromptDeferredTimer?.cancel();
    _compareReplayDraftUrgentPromptDeferredTimer = null;
    if (shouldReschedule && mounted) {
      _scheduleUrgentCompareReplayDraftPrompt();
    }
  }

  Future<void> _archiveExpiredCompareReplayDraftStatuses() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final retentionMs = _compareReplayDraftRetention.inMilliseconds;
    final expiredKeys = <String>[];
    for (final recall in _recentExportRecalls) {
      if (recall.scopeType != _ExportRecallScopeType.compare) {
        continue;
      }
      final statusKey = _recentExportRecallKey(recall);
      final status = _compareReplayStatuses[statusKey];
      if (!_isCompareReplayDraftStatus(status)) {
        continue;
      }
      final startedAtMs = _compareReplayDraftTimestamps[statusKey];
      final isExpired =
          startedAtMs == null || nowMs - startedAtMs >= retentionMs;
      if (isExpired) {
        expiredKeys.add(statusKey);
      }
    }
    if (expiredKeys.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        for (final statusKey in expiredKeys) {
          _compareReplayStatuses[statusKey] =
              _compareReplayStatusManualRebuildRequired;
          _clearCompareReplayDraftState(statusKey);
          if (_lastCompareReplayStatusKey == statusKey) {
            _lastCompareReplayStatusKey = null;
            _lastCompareReplayMissingIds = const [];
            if (_exportStatusMessage != null &&
                _exportStatusMessage!.contains('Compare replay')) {
              _exportStatusMessage = null;
            }
          }
        }
      });
    } else {
      for (final statusKey in expiredKeys) {
        _compareReplayStatuses[statusKey] =
            _compareReplayStatusManualRebuildRequired;
        _clearCompareReplayDraftState(statusKey);
        if (_lastCompareReplayStatusKey == statusKey) {
          _lastCompareReplayStatusKey = null;
          _lastCompareReplayMissingIds = const [];
          if (_exportStatusMessage != null &&
              _exportStatusMessage!.contains('Compare replay')) {
            _exportStatusMessage = null;
          }
        }
      }
    }
    _resetUrgentCompareReplayDraftPromptScheduler();
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Archived stale compare replay draft states',
        details: {'count': expiredKeys.length},
      ),
    );
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
  }

  Future<void> _exitCurrentDraftCompareReplay() async {
    final statusKey = _lastCompareReplayStatusKey;
    if (statusKey == null ||
        !_isCompareReplayDraftStatus(_compareReplayStatuses[statusKey])) {
      return;
    }

    if (mounted) {
      setState(() {
        _compareReplayStatuses[statusKey] =
            _compareReplayStatusManualRebuildRequired;
        _clearCompareReplayDraftState(statusKey);
        _lastCompareReplayMissingIds = const [];
        if (_exportStatusMessage != null &&
            _exportStatusMessage!.contains('Compare replay')) {
          _exportStatusMessage = null;
        }
      });
    } else {
      _compareReplayStatuses[statusKey] =
          _compareReplayStatusManualRebuildRequired;
      _clearCompareReplayDraftState(statusKey);
      _lastCompareReplayMissingIds = const [];
      if (_exportStatusMessage != null &&
          _exportStatusMessage!.contains('Compare replay')) {
        _exportStatusMessage = null;
      }
    }
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
    _resetUrgentCompareReplayDraftPromptScheduler();
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Exited manual rebuild draft',
        details: {'scopeKey': statusKey},
      ),
    );
  }

  List<_ExportRecallCandidate>? _loadExportRecallsFromMeta(String rawValue) {
    if (rawValue.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List<dynamic>) {
        return null;
      }
      final recalls = <_ExportRecallCandidate>[];
      for (final value in decoded) {
        if (value is! String) {
          continue;
        }
        final recall = _extractExportRecallFromScope(value);
        if (recall == null) {
          continue;
        }
        final duplicate = recalls.any(
          (item) =>
              item.scopeType == recall.scopeType &&
              item.scopeValue.toLowerCase() == recall.scopeValue.toLowerCase(),
        );
        if (duplicate) {
          continue;
        }
        recalls.add(recall);
        if (recalls.length >= _maxRecentExportSearches) {
          break;
        }
      }
      return recalls;
    } catch (_) {
      return null;
    }
  }

  Future<void> _appendRecentExportRecall(String scopeLabel) async {
    final recall = _extractExportRecallFromScope(scopeLabel);
    if (recall == null) {
      return;
    }
    final recallKey = _recentExportRecallKey(recall);
    final existing = List<_ExportRecallCandidate>.from(_recentExportRecalls);
    final deduped = existing
        .where(
          (item) =>
              item.scopeType != recall.scopeType ||
              item.scopeValue.toLowerCase() != recall.scopeValue.toLowerCase(),
        )
        .toList(growable: false);
    deduped.insert(0, recall);

    final capped = deduped
        .take(_maxRecentExportSearches)
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _recentExportRecalls = capped;
        if (recall.scopeType == _ExportRecallScopeType.compare) {
          _compareReplayStatuses.remove(recallKey);
          _clearCompareReplayDraftState(recallKey);
          _resetUrgentCompareReplayDraftPromptScheduler();
        }
      });
    }
    await _persistRecentExportRecalls(capped);
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
  }

  Future<void> _persistRecentExportReplayStatuses() async {
    try {
      final filteredStatuses = <String, String>{};
      for (final recall in _recentExportRecalls) {
        final key = _recentExportRecallKey(recall);
        final status = _compareReplayStatuses[key]?.trim();
        if (status != null && status.isNotEmpty) {
          filteredStatuses[key] = status;
        }
      }

      var payload = jsonEncode(filteredStatuses);
      if (AppMetaPayloadBudget.utf8ByteLength(payload) <=
          _maxAppMetaValueLength) {
        await _appMetaWriteQueue.enqueue(
          _recentExportReplayStatusesMetaKey,
          payload,
        );
        return;
      }

      final compactKeys = filteredStatuses.keys.toList(growable: false);
      var candidateKeys = List<String>.from(compactKeys);
      while (candidateKeys.isNotEmpty) {
        candidateKeys.removeLast();
        final candidatePayload = jsonEncode({
          for (final key in candidateKeys)
            if (filteredStatuses.containsKey(key)) key: filteredStatuses[key],
        });
        if (AppMetaPayloadBudget.utf8ByteLength(candidatePayload) <=
            _maxAppMetaValueLength) {
          await _appMetaWriteQueue.enqueue(
            _recentExportReplayStatusesMetaKey,
            candidatePayload,
          );
          return;
        }
      }
      await _appMetaWriteQueue.enqueue(
        _recentExportReplayStatusesMetaKey,
        '{}',
      );
    } catch (_) {
      // Replay status persistence is supplemental; keep the live status usable.
    }
  }

  Future<void> _persistRecentExportRecalls(
    List<_ExportRecallCandidate> recalls,
  ) async {
    try {
      final scopeLabels = recalls
          .map(_exportRecallScopeLabel)
          .toList(growable: false);
      await _setMetaList(key: _recentExportRecallsMetaKey, values: scopeLabels);
    } catch (_) {
      // Export recall persistence is supplemental; keep the live list usable.
    }
  }

  String _exportReplayLabel(_ExportRecallCandidate candidate) {
    return switch (candidate.scopeType) {
      _ExportRecallScopeType.search =>
        'Search: ${candidate.scopeValue.trim().isEmpty ? 'All local foods' : candidate.scopeValue}',
      _ExportRecallScopeType.country => 'Country: ${candidate.scopeValue}',
      _ExportRecallScopeType.favorites =>
        'Favorites: ${candidate.scopeValue.isEmpty ? 'All local foods' : candidate.scopeValue}',
      _ExportRecallScopeType.compare => _compareReplayChipLabel(candidate),
    };
  }

  bool get _hasUnavailableCompareRecalls {
    for (final recall in _recentExportRecalls) {
      if (recall.scopeType != _ExportRecallScopeType.compare) {
        continue;
      }
      final status = _compareReplayStatuses[_recentExportRecallKey(recall)]
          ?.trim();
      if (_isUnavailableCompareReplayStatus(status)) {
        return true;
      }
    }
    return false;
  }

  bool get _hasDraftCompareRecalls {
    for (final recall in _recentExportRecalls) {
      if (recall.scopeType != _ExportRecallScopeType.compare) {
        continue;
      }
      final status = _compareReplayStatuses[_recentExportRecallKey(recall)]
          ?.trim();
      if (!_isCompareReplayDraftStatus(status)) {
        continue;
      }
      final statusKey = _recentExportRecallKey(recall);
      final startedAt = _compareReplayDraftTimestamps[statusKey];
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final retentionMs = _compareReplayDraftRetention.inMilliseconds;
      final isActive = startedAt != null && nowMs - startedAt < retentionMs;
      if (isActive) {
        return true;
      }
    }
    return false;
  }

  bool _isUnavailableCompareReplayStatus(String? status) {
    if (status == null) {
      return false;
    }
    return status.trim().toLowerCase().startsWith('unavailable');
  }

  bool _isCompareReplayDraftStatus(String? status) {
    if (status == null) {
      return false;
    }
    return status.trim().toLowerCase().startsWith('draft');
  }

  bool _isCurrentCompareReplayDraft() {
    if (_lastCompareReplayStatusKey == null) {
      return false;
    }
    return _isCompareReplayDraftStatus(
      _compareReplayStatuses[_lastCompareReplayStatusKey!],
    );
  }

  int? _compareReplayDraftRemainingMs(String statusKey) {
    final startedAtMs = _compareReplayDraftTimestamps[statusKey];
    if (startedAtMs == null || startedAtMs <= 0) {
      return null;
    }
    final expiryMs = startedAtMs + _compareReplayDraftRetention.inMilliseconds;
    final remainingMs = expiryMs - DateTime.now().millisecondsSinceEpoch;
    return remainingMs <= 0 ? 0 : remainingMs;
  }

  String _compareReplayDraftRemainingLabel(String statusKey) {
    final remainingMs = _compareReplayDraftRemainingMs(statusKey);
    if (remainingMs == null) {
      return 'Draft duration unavailable';
    }
    if (remainingMs <= 0) {
      return 'Draft expired';
    }
    final remaining = Duration(milliseconds: remainingMs);
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h left';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m left';
    }
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m left';
    }
    return 'Less than 1m left';
  }

  bool _isCompareReplayDraftUrgent(String statusKey) {
    final remainingMs = _compareReplayDraftRemainingMs(statusKey);
    if (remainingMs == null) {
      return false;
    }
    return remainingMs > 0 &&
        remainingMs <=
            _compareReplayDraftUrgentPromptConfig
                .urgentThreshold
                .inMilliseconds;
  }

  String _compareReplayDraftUrgentThresholdLabel() {
    final minutes =
        _compareReplayDraftUrgentPromptConfig.urgentThreshold.inMinutes;
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '${hours}h';
    }
    return '${minutes}m';
  }

  String _compareReplayChipLabel(_ExportRecallCandidate candidate) {
    final base = 'Compare: ${_compareReplayLabelValue(candidate.scopeValue)}';
    final statusKey = _recentExportRecallKey(candidate);
    final status = _compareReplayStatuses[statusKey];
    if (status == null) {
      return base;
    }
    if (_isCompareReplayDraftStatus(status)) {
      final urgencySuffix = _isCompareReplayDraftUrgent(statusKey)
          ? ' · expires within ${_compareReplayDraftUrgentThresholdLabel()}'
          : '';
      return '$base · $status · ${_compareReplayDraftRemainingLabel(statusKey)}$urgencySuffix';
    }
    return '$base · $status';
  }

  Future<void> _resumeCompareReplayDraft() async {
    if (!mounted || _lastCompareReplayStatusKey == null) {
      return;
    }
    final statusKey = _lastCompareReplayStatusKey!;
    if (!_isCompareReplayDraftStatus(_compareReplayStatuses[statusKey])) {
      return;
    }
    if (_compareFoodIds.isNotEmpty || _compareFoodItemsById.isNotEmpty) {
      _clearCompareSelection();
    }
    if (_compareReplayDraftTimestamps[statusKey] == null) {
      _compareReplayDraftTimestamps[statusKey] =
          DateTime.now().millisecondsSinceEpoch;
    }
    setState(() {
      _compareReplayStatuses[statusKey] = _compareReplayStatusManualDraft;
      _lastCompareReplayStatusKey = statusKey;
      _exportStatusMessage =
          'Resumed manual rebuild draft. Pick foods to complete compare replay.';
    });
    _resetUrgentCompareReplayDraftPromptScheduler();
    unawaited(_persistRecentExportReplayStatuses());
    unawaited(_persistRecentExportReplayDraftTimestamps());
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Resumed compare replay draft',
        details: {'scopeKey': statusKey},
      ),
    );
  }

  String _recentExportRecallKey(_ExportRecallCandidate candidate) {
    return '${candidate.scopeType.name}:${candidate.scopeValue.trim().toLowerCase()}';
  }

  String _exportRecallScopeLabel(_ExportRecallCandidate candidate) {
    final value = candidate.scopeValue.trim().isEmpty
        ? 'all-local-foods'
        : candidate.scopeValue.trim();
    return switch (candidate.scopeType) {
      _ExportRecallScopeType.search => 'search:$value',
      _ExportRecallScopeType.country => 'country:$value',
      _ExportRecallScopeType.favorites => 'favorites:$value',
      _ExportRecallScopeType.compare => 'compare:$value',
    };
  }

  IconData _exportRecallIcon(_ExportRecallScopeType scopeType) {
    return switch (scopeType) {
      _ExportRecallScopeType.search => Icons.search,
      _ExportRecallScopeType.country => Icons.public,
      _ExportRecallScopeType.favorites => Icons.favorite_outline,
      _ExportRecallScopeType.compare => Icons.compare_arrows,
    };
  }

  _ExportRecallCandidate? _extractExportRecallFromScope(String scopeLabel) {
    final normalizedScopeLabel = scopeLabel.trim();
    const searchPrefix = 'search:';
    if (normalizedScopeLabel.startsWith(searchPrefix)) {
      final query = normalizedScopeLabel.substring(searchPrefix.length).trim();
      if (query.isEmpty || query.toLowerCase() == 'all-local-foods') {
        return const _ExportRecallCandidate(
          scopeType: _ExportRecallScopeType.search,
          scopeValue: '',
        );
      }
      return _ExportRecallCandidate(
        scopeType: _ExportRecallScopeType.search,
        scopeValue: query,
      );
    }
    const countryPrefix = 'country:';
    if (normalizedScopeLabel.startsWith(countryPrefix)) {
      final country = normalizedScopeLabel
          .substring(countryPrefix.length)
          .trim();
      if (country.isEmpty || country.toLowerCase() == 'all-local-foods') {
        return null;
      }
      return _ExportRecallCandidate(
        scopeType: _ExportRecallScopeType.country,
        scopeValue: country,
      );
    }
    const favoritePrefix = 'favorites:';
    if (normalizedScopeLabel.startsWith(favoritePrefix)) {
      final favorites = normalizedScopeLabel
          .substring(favoritePrefix.length)
          .trim();
      if (favorites.toLowerCase() == 'empty') {
        return null;
      }
      return _ExportRecallCandidate(
        scopeType: _ExportRecallScopeType.favorites,
        scopeValue: favorites.toLowerCase() == 'all-local-foods'
            ? ''
            : favorites,
      );
    }
    const comparePrefix = 'compare:';
    if (normalizedScopeLabel.startsWith(comparePrefix)) {
      final compare = normalizedScopeLabel
          .substring(comparePrefix.length)
          .trim();
      if (compare.isEmpty ||
          compare.toLowerCase() == 'empty' ||
          _parseCompareReplayIds(compare).isEmpty) {
        return null;
      }
      return _ExportRecallCandidate(
        scopeType: _ExportRecallScopeType.compare,
        scopeValue: compare,
      );
    }
    return null;
  }

  String _compareReplayLabelValue(String scopeValue) {
    final ids = _parseCompareReplayIds(scopeValue);
    if (ids.isEmpty) {
      return 'Unavailable';
    }
    if (ids.length == 1) {
      return '1 item';
    }
    return '${ids.length} items';
  }

  List<String> _parseCompareReplayIds(String scopeValue) {
    final values = scopeValue.trim();
    if (values.isEmpty) {
      return const [];
    }
    if (values.contains('|')) {
      return values
          .split('|')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }

    if (values.contains('+')) {
      final first = values.substring(0, values.indexOf('+')).trim();
      return first.isEmpty ? const [] : [first];
    }

    return values
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _replayExportRecall(_ExportRecallCandidate candidate) async {
    if (candidate.scopeType == _ExportRecallScopeType.compare) {
      await _replayCompareExportRecall(candidate);
      return;
    }
    if (candidate.scopeType == _ExportRecallScopeType.country) {
      await _runSearchWithCountryFilter(candidate.scopeValue);
      return;
    }
    _searchController.text = candidate.scopeValue;
    _clearAdvancedFilters();
    await _runSearch(candidate.scopeValue);
  }

  Future<void> _replayCompareExportRecall(
    _ExportRecallCandidate candidate,
  ) async {
    final scopeValue = candidate.scopeValue;
    final replayKey = _recentExportRecallKey(candidate);
    final ids = _parseCompareReplayIds(scopeValue);
    if (ids.isEmpty) {
      _compareReplayStatuses[replayKey] = _compareReplayStatusUnavailable;
      _clearCompareReplayDraftState(replayKey);
      _resetUrgentCompareReplayDraftPromptScheduler();
      setState(() {
        _lastCompareReplayMissingIds = const [];
        _lastCompareReplayStatusKey = replayKey;
      });
      unawaited(
        _appendActivityTrace(
          action: 'export',
          summary: 'Compare replay skipped: no valid IDs',
          details: {'mode': 'compare_replay_invalid'},
        ),
      );
      setState(() {
        _exportStatusMessage = 'Compare replay unavailable for this export.';
      });
      await _persistRecentExportReplayStatuses();
      await _persistRecentExportReplayDraftTimestamps();
      return;
    }
    _clearCompareSelection();
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    setState(() {
      _compareFoodIds
        ..clear()
        ..addAll(normalizedIds.take(_maxCompareFoods).toList(growable: false));
      _compareFoodItemsById.clear();
    });
    await _loadCompareFoodItemsForIds(_compareFoodIds);
    final missingIds = _compareFoodIds
        .where((id) => !_compareFoodItemsById.containsKey(id))
        .toList(growable: false);
    final loadedCount = _compareFoodIds.length - missingIds.length;
    final statusText = missingIds.isEmpty
        ? 'Restored $loadedCount/${_compareFoodIds.length}'
        : loadedCount == 0
        ? 'Unavailable'
        : 'Partially restored $loadedCount/${_compareFoodIds.length}';
    _compareReplayStatuses[replayKey] = statusText;
    _clearCompareReplayDraftState(replayKey);
    _resetUrgentCompareReplayDraftPromptScheduler();
    setState(() {
      _lastCompareReplayStatusKey = replayKey;
      _lastCompareReplayMissingIds = missingIds;
    });
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
    if (!mounted) {
      return;
    }
    if (missingIds.isNotEmpty) {
      final missingLabel = missingIds.length == 1
          ? '1 missing item'
          : '${missingIds.length} missing items';
      final loadedCount = _compareFoodIds.length - missingIds.length;
      if (loadedCount == 0) {
        setState(() {
          _exportStatusMessage =
              'Compare replay unavailable ($missingLabel). Rebuild compare manually.';
        });
      } else {
        setState(() {
          _exportStatusMessage =
              'Compare replay partially restored: $loadedCount loaded, $missingLabel unavailable.';
        });
      }
    } else {
      setState(() {
        _exportStatusMessage = null;
      });
    }
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary:
            'Replayed comparison from export recall (${_compareFoodIds.length} item(s))',
        details: {
          'foodIds': _compareFoodIds,
          'missingFoodIds': missingIds,
          'mode': 'export_recall',
        },
      ),
    );
  }

  Future<void> _runSearchWithCountryFilter(String country) async {
    _searchController.clear();
    _clearAdvancedFilters();
    _countryFilterController.text = country;
    await _runSearch('');
  }

  Future<void> _loadFavoriteTemplates() async {
    final rawValue = await widget.repository.getAppMeta(
      _favoriteTemplatesMetaKey,
    );
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List<dynamic>) {
        return;
      }
      final templates = <_FavoriteTemplate>[];
      for (final value in decoded) {
        final template = _FavoriteTemplate.fromJson(value);
        if (template != null) {
          templates.add(template);
        }
      }
      if (templates.isEmpty) {
        return;
      }
      templates.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final next = templates
          .take(_maxFavoriteTemplates)
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _favoriteTemplates
            ..clear()
            ..addAll(next);
          _syncActiveFavoriteTemplateSelection();
        });
      }
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  Future<void> _retryMissingCompareReplayItems() async {
    if (!mounted ||
        _lastCompareReplayStatusKey == null ||
        _lastCompareReplayMissingIds.isEmpty) {
      return;
    }
    if (_isCurrentCompareReplayDraft()) {
      setState(() {
        _exportStatusMessage =
            'Draft compare rebuild is active. Pick foods manually to rebuild compare.';
      });
      return;
    }
    final statusKey = _lastCompareReplayStatusKey!;
    final nextAttempt = (_compareReplayRetryAttempts[statusKey] ?? 0) + 1;
    _compareReplayRetryAttempts[statusKey] = nextAttempt;
    if (nextAttempt > _maxCompareReplayRetryAttempts) {
      _handleCompareReplayRetryLimitReached();
      return;
    }
    final missingIds = List<String>.from(_lastCompareReplayMissingIds);
    setState(() {
      _exportStatusMessage =
          'Retrying compare replay for ${missingIds.length} item(s)...';
    });
    await _loadCompareFoodItemsForIds(missingIds);
    final remainingMissingIds = missingIds
        .where((id) => !_compareFoodItemsById.containsKey(id))
        .toList(growable: false);
    final restoredCount = _compareFoodIds
        .where((id) => _compareFoodItemsById.containsKey(id))
        .length;
    final statusText = remainingMissingIds.isEmpty
        ? 'Restored $restoredCount/${_compareFoodIds.length}'
        : restoredCount == 0
        ? 'Unavailable'
        : 'Partially restored $restoredCount/${_compareFoodIds.length}';
    _compareReplayStatuses[statusKey] = statusText;
    _clearCompareReplayDraftState(statusKey);
    _resetUrgentCompareReplayDraftPromptScheduler();
    _compareReplayRetryAttempts[statusKey] = nextAttempt;
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
    if (!mounted) {
      return;
    }
    if (remainingMissingIds.isEmpty) {
      setState(() {
        _compareReplayRetryAttempts.remove(statusKey);
        _lastCompareReplayMissingIds = const [];
        _lastCompareReplayStatusKey = statusKey;
        _exportStatusMessage = null;
      });
      return;
    }

    final attemptCount = _compareReplayRetryAttempts[statusKey] ?? 0;
    final isAttemptLimitReached =
        attemptCount >= _maxCompareReplayRetryAttempts;
    final missingLabel = remainingMissingIds.length == 1
        ? '1 missing item'
        : '${remainingMissingIds.length} missing items';
    setState(() {
      _lastCompareReplayMissingIds = remainingMissingIds;
      _lastCompareReplayStatusKey = statusKey;
      if (isAttemptLimitReached) {
        final retrySuffix = restoredCount == 0
            ? 'all missing'
            : 'partially restored';
        _exportStatusMessage =
            'Compare replay $retrySuffix after $nextAttempt attempts: $restoredCount loaded, $missingLabel missing. Rebuild compare manually.';
      } else {
        _exportStatusMessage =
            'Compare replay partially restored: $restoredCount loaded, $missingLabel unavailable.';
      }
    });
  }

  int _compareReplayRetryCountForCurrent() {
    final statusKey = _lastCompareReplayStatusKey;
    if (statusKey == null) {
      return 0;
    }
    return _compareReplayRetryAttempts[statusKey] ?? 0;
  }

  bool _isCompareReplayRetryLimitReached() {
    return _compareReplayRetryCountForCurrent() >=
        _maxCompareReplayRetryAttempts;
  }

  void _handleCompareReplayRetryLimitReached() {
    if (!mounted || _lastCompareReplayStatusKey == null) {
      return;
    }
    final statusKey = _lastCompareReplayStatusKey!;
    final missingLabel = _lastCompareReplayMissingIds.length == 1
        ? '1 missing item'
        : '${_lastCompareReplayMissingIds.length} missing items';
    final attemptText = _compareReplayRetryAttempts[statusKey];
    setState(() {
      _exportStatusMessage =
          'Compare replay still missing after ${attemptText ?? 0} attempts. $missingLabel unavailable. Please rebuild compare manually.';
    });
    _compareReplayStatuses[statusKey] = attemptText == null || attemptText < 1
        ? _compareReplayStatusUnavailable
        : _compareReplayStatusManualRebuildRequired;
    _clearCompareReplayDraftState(statusKey);
    _resetUrgentCompareReplayDraftPromptScheduler();
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Compare replay retry limit reached',
        details: {
          'attempts': attemptText ?? 0,
          'missingFoodIds': _lastCompareReplayMissingIds,
          'mode': 'compare_replay_retry_limit',
        },
      ),
    );
    unawaited(_persistRecentExportReplayStatuses());
    unawaited(_persistRecentExportReplayDraftTimestamps());
  }

  void _resetCompareReplayRetryLimit() {
    if (!mounted || _lastCompareReplayStatusKey == null) {
      return;
    }
    final statusKey = _lastCompareReplayStatusKey!;
    _compareReplayStatuses[statusKey] = _compareReplayStatusUnavailable;
    _clearCompareReplayDraftState(statusKey);
    _resetUrgentCompareReplayDraftPromptScheduler();
    setState(() {
      _exportStatusMessage =
          'Compare replay retry limit reset. '
          'You can retry missing items.';
    });
    unawaited(_persistRecentExportReplayStatuses());
    unawaited(_persistRecentExportReplayDraftTimestamps());
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Compare replay retry limit reset',
        details: {
          'scopeKey': statusKey,
          'mode': 'compare_replay_retry_limit_reset',
        },
      ),
    );
  }

  Future<void> _confirmRebuildCompareReplayManually() async {
    final statusKey = _lastCompareReplayStatusKey;
    if (!mounted || statusKey == null) {
      return;
    }
    final shouldRebuild = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rebuild compare manually?'),
        content: const Text(
          'This will keep the recall item, clear current compare selection, '
          'and mark this failed entry as a manual rebuild draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );
    if (shouldRebuild != true) {
      return;
    }
    await _rebuildCompareReplayManually(statusKey);
  }

  Future<void> _rebuildCompareReplayManually(String statusKey) async {
    if (!mounted || _lastCompareReplayStatusKey == null) {
      return;
    }
    final previousStatus =
        _compareReplayStatuses[statusKey]?.trim() ??
        _compareReplayStatusUnavailable;
    setState(() {
      _compareFoodIds.clear();
      _compareFoodItemsById.clear();
      _compareReplayStatuses[statusKey] = _compareReplayStatusManualDraft;
      _compareReplayDraftTimestamps[statusKey] =
          DateTime.now().millisecondsSinceEpoch;
      _lastCompareReplayStatusKey = statusKey;
      _exportStatusMessage =
          'Marked compare replay as manual rebuild draft. Pick foods to rebuild.';
    });
    _resetUrgentCompareReplayDraftPromptScheduler();
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: 'Compare replay marked as manual rebuild draft',
        details: {
          'scopeKey': statusKey,
          'mode': 'compare_replay_manual_rebuild_draft',
          'statusBefore': previousStatus,
        },
      ),
    );
    unawaited(_persistRecentExportReplayStatuses());
    unawaited(_persistRecentExportReplayDraftTimestamps());
  }

  Future<void> _loadFavoriteFilterState() async {
    final rawValue = await widget.repository.getAppMeta(
      _favoriteFiltersMetaKey,
    );
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return;
      }

      final sortModeRaw = decoded['sortMode'];
      final sortModeValue = sortModeRaw is String
          ? sortModeRaw.trim().toLowerCase()
          : null;
      final sortMode = switch (sortModeValue) {
        'alpha' => _FavoriteSortMode.alpha,
        _ => _FavoriteSortMode.recent,
      };

      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteCountryFilter = decoded['country'] is String
            ? decoded['country'] as String?
            : null;
        _favoriteSourceFilter = decoded['source'] is String
            ? decoded['source'] as String?
            : null;
        _favoriteCategoryFilter = decoded['category'] is String
            ? decoded['category'] as String?
            : null;
        _favoriteSortMode = sortMode;
      });
      _pruneUnavailableFavoriteFilters();
      _syncActiveFavoriteTemplateSelection();
      await _persistFavoriteFilterState();
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  Future<void> _loadFavoriteFoods() async {
    final rawValue = await widget.repository.getAppMeta(_favoriteFoodsMetaKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List<dynamic>) {
        return;
      }
      final favorites = <_FavoriteFoodRef>[];
      final seenFoodIds = <String>{};
      for (final value in decoded) {
        final favorite = _FavoriteFoodRef.fromJson(value);
        if (favorite == null || !seenFoodIds.add(favorite.foodId)) {
          continue;
        }
        favorites.add(favorite);
      }

      if (mounted) {
        setState(() {
          _favoriteFoods
            ..clear()
            ..addAll(favorites.take(_maxFavoriteFoods));
          _pruneUnavailableFavoriteFilters();
          _syncActiveFavoriteTemplateSelection();
        });
        unawaited(_persistFavoriteFilterState());
      }
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  Future<void> _persistFavoriteFilterState() async {
    try {
      final payload = jsonEncode({
        'country': _favoriteCountryFilter,
        'source': _favoriteSourceFilter,
        'category': _favoriteCategoryFilter,
        'sortMode': _favoriteSortMode == _FavoriteSortMode.alpha
            ? 'alpha'
            : 'recent',
      });

      if (AppMetaPayloadBudget.utf8ByteLength(payload) <=
          _maxAppMetaValueLength) {
        await _appMetaWriteQueue.enqueue(_favoriteFiltersMetaKey, payload);
        return;
      }
      await _appMetaWriteQueue.enqueue(_favoriteFiltersMetaKey, '{}');
    } catch (_) {
      // Favorite filters are supplemental; keep the in-memory selection live.
    }
  }

  void _applyFavoriteTemplate(_FavoriteTemplate template) {
    setState(() {
      _favoriteCountryFilter = template.countryFilter;
      _favoriteSourceFilter = template.sourceFilter;
      _favoriteCategoryFilter = template.categoryFilter;
      _favoriteSortMode = template.sortMode;
      _pruneUnavailableFavoriteFilters();
      _syncActiveFavoriteTemplateSelection();
    });
    unawaited(_persistFavoriteFilterState());
  }

  void _saveFavoriteTemplate() {
    final name = _favoriteTemplateNameController.text.trim();
    if (name.isEmpty || !mounted) {
      return;
    }

    final now = DateTime.now();
    final templates = List<_FavoriteTemplate>.from(_favoriteTemplates);
    final existingIndex = templates.indexWhere(
      (template) => template.name.toLowerCase() == name.toLowerCase(),
    );
    final template = _FavoriteTemplate(
      id: existingIndex >= 0
          ? templates[existingIndex].id
          : now.microsecondsSinceEpoch.toString(),
      name: name,
      countryFilter: _favoriteCountryFilter,
      sourceFilter: _favoriteSourceFilter,
      categoryFilter: _favoriteCategoryFilter,
      sortMode: _favoriteSortMode,
      createdAt: existingIndex >= 0 ? templates[existingIndex].createdAt : now,
      updatedAt: now,
    );
    if (existingIndex >= 0) {
      templates.removeAt(existingIndex);
    }
    templates.insert(0, template);
    if (templates.length > _maxFavoriteTemplates) {
      templates.removeRange(_maxFavoriteTemplates, templates.length);
    }

    setState(() {
      _favoriteTemplates
        ..clear()
        ..addAll(templates);
      _activeFavoriteTemplateId = template.id;
      _favoriteTemplateNameController.clear();
    });
    _syncActiveFavoriteTemplateSelection();
    unawaited(_persistFavoriteTemplates());
  }

  void _removeFavoriteTemplate(String templateId) {
    final exists = _favoriteTemplates.any(
      (template) => template.id == templateId,
    );
    if (!exists) {
      return;
    }
    final next = List<_FavoriteTemplate>.from(_favoriteTemplates)
      ..removeWhere((template) => template.id == templateId);
    setState(() {
      _favoriteTemplates
        ..clear()
        ..addAll(next);
      if (_activeFavoriteTemplateId == templateId) {
        _activeFavoriteTemplateId = null;
      }
    });
    unawaited(_persistFavoriteTemplates());
  }

  Future<void> _persistFavoriteTemplates() async {
    try {
      final clamped = _favoriteTemplates
          .take(_maxFavoriteTemplates)
          .toList(growable: false);
      var payload = jsonEncode(
        clamped.map((template) => template.toJson()).toList(growable: false),
      );
      if (AppMetaPayloadBudget.utf8ByteLength(payload) <=
          _maxAppMetaValueLength) {
        await _appMetaWriteQueue.enqueue(_favoriteTemplatesMetaKey, payload);
        return;
      }

      final compact = List<_FavoriteTemplate>.from(clamped);
      while (compact.isNotEmpty) {
        compact.removeLast();
        final candidate = jsonEncode(
          compact.map((template) => template.toJson()).toList(growable: false),
        );
        if (AppMetaPayloadBudget.utf8ByteLength(candidate) <=
            _maxAppMetaValueLength) {
          await _appMetaWriteQueue.enqueue(
            _favoriteTemplatesMetaKey,
            candidate,
          );
          return;
        }
      }
      await _appMetaWriteQueue.enqueue(_favoriteTemplatesMetaKey, '[]');
    } catch (_) {
      // Favorite templates are supplemental; keep the in-memory list live.
    }
  }

  void _syncActiveFavoriteTemplateSelection() {
    final selectedCountry = _normalizeFavoriteCountry(_favoriteCountryFilter);
    final selectedSource = _normalizeFavoriteSource(_favoriteSourceFilter);
    final selectedCategory = _normalizeFavoriteCategory(
      _favoriteCategoryFilter,
    );
    final selectedSortMode = _favoriteSortMode;

    String? activeTemplateId;
    for (final template in _favoriteTemplates) {
      final templateCountry = _normalizeFavoriteCountry(template.countryFilter);
      final templateSource = _normalizeFavoriteSource(template.sourceFilter);
      final templateCategory = _normalizeFavoriteCategory(
        template.categoryFilter,
      );
      if (templateCountry == selectedCountry &&
          templateSource == selectedSource &&
          templateCategory == selectedCategory &&
          template.sortMode == selectedSortMode) {
        activeTemplateId = template.id;
        break;
      }
    }
    _activeFavoriteTemplateId = activeTemplateId;
  }

  void _clearFavoriteFilters() {
    _favoriteCountryFilter = null;
    _favoriteSourceFilter = null;
    _favoriteCategoryFilter = null;
    _favoriteSortMode = _FavoriteSortMode.recent;
    _activeFavoriteTemplateId = null;
    unawaited(_persistFavoriteFilterState());
  }

  Future<void> _recordRecentSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return;
    }
    final deduped = <String>[];
    final trimmed = query.trim();
    deduped.add(trimmed);
    for (final previous in _recentSearches) {
      if (previous.toLowerCase() == trimmed.toLowerCase()) {
        continue;
      }
      deduped.add(previous);
    }

    final next = deduped.take(_maxRecentSearches).toList(growable: false);
    setState(() {
      _recentSearches = next;
    });
    await _persistRecentSearchesSafely(next);
  }

  List<String> get _favoriteCountryFilterOptions {
    final countries = <String>{};
    for (final favorite in _favoriteFoods) {
      final rawCountry = favorite.country.trim();
      final country = rawCountry.isEmpty ? 'Unknown country' : rawCountry;
      countries.add(country);
    }
    final list = countries.toList(growable: false);
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get _favoriteSourceFilterOptions {
    final sources = <String>{};
    for (final favorite in _favoriteFoods) {
      final rawSource = favorite.sourceName.trim();
      final source = rawSource.isEmpty ? 'Unknown source' : rawSource;
      sources.add(source);
    }
    final list = sources.toList(growable: false);
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get _favoriteCategoryFilterOptions {
    final categories = <String>{};
    for (final favorite in _favoriteFoods) {
      final rawCategory = favorite.category.trim();
      final category = rawCategory.isEmpty ? 'Unknown category' : rawCategory;
      categories.add(category);
    }
    final list = categories.toList(growable: false);
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<_FavoriteFoodRef> _filteredFavoriteFoods() {
    final selectedCountry = _normalizeFavoriteCountry(_favoriteCountryFilter);
    final selectedSource = _normalizeFavoriteSource(_favoriteSourceFilter);
    final selectedCategory = _normalizeFavoriteCategory(
      _favoriteCategoryFilter,
    );
    var output = List<_FavoriteFoodRef>.from(_favoriteFoods);
    if (selectedCountry != null) {
      output = output
          .where(
            (item) =>
                _normalizeFavoriteCountry(item.country) == selectedCountry,
          )
          .toList(growable: false);
    }
    if (selectedSource != null) {
      output = output
          .where(
            (item) =>
                _normalizeFavoriteSource(item.sourceName) == selectedSource,
          )
          .toList(growable: false);
    }
    if (selectedCategory != null) {
      output = output
          .where(
            (item) =>
                _normalizeFavoriteCategory(item.category) == selectedCategory,
          )
          .toList(growable: false);
    }
    if (_favoriteSortMode == _FavoriteSortMode.alpha) {
      output.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return output;
  }

  Map<String, List<_FavoriteFoodRef>> _groupFavoritesByCountry(
    List<_FavoriteFoodRef> favorites,
  ) {
    final grouped = <String, List<_FavoriteFoodRef>>{};
    for (final favorite in favorites) {
      final country = _normalizeFavoriteCountryLabel(favorite.country);
      (grouped[country] ??= <_FavoriteFoodRef>[]).add(favorite);
    }
    return grouped;
  }

  String? _normalizeFavoriteCountry(String? country) {
    if (country == null) {
      return null;
    }
    final trimmed = country.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'unknown country') {
      return '__unknown_country__';
    }
    return trimmed;
  }

  String? _normalizeFavoriteSource(String? source) {
    if (source == null) {
      return null;
    }
    final trimmed = source.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'unknown source') {
      return '__unknown_source__';
    }
    return trimmed;
  }

  String? _normalizeFavoriteCategory(String? category) {
    if (category == null) {
      return null;
    }
    final trimmed = category.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'unknown category') {
      return '__unknown_category__';
    }
    return trimmed;
  }

  void _pruneUnavailableFavoriteFilters() {
    final normalizedCountry = _normalizeFavoriteCountry(_favoriteCountryFilter);
    if (normalizedCountry != null) {
      final availableCountries = _favoriteFoods
          .map((item) => _normalizeFavoriteCountry(item.country))
          .whereType<String>()
          .toSet();
      if (!availableCountries.contains(normalizedCountry)) {
        _favoriteCountryFilter = null;
      }
    }
    final normalizedSource = _normalizeFavoriteSource(_favoriteSourceFilter);
    if (normalizedSource != null) {
      final availableSources = _favoriteFoods
          .map((item) => _normalizeFavoriteSource(item.sourceName))
          .whereType<String>()
          .toSet();
      if (!availableSources.contains(normalizedSource)) {
        _favoriteSourceFilter = null;
      }
    }
    final normalizedCategory = _normalizeFavoriteCategory(
      _favoriteCategoryFilter,
    );
    if (normalizedCategory != null) {
      final availableCategories = _favoriteFoods
          .map((item) => _normalizeFavoriteCategory(item.category))
          .whereType<String>()
          .toSet();
      if (!availableCategories.contains(normalizedCategory)) {
        _favoriteCategoryFilter = null;
      }
    }
  }

  String _normalizeFavoriteCountryLabel(String country) {
    final trimmed = country.trim();
    if (trimmed.isEmpty) {
      return 'Unknown country';
    }
    return trimmed;
  }

  void _loadRecentSearch(String query) {
    _searchController.text = query;
    unawaited(_runSearch(query));
  }

  void _retryFailedSearch() {
    final query = _failedSearchQuery;
    if (query == null) {
      return;
    }
    _searchController.text = query;
    unawaited(_runSearch(query));
  }

  Future<void> _removeRecentSearch(String query) async {
    final next = _recentSearches
        .where((item) => item.toLowerCase() != query.toLowerCase())
        .toList(growable: false);
    setState(() {
      _recentSearches = next;
    });
    await _persistRecentSearchesSafely(next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() {
      _recentSearches = const [];
    });
    await _persistRecentSearchesSafely(const []);
  }

  Future<void> _persistRecentSearchesSafely(List<String> values) async {
    try {
      await _setMetaList(key: _recentSearchesMetaKey, values: values);
    } catch (_) {
      // Recent-search persistence is supplemental; keep UI state responsive.
    }
  }

  Future<void> _clearRecentExportRecalls() async {
    if (_recentExportRecalls.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    unawaited(
      _appendActivityTrace(
        action: 'export',
        summary: 'Cleared recent export recall list',
        details: {'count': _recentExportRecalls.length},
      ),
    );
    setState(() {
      _recentExportRecalls = const [];
      _compareReplayStatuses.clear();
      _compareReplayRetryAttempts.clear();
      _compareReplayDraftTimestamps.clear();
      _compareReplayDraftUrgentPromptCounts.clear();
      _compareReplayDraftUrgentPromptCooldownMs.clear();
      _compareReplayDraftUrgentPromptPriorityKey = null;
      _lastCompareReplayMissingIds = const [];
      _lastCompareReplayStatusKey = null;
      if (_exportStatusMessage != null &&
          _exportStatusMessage!.contains('Compare replay')) {
        _exportStatusMessage = null;
      }
    });
    _resetUrgentCompareReplayDraftPromptScheduler();
    await _persistRecentExportRecalls(const []);
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
  }

  Future<void> _clearUnavailableCompareRecalls() async {
    final next = _recentExportRecalls
        .where(
          (recall) =>
              recall.scopeType != _ExportRecallScopeType.compare ||
              !_isUnavailableCompareReplayStatus(
                _compareReplayStatuses[_recentExportRecallKey(recall)],
              ),
        )
        .toList(growable: false);
    if (next.length == _recentExportRecalls.length) {
      return;
    }
    final removedCount = _recentExportRecalls.length - next.length;
    final removedKeys = <String>{};
    unawaited(
      _appendActivityTrace(
        action: 'export',
        summary: 'Cleared unavailable compare recalls',
        details: {'count': removedCount},
      ),
    );
    setState(() {
      _recentExportRecalls = next;
      for (final key in List<String>.from(_compareReplayStatuses.keys)) {
        if (_isUnavailableCompareReplayStatus(_compareReplayStatuses[key])) {
          removedKeys.add(key);
          _compareReplayStatuses.remove(key);
          _clearCompareReplayDraftState(key);
        }
      }
      if (_lastCompareReplayStatusKey != null &&
          removedKeys.contains(_lastCompareReplayStatusKey)) {
        _lastCompareReplayStatusKey = null;
        _lastCompareReplayMissingIds = const [];
        if (_exportStatusMessage != null &&
            _exportStatusMessage!.contains('Compare replay')) {
          _exportStatusMessage = null;
        }
      }
    });
    _resetUrgentCompareReplayDraftPromptScheduler();
    await _persistRecentExportRecalls(next);
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
  }

  Future<void> _clearDraftCompareRecalls() async {
    final next = _recentExportRecalls
        .where(
          (recall) =>
              recall.scopeType != _ExportRecallScopeType.compare ||
              !_isCompareReplayDraftStatus(
                _compareReplayStatuses[_recentExportRecallKey(recall)],
              ),
        )
        .toList(growable: false);
    if (next.length == _recentExportRecalls.length) {
      return;
    }
    final removedKeys = <String>{};
    unawaited(
      _appendActivityTrace(
        action: 'export',
        summary: 'Cleared draft compare recalls',
        details: {'count': _recentExportRecalls.length - next.length},
      ),
    );
    setState(() {
      _recentExportRecalls = next;
      for (final key in List<String>.from(_compareReplayStatuses.keys)) {
        if (_isCompareReplayDraftStatus(_compareReplayStatuses[key])) {
          removedKeys.add(key);
          _compareReplayStatuses.remove(key);
          _clearCompareReplayDraftState(key);
        }
      }
      if (_lastCompareReplayStatusKey != null &&
          removedKeys.contains(_lastCompareReplayStatusKey)) {
        _lastCompareReplayStatusKey = null;
        _lastCompareReplayMissingIds = const [];
        if (_exportStatusMessage != null &&
            _exportStatusMessage!.contains('Compare replay')) {
          _exportStatusMessage = null;
        }
      }
    });
    _resetUrgentCompareReplayDraftPromptScheduler();
    await _persistRecentExportRecalls(next);
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
  }

  Future<void> _clearCurrentCompareReplayDraftNow() async {
    final statusKey = _lastCompareReplayStatusKey;
    if (statusKey == null) {
      return;
    }
    await _clearCompareReplayDraftNowByKey(statusKey);
  }

  Future<void> _clearCompareReplayDraftNowByKey(
    String statusKey, {
    bool fromUrgentPrompt = false,
    String? promptInstanceId,
    int? promptSessionIndex,
  }) async {
    final currentStatus = _compareReplayStatuses[statusKey];
    if (!mounted || !_isCompareReplayDraftStatus(currentStatus)) {
      return;
    }
    _clearCompareReplayDraftState(statusKey);
    final isLast = statusKey == _lastCompareReplayStatusKey;
    setState(() {
      _compareReplayStatuses[statusKey] =
          _compareReplayStatusManualRebuildRequired;
      if (isLast) {
        _lastCompareReplayMissingIds = const [];
        if (_exportStatusMessage != null &&
            _exportStatusMessage!.contains('Compare replay')) {
          _exportStatusMessage = null;
        }
      }
    });
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
    _resetUrgentCompareReplayDraftPromptScheduler();
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: fromUrgentPrompt
            ? 'Cleared compare replay draft now from urgent prompt'
            : 'Cleared compare replay draft now',
        details: {
          ..._compareReplayDraftPromptTraceDetails(
            scopeKey: statusKey,
            userAction: fromUrgentPrompt
                ? _CompareReplayDraftPromptUserAction.clearFromPrompt
                : _CompareReplayDraftPromptUserAction.manualClear,
            remainingMs: _compareReplayDraftRemainingMs(statusKey),
            promptInstanceId: promptInstanceId,
            promptSessionIndex: promptSessionIndex,
            promptConfigVersion: fromUrgentPrompt
                ? _compareReplayDraftUrgentPromptConfig.version
                : null,
            promptExperimentVariant: fromUrgentPrompt
                ? _compareReplayDraftUrgentPromptConfig.experimentVariant
                : null,
            statusBefore: currentStatus,
            trigger: fromUrgentPrompt
                ? _CompareReplayDraftPromptTrigger.urgentPrompt
                : _CompareReplayDraftPromptTrigger.manual,
          ),
        },
      ),
    );
  }

  Map<String, Object?> _compareReplayDraftPromptTraceDetails({
    required String scopeKey,
    required _CompareReplayDraftPromptUserAction userAction,
    required int? remainingMs,
    String? suppressReason,
    int? shownCount,
    int? cooldownMs,
    int? deferCount,
    _CompareReplayDraftPromptDismissReason? reason,
    String? promptConfigVersion,
    String? promptExperimentVariant,
    String? promptInstanceId,
    String? statusBefore,
    int? promptSessionIndex,
    _CompareReplayDraftPromptTrigger? trigger,
  }) {
    final details = <String, Object?>{
      'scopeKey': scopeKey,
      'activityTraceSchemaVersion':
          _activityTraceCompareReplayDraftPromptSchemaVersion,
      'userAction': userAction.value,
    };

    if (remainingMs != null) {
      details['remainingMs'] = remainingMs;
    }
    if (suppressReason != null) {
      details['suppressReason'] = suppressReason;
    }
    if (shownCount != null) {
      details['shownCount'] = shownCount;
    }
    if (cooldownMs != null) {
      details['cooldownMs'] = cooldownMs;
    }
    if (deferCount != null) {
      details['deferCount'] = deferCount;
    }
    if (reason != null) {
      details['reason'] = reason.value;
    }
    if (promptInstanceId != null) {
      details['promptInstanceId'] = promptInstanceId;
    }
    if (promptConfigVersion != null) {
      details['promptConfigVersion'] = promptConfigVersion;
    }
    if (promptExperimentVariant != null) {
      details['promptExperimentVariant'] = promptExperimentVariant;
    }
    if (promptSessionIndex != null) {
      details['promptSessionIndex'] = promptSessionIndex;
    }
    if (_compareReplayDraftUrgentPromptConfigFallbackReasons.isNotEmpty) {
      details['promptConfigFallback'] = true;
      details['promptConfigFallbackReasons'] = List<String>.from(
        _compareReplayDraftUrgentPromptConfigFallbackReasons,
      );
    }
    if (statusBefore != null) {
      details['statusBefore'] = statusBefore;
    }
    if (trigger != null) {
      details['trigger'] = trigger.value;
      details['promptType'] = trigger.value;
    }
    if (trigger == _CompareReplayDraftPromptTrigger.urgentPrompt &&
        promptConfigVersion == _compareReplayDraftUrgentPromptConfig.version) {
      details['promptConfigCooldownMinutes'] =
          _compareReplayDraftUrgentPromptConfig.snooze.inMinutes;
    }
    return details;
  }

  Future<void> _removeRecentExportRecall(
    _ExportRecallCandidate candidate,
  ) async {
    final targetKey = _recentExportRecallKey(candidate).toLowerCase();
    final isCurrentReplayStatus = targetKey == _lastCompareReplayStatusKey;
    final next = _recentExportRecalls
        .where(
          (item) => _recentExportRecallKey(item).toLowerCase() != targetKey,
        )
        .toList(growable: false);
    _clearCompareReplayDraftState(targetKey);
    unawaited(
      _appendActivityTrace(
        action: 'export',
        summary: 'Removed recent export recall',
        details: {'scopeLabel': _exportRecallScopeLabel(candidate)},
      ),
    );
    setState(() {
      _recentExportRecalls = next;
      if (isCurrentReplayStatus) {
        _lastCompareReplayStatusKey = null;
        _lastCompareReplayMissingIds = const [];
        if (_exportStatusMessage != null &&
            _exportStatusMessage!.contains('Compare replay')) {
          _exportStatusMessage = null;
        }
      }
    });
    _resetUrgentCompareReplayDraftPromptScheduler();
    await _persistRecentExportRecalls(next);
    await _persistRecentExportReplayStatuses();
    await _persistRecentExportReplayDraftTimestamps();
  }

  bool _isFavorite(String foodId) {
    return _favoriteFoods.any((item) => item.foodId == foodId);
  }

  bool _isCompared(String foodId) {
    return _compareFoodIds.contains(foodId);
  }

  void _toggleCompare(FoodItem food) {
    setState(() {
      final next = List<String>.from(_compareFoodIds);
      final exists = next.contains(food.id);
      if (exists) {
        next.remove(food.id);
        _compareFoodItemsById.remove(food.id);
      } else {
        if (_isCurrentCompareReplayDraft()) {
          unawaited(_exitCurrentDraftCompareReplay());
        }
        next.insert(0, food.id);
        if (next.length > _maxCompareFoods) {
          next.removeRange(_maxCompareFoods, next.length);
        }
      }
      _compareFoodIds
        ..clear()
        ..addAll(next);
    });
    final needsLoad = !_compareFoodItemsById.containsKey(food.id);
    if (_compareFoodIds.contains(food.id) && needsLoad) {
      unawaited(_loadCompareFoodItemsForIds([food.id]));
    }
    final isAdded = _compareFoodIds.contains(food.id);
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary:
            (isAdded ? 'Added to compare: ' : 'Removed from compare: ') +
            food.name,
        details: {
          'foodId': food.id,
          'foodName': food.name,
          'status': isAdded ? 'added' : 'removed',
        },
      ),
    );
  }

  Future<void> _applyFavoriteFilterToCompare(
    List<_FavoriteFoodRef> favoriteFoods,
  ) async {
    _clearPendingCompareUndo();
    if (favoriteFoods.isEmpty) {
      return;
    }
    final deduped = <String>[];
    for (final favorite in favoriteFoods.take(_maxCompareFoods)) {
      final foodId = favorite.foodId.trim();
      if (foodId.isEmpty || deduped.contains(foodId)) {
        continue;
      }
      deduped.add(foodId);
    }
    if (deduped.isEmpty) {
      return;
    }
    setState(() {
      _compareFoodIds
        ..clear()
        ..addAll(deduped);
    });
    final previousNames = deduped
        .map(
          (id) => _favoriteFoods.firstWhere((item) => item.foodId == id).name,
        )
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    unawaited(
      _appendActivityTrace(
        action: 'compare',
        summary: previousNames.isEmpty
            ? 'Loaded compare selection from filtered favorites'
            : 'Loaded compare from filtered favorites: ${previousNames.join(', ')}',
        details: {
          'foodIds': deduped,
          'count': deduped.length,
          'mode': 'favorite-filter',
        },
      ),
    );
    await _loadCompareFoodItemsForIds(deduped);
  }

  Future<void> _loadCompareFoodItemsForIds(List<String> foodIds) async {
    if (foodIds.isEmpty) {
      return;
    }
    final nextMap = <String, FoodItem>{};
    for (final foodId in foodIds) {
      if (foodId.trim().isEmpty || _compareFoodItemsById.containsKey(foodId)) {
        continue;
      }
      FoodDetails? detail;
      try {
        detail = await widget.repository.getFoodDetails(foodId);
      } catch (_) {
        // One unavailable detail must not block the remaining replay IDs.
        continue;
      }
      if (detail == null) {
        continue;
      }
      nextMap[foodId] = FoodItem(
        id: detail.id,
        name: detail.displayName,
        category: detail.category,
        country: detail.countryHint,
        sourceName: detail.sourceRecords.isEmpty
            ? ''
            : detail.sourceRecords.first.sourceName,
        description: detail.description,
        servingBasis: detail.servingBasis,
        tags: const ['official'],
        nutrients: detail.aggregatedNutrients,
        lastUpdated: detail.lastAggregatedAt,
      );
    }
    if (nextMap.isEmpty) {
      return;
    }
    setState(() {
      _compareFoodItemsById.addAll(nextMap);
    });
  }

  void _clearCompareSelection() {
    _clearPendingCompareUndo();
    final hadItems = _compareFoodIds.isNotEmpty;
    setState(() {
      _compareFoodIds.clear();
      _compareFoodItemsById.clear();
    });
    if (hadItems) {
      unawaited(
        _appendActivityTrace(
          action: 'compare',
          summary: 'Cleared comparison selection',
          details: {'status': 'cleared'},
        ),
      );
    }
  }

  void _clearPendingCompareUndo() {
    _compareUndoTimer?.cancel();
    _compareUndoTimer = null;
    _compareUndoSnapshot = const [];
  }

  List<String> _normalizeCompareFoodIds(List<String> foodIds) {
    final normalized = <String>[];
    for (final foodId in foodIds) {
      final value = foodId.trim();
      if (value.isEmpty || normalized.contains(value)) {
        continue;
      }
      normalized.add(value);
      if (normalized.length >= _maxCompareFoods) {
        break;
      }
    }
    return normalized;
  }

  void _restoreCompareSelection(List<String> foodIds, {bool fromUndo = false}) {
    if (!mounted) {
      return;
    }
    final normalized = _normalizeCompareFoodIds(foodIds);
    setState(() {
      _compareFoodIds
        ..clear()
        ..addAll(normalized);
    });
    unawaited(_loadCompareFoodItemsForIds(normalized));
    if (fromUndo) {
      unawaited(
        _appendActivityTrace(
          action: 'compare',
          summary: 'Restored compare selection from undo',
          details: {'count': normalized.length, 'foodIds': normalized},
        ),
      );
    }
  }

  void _removeCompareWithUndo({
    required BuildContext context,
    required FoodItem food,
  }) {
    if (!mounted) {
      return;
    }
    if (!_compareFoodIds.contains(food.id)) {
      return;
    }

    final previousSelection = List<String>.from(_compareFoodIds);
    final removedName = food.name.isNotEmpty ? food.name : 'Selected item';
    _clearPendingCompareUndo();
    _toggleCompare(food);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    _compareUndoSnapshot = previousSelection;
    _compareUndoTimer = Timer(
      const Duration(seconds: 6),
      _clearPendingCompareUndo,
    );
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$removedName removed from compare.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) {
                return;
              }
              final snapshot = List<String>.from(_compareUndoSnapshot);
              _clearPendingCompareUndo();
              _restoreCompareSelection(snapshot, fromUndo: true);
            },
          ),
        ),
      );
  }

  List<String> _resolveCompareFoodIdsForResults(List<FoodItem> results) {
    if (_compareFoodIds.isEmpty) {
      return const [];
    }
    final availableIds = <String>{..._compareFoodItemsById.keys};
    for (final food in results) {
      availableIds.add(food.id);
    }
    final resolved = <String>[];
    for (final id in _compareFoodIds) {
      if (availableIds.contains(id)) {
        resolved.add(id);
      }
    }
    if (resolved.length > _maxCompareFoods) {
      return resolved.take(_maxCompareFoods).toList(growable: false);
    }
    return resolved;
  }

  List<FoodItem> _selectedCompareFoods() {
    if (_compareFoodIds.isEmpty) {
      return const [];
    }
    final byId = <String, FoodItem>{for (final food in _results) food.id: food};
    final selected = <FoodItem>[];
    for (final id in _compareFoodIds) {
      final food = byId[id];
      final fallback = _compareFoodItemsById[id];
      final foodValue = food ?? fallback;
      if (foodValue != null) {
        selected.add(foodValue);
      }
    }
    return selected;
  }

  String _compareExportTraceQuery() {
    final ids = _compareFoodIds.take(_maxCompareFoods).toList(growable: false);
    if (ids.isEmpty) {
      return 'compare:empty';
    }
    return 'compare:${ids.join('|')}';
  }

  Widget _buildComparisonPanel(BuildContext context, List<FoodItem> foods) {
    if (_compareFoodIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    if (foods.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.compare_arrows_outlined),
          title: Text('Selected items are not visible in current results'),
          subtitle: Text(
            'Run those foods again or clear selection to start a new comparison.',
          ),
        ),
      );
    }
    if (foods.length < 2) {
      return Card(
        color: const Color(0xFFF8FAFC),
        child: ListTile(
          leading: const Icon(Icons.compare_arrows),
          title: const Text('Add one more result to unlock comparison'),
          subtitle: Text('Select at least ${2 - foods.length} more item(s).'),
        ),
      );
    }

    final labels = <String>{}
      ..addAll(
        foods.expand(
          (food) => food.nutrients
              .map((nutrient) => nutrient.label.trim())
              .where((label) => label.isNotEmpty),
        ),
      );
    final sortedNutrients = labels.toList()..sort();
    final comparisonRows = sortedNutrients
        .map((label) {
          final cells = <_CompareNutrientCell>[];
          final comparableAmountsByUnit = <String, List<double>>{};
          final comparableUnits = <String>{};
          final incomparableUnits = <String>{};

          for (final food in foods) {
            Nutrient? nutrient;
            final normalizedLabel = label.toLowerCase().trim();
            for (final item in food.nutrients) {
              if (item.label.trim().toLowerCase() == normalizedLabel) {
                nutrient = item;
                break;
              }
            }

            if (nutrient == null) {
              cells.add(
                _CompareNutrientCell(
                  foodId: food.id,
                  foodName: food.name,
                  display: '—',
                  amount: null,
                  unit: null,
                  present: false,
                ),
              );
            } else {
              final normalizedNutrient = _normalizeNutrientForComparison(
                amount: nutrient.amount,
                unit: nutrient.unit,
              );
              if (normalizedNutrient.canCompare &&
                  normalizedNutrient.comparableAmount != null) {
                final normalizedUnit = normalizedNutrient.normalizedUnit;
                if (normalizedUnit.isNotEmpty) {
                  comparableUnits.add(normalizedUnit);
                }
                comparableAmountsByUnit
                    .putIfAbsent(normalizedUnit, () => <double>[])
                    .add(normalizedNutrient.comparableAmount!);
              } else {
                incomparableUnits.add(
                  nutrientComparisonIncomparableUnitLabel(
                    normalizedNutrient.rawUnit,
                  ),
                );
              }
              cells.add(
                _CompareNutrientCell(
                  foodId: food.id,
                  foodName: food.name,
                  display: normalizedNutrient.display,
                  amount: normalizedNutrient.canCompare
                      ? normalizedNutrient.comparableAmount
                      : null,
                  unit: normalizedNutrient.normalizedUnit.isEmpty
                      ? nutrient.unit.trim()
                      : normalizedNutrient.normalizedUnit,
                  present: true,
                ),
              );
            }
          }

          final hasMissing = cells.any((cell) => !cell.present);
          final canCompareWithinUnit =
              comparableUnits.length == 1 &&
              comparableAmountsByUnit.length == 1;
          final amountsForVariance = canCompareWithinUnit
              ? (comparableAmountsByUnit.values.isNotEmpty
                    ? comparableAmountsByUnit.values.first
                    : const <double>[])
              : const <double>[];
          final hasVariance = hasNutrientComparisonAmountVariance(
            amountsForVariance,
          );
          final hasUnitMismatch =
              comparableUnits.length > 1 || incomparableUnits.isNotEmpty;
          final unitSummary = _comparisonUnitSummary(
            normalizedUnits: comparableUnits,
            incomparableUnits: incomparableUnits,
          );

          final sortedAmounts = <double>[...amountsForVariance]..sort();
          final min = sortedAmounts.isEmpty ? null : sortedAmounts.first;
          final max = sortedAmounts.isEmpty ? null : sortedAmounts.last;
          return _CompareNutrientRow(
            label: label,
            cells: cells,
            hasVariance: hasVariance,
            hasMissing: hasMissing,
            hasUnitMismatch: hasUnitMismatch,
            statusSummary: _comparisonRowSummaryText(
              label: label,
              hasVariance: hasVariance,
              hasMissing: hasMissing,
              hasUnitMismatch: hasUnitMismatch,
              unitSummary: unitSummary,
            ),
            unitSummary: unitSummary,
            minAmount: min,
            maxAmount: max,
          );
        })
        .toList(growable: false);
    final varianceCount = comparisonRows.where((row) => row.hasVariance).length;
    final missingValueCount = comparisonRows
        .where((row) => row.hasMissing)
        .length;
    final unitMismatchCount = comparisonRows
        .where((row) => row.hasUnitMismatch)
        .length;

    return Card(
      color: const Color(0xFFFFFDFA),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Semantics(
                container: true,
                label: 'Selected foods for comparison',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: foods
                      .asMap()
                      .entries
                      .map(
                        (entry) => FocusTraversalOrder(
                          order: NumericFocusOrder(entry.key.toDouble()),
                          child: Focus(
                            canRequestFocus: true,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.delete ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.backspace)) {
                                _removeCompareWithUndo(
                                  context: context,
                                  food: entry.value,
                                );
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Tooltip(
                              message:
                                  'Selected food: ${entry.value.name}. Tap x to remove from compare.',
                              child: Semantics(
                                button: true,
                                label:
                                    '${entry.value.name} selected for comparison. Press Delete to remove.',
                                child: Chip(
                                  label: Text(
                                    '${entry.value.name} • ${entry.value.country}',
                                  ),
                                  onDeleted: () => _removeCompareWithUndo(
                                    context: context,
                                    food: entry.value,
                                  ),
                                  deleteIcon: const Icon(Icons.close),
                                  deleteButtonTooltipMessage:
                                      'Remove ${entry.value.name} from comparison',
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (varianceCount > 0)
                    Semantics(
                      label:
                          'Variance: $varianceCount nutrients with different values across selected foods',
                      child: Tooltip(
                        message:
                            'Nutrients with different normalized values across selected foods',
                        child: Chip(
                          avatar: const Icon(Icons.trending_up),
                          label: Text('Variance: $varianceCount'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  if (missingValueCount > 0)
                    Semantics(
                      label:
                          'Missing values: $missingValueCount nutrients in current comparison',
                      child: Tooltip(
                        message:
                            'Some selected foods are missing this nutrient',
                        child: Chip(
                          avatar: const Icon(Icons.warning_amber_outlined),
                          label: Text('Missing values: $missingValueCount'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFFEF3C7),
                        ),
                      ),
                    ),
                  if (unitMismatchCount > 0)
                    Semantics(
                      label:
                          'Unit mismatch: $unitMismatchCount nutrients need review',
                      child: Tooltip(
                        message:
                            'Some nutrients use inconsistent or non-comparable units',
                        child: Chip(
                          avatar: const Icon(Icons.balance),
                          label: Text('Unit mismatch: $unitMismatchCount'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFFEE2E2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              'Nutrient-level diff table',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...comparisonRows.map(
              (label) => Focus(
                canRequestFocus: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FocusTraversalOrder(
                        order: NumericFocusOrder(
                          comparisonRows.indexOf(label).toDouble(),
                        ),
                        child: Semantics(
                          container: true,
                          label: 'Nutrient row ${label.label}',
                          child: Text(
                            label.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  label.hasVariance ||
                                      label.hasMissing ||
                                      label.hasUnitMismatch
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        container: true,
                        label: label.statusSummary,
                        child: FocusTraversalGroup(
                          policy: WidgetOrderTraversalPolicy(),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: label.cells
                                .asMap()
                                .entries
                                .map(
                                  (cellEntry) => FocusTraversalOrder(
                                    order: NumericFocusOrder(
                                      cellEntry.key.toDouble() + 0.5,
                                    ),
                                    child: Focus(
                                      canRequestFocus: true,
                                      child: _ComparisonValueChip(
                                        cell: cellEntry.value,
                                        minAmount: label.minAmount,
                                        maxAmount: label.maxAmount,
                                        hasVariance: label.hasVariance,
                                        textStyle: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                      if ((label.hasUnitMismatch || label.hasMissing) &&
                          label.cells.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            <String>[
                              if (label.hasMissing)
                                'Missing value(s) in selected foods',
                              if (label.hasUnitMismatch) ...[
                                if (label.unitSummary.isEmpty)
                                  'Unit inconsistency across selected foods'
                                else
                                  'Unit comparison note: ${label.unitSummary}',
                              ],
                            ].join(' | '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NutrientComparisonReading _normalizeNutrientForComparison({
    required double amount,
    required String unit,
  }) {
    final normalizedUnit = normalizeNutrientComparisonUnit(unit);
    final trimmedUnit = unit.trim();
    if (normalizedUnit == null) {
      return _NutrientComparisonReading(
        display: trimmedUnit.isEmpty
            ? amount.toString()
            : '$amount $trimmedUnit',
        canCompare: false,
        comparableAmount: null,
        normalizedUnit: trimmedUnit,
        rawUnit: trimmedUnit,
        wasNormalized: false,
      );
    }
    final comparableAmount = amount * normalizedUnit.scaleToCanonical;
    final shouldNormalize = normalizedUnit.scaleToCanonical != 1;
    final normalizedDisplayUnit = normalizedUnit.displayUnit;
    final display = shouldNormalize
        ? '$amount ${trimmedUnit.isEmpty ? '' : trimmedUnit}'
                  ' (≈${comparableAmount.toStringAsFixed(4)} $normalizedDisplayUnit)'
              .trim()
        : trimmedUnit.isEmpty
        ? amount.toString()
        : '$amount $trimmedUnit';
    return _NutrientComparisonReading(
      display: display,
      canCompare: true,
      comparableAmount: comparableAmount,
      normalizedUnit: normalizedDisplayUnit,
      rawUnit: trimmedUnit,
      wasNormalized: shouldNormalize,
    );
  }

  String _comparisonUnitSummary({
    required Set<String> normalizedUnits,
    required Set<String> incomparableUnits,
  }) {
    if (normalizedUnits.isEmpty && incomparableUnits.isEmpty) {
      return '';
    }
    final sortedNormalized = [...normalizedUnits]..sort();
    final sortedIncomparable = [...incomparableUnits]..sort();
    final normalizedText = sortedNormalized.isEmpty
        ? null
        : 'normalized to ${sortedNormalized.join(', ')}';
    final incomparableText = sortedIncomparable.isEmpty
        ? null
        : 'non-comparable units: ${sortedIncomparable.join(', ')}';
    if (normalizedText == null) {
      return incomparableText!;
    }
    if (incomparableText == null) {
      return normalizedText;
    }
    return '$normalizedText; $incomparableText';
  }

  String _comparisonRowSummaryText({
    required String label,
    required bool hasVariance,
    required bool hasMissing,
    required bool hasUnitMismatch,
    required String unitSummary,
  }) {
    if (!hasVariance && !hasMissing && !hasUnitMismatch) {
      return 'Nutrient $label: values are aligned and comparable.';
    }

    final notes = <String>[];
    if (hasVariance) {
      notes.add('normalized values differ across selected foods');
    }
    if (hasMissing) {
      notes.add('one or more selected foods are missing this nutrient');
    }
    if (hasUnitMismatch) {
      notes.add(
        unitSummary.isEmpty
            ? 'units are not comparable'
            : 'unit comparison note: $unitSummary',
      );
    }
    return 'Nutrient $label: ${notes.join('; ')}.';
  }

  List<_ActivityTraceSession> _activityTraceSessions(
    List<_ActivityTraceEntry> entries,
  ) {
    if (entries.isEmpty) {
      return const [];
    }

    final sessions = <_ActivityTraceSession>[];
    var current = <_ActivityTraceEntry>[entries.first];

    for (var i = 1; i < entries.length; i++) {
      final previous = entries[i - 1];
      final next = entries[i];
      final gap = previous.occurredAt.difference(next.occurredAt).abs();
      if (gap > _activityTraceSessionGap) {
        sessions.add(_ActivityTraceSession(entries: current));
        current = <_ActivityTraceEntry>[];
      }
      current.add(next);
    }
    sessions.add(_ActivityTraceSession(entries: current));
    return sessions;
  }

  String _activityTraceSessionSummary(_ActivityTraceSession session) {
    final actionCounts = <String, int>{};
    for (final entry in session.entries) {
      actionCounts[entry.action] = (actionCounts[entry.action] ?? 0) + 1;
    }

    final summaryParts = <String>[];
    for (final action in _activityTraceActionOrder) {
      final count = actionCounts[action];
      if (count != null) {
        summaryParts.add('${_activityTraceActionLabel(action)} x$count');
      }
    }
    final others =
        actionCounts.keys
            .where(
              (action) =>
                  !_activityTraceActionOrder.contains(action) &&
                  action.trim().isNotEmpty &&
                  action != 'all',
            )
            .toList(growable: false)
          ..sort();
    for (final action in others) {
      summaryParts.add('$action x${actionCounts[action]}');
    }
    return summaryParts.isEmpty ? 'No actions' : summaryParts.join(' / ');
  }

  String _activityTraceSessionTimeRange(_ActivityTraceSession session) {
    if (session.entries.isEmpty) {
      return 'empty';
    }
    final oldest = session.entries.last;
    final newest = session.entries.first;
    final rangeMinutes = newest.occurredAt
        .difference(oldest.occurredAt)
        .inMinutes;
    if (rangeMinutes <= 0) {
      return _formatActivityAt(newest.occurredAt);
    }
    return '${_formatActivityAt(oldest.occurredAt)} → ${_formatActivityAt(newest.occurredAt)}';
  }

  bool _canReplayActivitySession(_ActivityTraceSession session) {
    return session.entries.any(_canReplayActivity);
  }

  Widget _buildActivityTraceSessionSummaryChip(
    BuildContext context,
    _ActivityTraceSession session,
  ) {
    return InputChip(
      avatar: const Icon(Icons.history_toggle_off_outlined),
      label: Text(
        '${session.entries.length} traces: ${_activityTraceSessionSummary(session)}',
      ),
      onPressed: null,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }

  Widget _buildActivityTraceSession(
    BuildContext context,
    _ActivityTraceSession session,
  ) {
    final canReplay = _canReplayActivitySession(session);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text('Task loop • ${session.entries.length} trace(s)'),
        subtitle: Text(
          '${_activityTraceSessionTimeRange(session)} • ${_activityTraceSessionSummary(session)}',
        ),
        trailing: canReplay
            ? TextButton(
                onPressed: () => unawaited(_replayActivitySession(session)),
                child: const Text('Replay loop'),
              )
            : null,
      ),
    );
  }

  Future<void> _replayActivitySession(_ActivityTraceSession session) async {
    final replayEntries = session.entries
        .where(_canReplayActivity)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    for (final entry in replayEntries) {
      if (!mounted) {
        return;
      }
      await _replayActivity(entry);
    }
  }

  Widget _buildActivityTraceItem(
    BuildContext context,
    _ActivityTraceEntry entry,
  ) {
    final replayQuery = _activityReplayQuery(entry);
    final canReplay = _canReplayActivity(entry);
    return Card(
      child: ListTile(
        key: ValueKey(
          'activity-${entry.occurredAt.microsecondsSinceEpoch}-${entry.action}',
        ),
        leading: Icon(_iconForActivityAction(entry.action)),
        title: Text(entry.summary),
        subtitle: Text(
          '${_formatActivityAt(entry.occurredAt)} • ${entry.action}'
          '${replayQuery.isEmpty ? '' : ' • $replayQuery'}',
        ),
        trailing: canReplay
            ? TextButton(
                onPressed: () => unawaited(_replayActivity(entry)),
                child: const Text('Replay'),
              )
            : null,
      ),
    );
  }

  IconData _iconForActivityAction(String action) {
    return switch (action) {
      'search' => Icons.manage_search,
      'import' => Icons.cloud_download_outlined,
      'favorite' => Icons.star,
      'compare' => Icons.compare_arrows,
      'export' => Icons.file_download_outlined,
      'governance' => Icons.rule_folder_outlined,
      _ => Icons.timeline,
    };
  }

  String _activityTraceActionLabel(String action) {
    if (action == 'all') {
      return 'All';
    }
    return switch (action) {
      'search' => 'Search',
      'import' => 'Import',
      'favorite' => 'Favorite',
      'compare' => 'Compare',
      'export' => 'Export',
      'governance' => 'Governance',
      'other' => 'Other',
      _ => action,
    };
  }

  List<String> get _activityTraceFilterOptions {
    final presentActions = _activityTrace.map((entry) => entry.action).toSet();
    final options = <String>['all'];
    for (final action in _activityTraceActionOrder) {
      if (action == 'other') {
        continue;
      }
      if (presentActions.contains(action)) {
        options.add(action);
      }
    }
    final otherPresent = presentActions.where(
      (action) =>
          !_activityTraceActionOrder.contains(action) &&
          action.trim().isNotEmpty,
    );
    options.addAll(otherPresent.toList()..sort());
    return options;
  }

  List<_ActivityTraceEntry> get _filteredActivityTrace {
    if (_selectedActivityTraceAction == 'all') {
      return _activityTrace;
    }
    if (_activityTrace.every(
      (entry) => entry.action != _selectedActivityTraceAction,
    )) {
      return _activityTrace;
    }
    return _activityTrace
        .where((entry) => entry.action == _selectedActivityTraceAction)
        .toList(growable: false);
  }

  String _activityReplayQuery(_ActivityTraceEntry entry) {
    final value = entry.details['query'];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    final foodName = entry.details['foodName'];
    return foodName is String ? foodName : '';
  }

  bool _canReplayActivity(_ActivityTraceEntry entry) {
    if (entry.action == 'governance') {
      return false;
    }
    return _activityReplayQuery(entry).trim().isNotEmpty;
  }

  String _formatActivityAt(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFavoritePersistence() async {
    for (final loader in <Future<void> Function()>[
      _loadFavoriteFoods,
      _loadFavoriteFilterState,
      _loadFavoriteTemplates,
    ]) {
      try {
        await loader();
      } catch (_) {
        // Isolate repository read failures so later favorite state can load.
      }
    }
  }

  Future<void> _replayActivity(_ActivityTraceEntry entry) async {
    final query = _activityReplayQuery(entry).trim();
    if (query.isEmpty) {
      return;
    }
    _searchController.text = query;
    await _runSearch(query);
  }

  Future<void> _loadActivityTrace() async {
    try {
      final records = await ActivityTraceStore(widget.repository).load();
      _replaceActivityTraceRecords(records);
    } catch (_) {
      // Ignore malformed payloads for backward compatibility.
    }
  }

  Future<void> _appendActivityTrace({
    required String action,
    required String summary,
    required Map<String, Object?> details,
  }) async {
    try {
      await ActivityTraceStore(
        widget.repository,
      ).append(action: action, summary: summary, details: details);
    } catch (_) {
      // Activity trace persistence must not break the requested interaction.
    }
  }

  void _replaceActivityTraceRecords(List<Map<String, Object?>> records) {
    if (!mounted) {
      return;
    }
    final next = _activityTraceEntriesFromRecords(records);
    setState(() {
      _activityTrace
        ..clear()
        ..addAll(next);
    });
  }

  List<_ActivityTraceEntry> _activityTraceEntriesFromRecords(
    List<Map<String, Object?>> records,
  ) {
    final traces = <_ActivityTraceEntry>[];
    for (final record in records) {
      final trace = _ActivityTraceEntry.fromJson(record);
      if (trace != null) {
        traces.add(trace);
      }
    }
    return traces;
  }

  Future<void> _clearActivityTrace() async {
    try {
      await ActivityTraceStore(widget.repository).clear();
    } catch (_) {
      // Keep the current trace visible when persistence fails.
    }
  }

  Future<void> _toggleFavorite(FoodItem food) async {
    final next = List<_FavoriteFoodRef>.from(_favoriteFoods);
    final existsIndex = next.indexWhere((item) => item.foodId == food.id);
    final isAdded = existsIndex < 0;
    if (existsIndex >= 0) {
      next.removeAt(existsIndex);
    } else {
      next.insert(
        0,
        _FavoriteFoodRef(
          foodId: food.id,
          name: food.name,
          country: food.country,
          category: food.category,
          sourceName: food.sourceName,
        ),
      );
      if (next.length > _maxFavoriteFoods) {
        next.removeRange(_maxFavoriteFoods, next.length);
      }
    }

    setState(() {
      _favoriteFoods
        ..clear()
        ..addAll(next);
      _pruneUnavailableFavoriteFilters();
      _syncActiveFavoriteTemplateSelection();
    });
    unawaited(_persistFavoriteFilterState());
    await _persistFavoriteFoodsSafely(next);
    unawaited(
      _appendActivityTrace(
        action: 'favorite',
        summary: isAdded
            ? 'Added favorite: ${food.name}'
            : 'Removed favorite: ${food.name}',
        details: {
          'foodId': food.id,
          'foodName': food.name,
          'status': isAdded ? 'added' : 'removed',
        },
      ),
    );
  }

  void _removeFavoriteById(String foodId) {
    if (!_favoriteFoods.any((item) => item.foodId == foodId)) {
      return;
    }
    unawaited(
      _appendActivityTrace(
        action: 'favorite',
        summary: 'Removed favorite',
        details: {'foodId': foodId, 'status': 'removed'},
      ),
    );
    setState(() {
      _favoriteFoods.removeWhere((item) => item.foodId == foodId);
      _pruneUnavailableFavoriteFilters();
      _syncActiveFavoriteTemplateSelection();
    });
    unawaited(_persistFavoriteFilterState());
    unawaited(_persistFavoriteFoodsSafely(_favoriteFoods));
  }

  Future<void> _clearFavoriteFoods() async {
    if (_favoriteFoods.isNotEmpty) {
      unawaited(
        _appendActivityTrace(
          action: 'favorite',
          summary: 'Cleared all favorites',
          details: {'count': _favoriteFoods.length},
        ),
      );
    }
    setState(() {
      _favoriteFoods.clear();
      _clearFavoriteFilters();
      _syncActiveFavoriteTemplateSelection();
    });
    await _persistFavoriteFoodsSafely(const []);
  }

  Future<void> _replayFavorite(_FavoriteFoodRef favorite) async {
    _searchController.text = favorite.name;
    await _runSearch(favorite.name);
  }

  Future<void> _setMetaList({
    required String key,
    required List<String> values,
  }) async {
    final clamped = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    var payload = jsonEncode(clamped);
    if (AppMetaPayloadBudget.utf8ByteLength(payload) <=
        _maxAppMetaValueLength) {
      await _appMetaWriteQueue.enqueue(key, payload);
      return;
    }

    final compact = List<String>.from(clamped);
    while (compact.isNotEmpty) {
      compact.removeLast();
      final candidate = jsonEncode(compact);
      if (AppMetaPayloadBudget.utf8ByteLength(candidate) <=
          _maxAppMetaValueLength) {
        await _appMetaWriteQueue.enqueue(key, candidate);
        return;
      }
    }
    await _appMetaWriteQueue.enqueue(key, '[]');
  }

  Future<void> _setFavoriteFoods(List<_FavoriteFoodRef> favorites) async {
    final clamped = favorites.take(_maxFavoriteFoods).toList(growable: false);
    var payload = jsonEncode(clamped.map((item) => item.toJson()).toList());
    if (AppMetaPayloadBudget.utf8ByteLength(payload) <=
        _maxAppMetaValueLength) {
      await _appMetaWriteQueue.enqueue(_favoriteFoodsMetaKey, payload);
      return;
    }

    final compact = List<_FavoriteFoodRef>.from(clamped);
    while (compact.isNotEmpty) {
      compact.removeLast();
      final candidate = jsonEncode(
        compact.map((item) => item.toJson()).toList(),
      );
      if (AppMetaPayloadBudget.utf8ByteLength(candidate) <=
          _maxAppMetaValueLength) {
        await _appMetaWriteQueue.enqueue(_favoriteFoodsMetaKey, candidate);
        return;
      }
    }
    await _appMetaWriteQueue.enqueue(_favoriteFoodsMetaKey, '[]');
  }

  Future<void> _persistFavoriteFoodsSafely(
    List<_FavoriteFoodRef> favorites,
  ) async {
    try {
      await _setFavoriteFoods(favorites);
    } catch (_) {
      // Favorite persistence is supplemental; keep the in-memory toggle live.
    }
  }

  String _searchStatusText() {
    switch (_searchState.status) {
      case SearchStatus.idle:
        return 'Submit a query to search local data and trigger controlled official fetches.';
      case SearchStatus.local:
        return _searchState.message ?? 'Local results ready';
      case SearchStatus.fetching:
        return 'Fetching official data';
      case SearchStatus.archived:
        return 'Archived into local database';
      case SearchStatus.failed:
        return 'Fetch failed';
    }
  }

  void _handleSearchChanged(String value) {
    if (value.trim().isNotEmpty) {
      return;
    }
    _searchRequestGeneration += 1;
    _enrichmentTimer?.cancel();
    widget.searchOrchestrator.cancelEnrichment(_searchState.query);
    if (!mounted) {
      return;
    }
    setState(() {
      _enrichmentState = EnrichmentQueueState.idle();
      _searchErrorMessage = null;
      _failedSearchQuery = null;
    });
  }

  void _scheduleEnrichmentIfNeeded(SearchSessionState state) {
    _enrichmentTimer?.cancel();
    if (state.status != SearchStatus.archived || state.query.trim().isEmpty) {
      return;
    }

    _enrichmentTimer = Timer(const Duration(seconds: 2), () {
      widget.searchOrchestrator.scheduleEnrichment(
        state.query,
        state.activeSources,
      );
    });
  }

  Future<void> _handleEnrichmentState(EnrichmentQueueState state) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _enrichmentState = state;
    });

    if (state.activeQuery == null || state.activeQuery != _searchState.query) {
      return;
    }

    if (state.status == EnrichmentStatus.enriching ||
        state.status == EnrichmentStatus.completed ||
        state.status == EnrichmentStatus.failed) {
      final refreshGeneration = _searchRequestGeneration;
      await _refreshResults(_searchState.query, refreshGeneration);
    }
  }

  String _enrichmentStatusText() {
    final sources = _enrichmentState.activeSources
        .map(_displaySourceName)
        .join(', ');
    final suffix = sources.isEmpty ? '' : ' [$sources]';

    switch (_enrichmentState.status) {
      case EnrichmentStatus.idle:
        return '';
      case EnrichmentStatus.enriching:
        return 'Enriching related official data$suffix';
      case EnrichmentStatus.completed:
        return 'Completed background enrichment';
      case EnrichmentStatus.failed:
        return 'Background enrichment failed';
    }
  }

  String _displaySourceName(String importerId) {
    for (final entity in widget.entities) {
      for (final source in entity.sources) {
        if (source.id == importerId) {
          return source.name;
        }
      }
    }
    return importerId;
  }

  Future<void> _exportSearchSummaryJson() async {
    await _runExport(
      setLoading: (value) => _isExportingSummaryJson = value,
      action: () => widget.exportService.exportSearchResults(
        query: _searchController.text,
        format: ExportFormat.json,
        detailLevel: ExportDetailLevel.summary,
      ),
      actionLabel: 'search_summary_json',
    );
  }

  Future<void> _exportSearchDetailedCsv() async {
    await _runExport(
      setLoading: (value) => _isExportingDetailedCsv = value,
      action: () => widget.exportService.exportSearchResults(
        query: _searchController.text,
        format: ExportFormat.csv,
        detailLevel: ExportDetailLevel.detailed,
      ),
      actionLabel: 'search_detailed_csv',
    );
  }

  Future<void> _exportFavoriteComparisonSummaryJson() async {
    await _exportFavoriteComparison(
      format: ExportFormat.json,
      detailLevel: ExportDetailLevel.summary,
      setLoading: (value) => _isExportingCompareSummaryJson = value,
      actionLabel: 'compare_summary_json',
    );
  }

  Future<void> _exportFavoriteComparisonDetailedCsv() async {
    await _exportFavoriteComparison(
      format: ExportFormat.csv,
      detailLevel: ExportDetailLevel.detailed,
      setLoading: (value) => _isExportingCompareDetailedCsv = value,
      actionLabel: 'compare_detailed_csv',
    );
  }

  Future<void> _exportFavoriteComparison({
    required ExportFormat format,
    required ExportDetailLevel detailLevel,
    required void Function(bool value) setLoading,
    required String actionLabel,
  }) async {
    final ids = _compareFoodIds.take(_maxCompareFoods).toList(growable: false);
    if (ids.length < 2) {
      setState(() {
        _exportStatusMessage =
            'Select at least 2 foods before exporting comparison.';
      });
      return;
    }
    await _runExport(
      setLoading: setLoading,
      action: () => widget.exportService.exportFoodIds(
        foodIds: ids,
        format: format,
        detailLevel: detailLevel,
        scopeType: 'compare',
        scopeValue: ids.join('|'),
      ),
      actionLabel: actionLabel,
      traceQuery: _compareExportTraceQuery(),
    );
  }

  Future<void> _exportDatabaseSnapshot() async {
    await _runExport(
      setLoading: (value) => _isExportingSnapshot = value,
      action: widget.exportService.exportDatabaseSnapshot,
      actionLabel: 'database_snapshot',
    );
  }

  Future<void> _runExport({
    required void Function(bool value) setLoading,
    required Future<ExportArtifact> Function() action,
    required String actionLabel,
    String? traceQuery,
  }) async {
    final queryForTrace = traceQuery?.trim().isNotEmpty == true
        ? traceQuery!.trim()
        : _searchController.text.trim();
    setState(() {
      setLoading(true);
      _exportStatusMessage = null;
    });
    unawaited(
      _appendActivityTrace(
        action: 'export',
        summary: 'Started $actionLabel',
        details: {'mode': actionLabel, 'query': queryForTrace},
      ),
    );

    try {
      final artifact = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestExportArtifact = artifact;
        _exportStatusMessage =
            'Exported ${artifact.recordCount} records to ${artifact.path}';
      });
      unawaited(_appendRecentExportRecall(artifact.scopeLabel));
      unawaited(
        _appendActivityTrace(
          action: 'export',
          summary:
              'Exported ${artifact.recordCount} records (${artifact.format.name})',
          details: {
            'mode': actionLabel,
            'query': queryForTrace,
            'count': artifact.recordCount,
            'path': artifact.path,
          },
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatusMessage = 'Export failed: $error';
      });
      unawaited(
        _appendActivityTrace(
          action: 'export',
          summary: 'Export failed: $actionLabel',
          details: {
            'mode': actionLabel,
            'query': queryForTrace,
            'error': error.toString(),
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          setLoading(false);
        });
      }
    }
  }

  Future<void> _shareLatestExport() async {
    final artifact = _latestExportArtifact;
    if (artifact == null) {
      return;
    }
    setState(() {
      _isSharingExport = true;
      _exportStatusMessage = null;
    });
    try {
      await widget.exportShareService.shareFile(artifact.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatusMessage = 'Share sheet opened for ${artifact.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatusMessage = 'Share failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSharingExport = false;
        });
      }
    }
  }

  Future<void> _showFoodDetails(String canonicalFoodId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: FutureBuilder<FoodDetails?>(
            future: widget.repository.getFoodDetails(canonicalFoodId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const FoodDetailErrorState();
              }

              final details = snapshot.data;
              if (details == null) {
                return const FoodDetailErrorState(
                  message: 'No provenance records available yet',
                );
              }

              return FoodDetailSheet(details: details);
            },
          ),
        );
      },
    );
  }

  Widget _buildImporterCard(ImporterDescriptor descriptor) {
    final isImporting = _isImportingById[descriptor.importerId] ?? false;
    return _ImportCard(
      title: descriptor.displayName,
      description: descriptor.description,
      fields: [
        if (descriptor.requiresApiKey)
          _ImportField(
            label: descriptor.apiKeyLabel,
            child: TextField(
              controller: _apiKeyControllers[descriptor.importerId],
              decoration: InputDecoration(hintText: descriptor.apiKeyHint),
            ),
          ),
        if (descriptor.supportsDatasetPath)
          _ImportField(
            label: descriptor.pathLabel,
            child: TextField(
              controller: _pathControllers[descriptor.importerId],
              decoration: InputDecoration(hintText: descriptor.pathHint),
            ),
          ),
        if (descriptor.supportsQuery)
          _ImportField(
            label: descriptor.queryLabel,
            child: TextField(
              controller: _queryControllers[descriptor.importerId],
              decoration: InputDecoration(hintText: descriptor.queryHint),
            ),
          ),
      ],
      footer: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _limitController,
              decoration: const InputDecoration(labelText: 'Import limit'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: isImporting ? null : () => _runImporter(descriptor),
            icon: isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_iconFor(descriptor.inputKind)),
            label: Text(descriptor.buttonLabel),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ImporterInputKind inputKind) {
    return switch (inputKind) {
      ImporterInputKind.api => Icons.cloud_download_outlined,
      ImporterInputKind.directory => Icons.folder_zip_outlined,
      ImporterInputKind.singleFile => Icons.table_chart_outlined,
      ImporterInputKind.multiFileDirectory => Icons.dataset_outlined,
    };
  }
}

enum _FavoriteSortMode { recent, alpha }

class ExportCard extends StatelessWidget {
  const ExportCard({
    super.key,
    required this.onExportSummaryJson,
    required this.onExportDetailedCsv,
    required this.onExportSnapshot,
    required this.isExportingSummaryJson,
    required this.isExportingDetailedCsv,
    required this.isExportingSnapshot,
    required this.latestArtifact,
    required this.isSharing,
    required this.onShareLatest,
  });

  final VoidCallback? onExportSummaryJson;
  final VoidCallback? onExportDetailedCsv;
  final VoidCallback? onExportSnapshot;
  final bool isExportingSummaryJson;
  final bool isExportingDetailedCsv;
  final bool isExportingSnapshot;
  final ExportArtifact? latestArtifact;
  final bool isSharing;
  final VoidCallback? onShareLatest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Export the current local results as summary JSON, detailed CSV, or copy a full SQLite snapshot.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onExportSummaryJson,
                  icon: isExportingSummaryJson
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.data_object_outlined),
                  label: const Text('Export search summary JSON'),
                ),
                FilledButton.icon(
                  onPressed: onExportDetailedCsv,
                  icon: isExportingDetailedCsv
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_rows_outlined),
                  label: const Text('Export search detailed CSV'),
                ),
                FilledButton.icon(
                  onPressed: onExportSnapshot,
                  icon: isExportingSnapshot
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Export SQLite snapshot'),
                ),
                OutlinedButton.icon(
                  onPressed: onShareLatest,
                  icon: isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_outlined),
                  label: const Text('Share latest export'),
                ),
              ],
            ),
            if (latestArtifact != null) ...[
              const SizedBox(height: 8),
              Text(
                'Latest: ${latestArtifact!.recordCount} records at ${latestArtifact!.path}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdvancedFiltersCard extends StatelessWidget {
  const _AdvancedFiltersCard({
    required this.expanded,
    required this.selectedPreset,
    required this.countryController,
    required this.sourceController,
    required this.categoryController,
    required this.minController,
    required this.maxController,
    required this.onToggle,
    required this.onPresetChanged,
    required this.onApply,
    required this.onClear,
  });

  final bool expanded;
  final NutrientPreset? selectedPreset;
  final TextEditingController countryController;
  final TextEditingController sourceController;
  final TextEditingController categoryController;
  final TextEditingController minController;
  final TextEditingController maxController;
  final VoidCallback onToggle;
  final ValueChanged<NutrientPreset?> onPresetChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Advanced filters'),
            subtitle: const Text(
              'Local-only source, country, category, and nutrient range search.',
            ),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country filter',
                      hintText: 'e.g. Canada, Japan',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Source/importer filter',
                      hintText: 'e.g. canada-cnf, usda',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category filter',
                      hintText: 'e.g. fish, cereal',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<NutrientPreset>(
                    initialValue: selectedPreset,
                    decoration: const InputDecoration(
                      labelText: 'Nutrient preset',
                    ),
                    items: nutrientSearchPresets
                        .map(
                          (preset) => DropdownMenuItem(
                            value: preset,
                            child: Text('${preset.label} (${preset.unit})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onPresetChanged,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          decoration: const InputDecoration(labelText: 'Min'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          decoration: const InputDecoration(labelText: 'Max'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: onApply,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Apply filters'),
                      ),
                      TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.foodCount});

  final int foodCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DataHookClaws',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Persist official nutrition records locally, then search them without relying on demo data.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$foodCount records currently stored on device',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.title,
    required this.description,
    required this.fields,
    required this.footer,
  });

  final String title;
  final String description;
  final List<Widget> fields;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            ...fields,
            footer,
          ],
        ),
      ),
    );
  }
}

class _ImportField extends StatelessWidget {
  const _ImportField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label), const SizedBox(height: 6), child],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ImportLogCard extends StatelessWidget {
  const _ImportLogCard({required this.entry});

  final ImportLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = entry.status == 'success';
    final timestamp =
        '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')} '
        '${entry.createdAt.hour.toString().padLeft(2, '0')}:${entry.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSuccess
              ? const Color(0xFFDDF7E8)
              : const Color(0xFFFDE7E7),
          child: Icon(
            isSuccess ? Icons.check : Icons.error_outline,
            color: isSuccess
                ? const Color(0xFF166534)
                : const Color(0xFF991B1B),
          ),
        ),
        title: Text('${entry.sourceName} • ${entry.importedCount} records'),
        subtitle: Text(
          '${entry.message}\nQuery: ${entry.query.isEmpty ? '(none)' : entry.query}\n$timestamp',
          style: theme.textTheme.bodySmall,
        ),
        isThreeLine: true,
        trailing: Chip(label: Text(entry.status)),
      ),
    );
  }
}

class _AdministrativeEntityCard extends StatelessWidget {
  const _AdministrativeEntityCard({required this.entity});

  final AdministrativeFoodEntity entity;

  @override
  Widget build(BuildContext context) {
    final integrated = entity.sources.where((source) => source.isIntegrated);
    final cataloged = entity.sources.where((source) => !source.isIntegrated);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFD9F3F4),
                  child: Text(entity.code),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entity.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text('${entity.sources.length} source(s)')),
              ],
            ),
            const SizedBox(height: 12),
            ...entity.sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${source.name}\n'
                        '${source.authority} • ${source.endpointLabel}\n'
                        'Latest: ${source.latestReleaseLabel} (${source.latestReleaseDate})\n'
                        '${source.notes}\n'
                        '${source.officialUrl}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(label: Text(source.status)),
                  ],
                ),
              ),
            ),
            if (integrated.isNotEmpty || cataloged.isNotEmpty)
              Text(
                'Integrated: ${integrated.length} • Cataloged: ${cataloged.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
          ],
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.food,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.isCompared,
    required this.onToggleCompare,
  });

  final FoodItem food;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool isCompared;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: ValueKey('food-card-${food.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${food.category} • ${food.country} • ${food.sourceName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Chip(label: Text(food.servingBasis)),
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: onToggleCompare,
                        tooltip: isCompared
                            ? 'Remove from comparison'
                            : 'Add to comparison',
                        icon: Icon(
                          isCompared ? Icons.compare : Icons.compare_arrows,
                          color: isCompared ? const Color(0xFF2563EB) : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: onToggleFavorite,
                        tooltip: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View provenance',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF0E7490),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                food.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: food.tags
                    .map((tag) => Chip(label: Text(tag)))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: food.nutrients.map((nutrient) {
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nutrient.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${nutrient.amount} ${nutrient.unit}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Last updated ${food.lastUpdated.year}-${food.lastUpdated.month.toString().padLeft(2, '0')}-${food.lastUpdated.day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FoodDetailSheet extends StatelessWidget {
  const FoodDetailSheet({super.key, required this.details});

  final FoodDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final observationsBySource = <String, List<NutrientObservationView>>{};
    for (final observation in details.nutrientObservations) {
      observationsBySource.putIfAbsent(observation.sourceRecordId, () => []);
      observationsBySource[observation.sourceRecordId]!.add(observation);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            details.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${details.category} • ${details.countryHint}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(details.description),
                  const SizedBox(height: 8),
                  Text('Serving basis: ${details.servingBasis}'),
                  const SizedBox(height: 4),
                  Text(
                    'Last aggregated: ${_formatDateTime(details.lastAggregatedAt)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aggregated nutrients',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (details.aggregatedNutrients.isEmpty)
            const Card(
              child: ListTile(title: Text('No aggregated nutrients available')),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: details.aggregatedNutrients.map((nutrient) {
                    return Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nutrient.label),
                          const SizedBox(height: 6),
                          Text(
                            '${nutrient.amount} ${nutrient.unit}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Nutrient source comparison',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (details.nutrientComparisons.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No source-level nutrient observations available'),
              ),
            )
          else
            ...details.nutrientComparisons.map(
              (comparison) => Card(
                child: ExpansionTile(
                  title: Text(comparison.canonicalLabel),
                  subtitle: Text(
                    'Snapshot: ${comparison.aggregated == null ? '(missing)' : '${comparison.aggregated!.amount} ${comparison.aggregated!.unit}'} • ${comparison.varianceStatus.name}',
                  ),
                  children: comparison.observations.isEmpty
                      ? const [ListTile(title: Text('No source observations'))]
                      : comparison.observations
                            .map(
                              (observation) => ListTile(
                                title: Text(
                                  '${observation.amount} ${observation.unit}',
                                ),
                                subtitle: Text(
                                  '${observation.sourceName} • ${observation.country}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text(
                'This food currently merges ${details.sourceRecords.length} official source ${details.sourceRecords.length == 1 ? 'record' : 'records'} into one canonical entry',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Official sources',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!details.hasProvenance)
            const Card(
              child: ListTile(
                title: Text('No provenance records available yet'),
              ),
            )
          else
            ...details.sourceRecords.map((source) {
              final observations =
                  observationsBySource[source.id] ??
                  const <NutrientObservationView>[];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.sourceName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${source.country} • ${source.importerId}'),
                      const SizedBox(height: 4),
                      Text('Record id: ${source.sourceRecordId}'),
                      const SizedBox(height: 4),
                      Text('Fetched: ${_formatDateTime(source.fetchedAt)}'),
                      const SizedBox(height: 4),
                      Text(
                        'Source updated: ${_formatDateTime(source.sourceUpdatedAt)}',
                      ),
                      const SizedBox(height: 8),
                      Text(source.recordDescription),
                      const SizedBox(height: 12),
                      Text(
                        'Merge audit',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (source.mergeAudit == null)
                        const Text(
                          'No merge audit recorded for this source record',
                        )
                      else ...[
                        Text(
                          'Decision: ${source.mergeAudit!.reusedCanonical ? 'Reused canonical' : 'Created new canonical'}',
                        ),
                        const SizedBox(height: 4),
                        Text('Matched by: ${source.mergeAudit!.matchedBy}'),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: ${source.mergeAudit!.confidence.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 4),
                        Text('Reason: ${source.mergeAudit!.reason}'),
                        const SizedBox(height: 10),
                        Text(
                          'Candidate review',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (source.mergeAudit!.candidateEvaluations.isEmpty)
                          const Text(
                            'No canonical candidates were evaluated for this source record',
                          )
                        else
                          ...source.mergeAudit!.candidateEvaluations.map(
                            (candidate) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      candidate.candidateCanonicalFoodId,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Accepted: ${candidate.accepted ? 'yes' : 'no'}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Alias/category/serving: ${candidate.aliasMatched ? 'match' : 'mismatch'} / ${candidate.categoryMatched ? 'match' : 'mismatch'} / ${candidate.servingMatched ? 'match' : 'mismatch'}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nutrient similarity: ${candidate.nutrientSimilarity.toStringAsFixed(2)}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Reason: ${candidate.reason}'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (observations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Observations',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...observations.map(
                          (observation) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${observation.canonicalLabel}: ${observation.amount} ${observation.unit}',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            'Aliases',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (details.aliases.isEmpty)
            const Card(child: ListTile(title: Text('No aliases recorded')))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: details.aliases
                      .map((alias) => Chip(label: Text(alias)))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FoodDetailErrorState extends StatelessWidget {
  const FoodDetailErrorState({
    super.key,
    this.message = 'Failed to load provenance details',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Food details unavailable'),
            subtitle: Text(message),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _CompareNutrientCell {
  const _CompareNutrientCell({
    required this.foodId,
    required this.foodName,
    required this.display,
    required this.amount,
    required this.unit,
    required this.present,
  });

  final String foodId;
  final String foodName;
  final String display;
  final double? amount;
  final String? unit;
  final bool present;
}

class _CompareNutrientRow {
  const _CompareNutrientRow({
    required this.label,
    required this.cells,
    required this.hasVariance,
    required this.hasMissing,
    required this.hasUnitMismatch,
    required this.statusSummary,
    required this.unitSummary,
    required this.minAmount,
    required this.maxAmount,
  });

  final String label;
  final List<_CompareNutrientCell> cells;
  final bool hasVariance;
  final bool hasMissing;
  final bool hasUnitMismatch;
  final String statusSummary;
  final String unitSummary;
  final double? minAmount;
  final double? maxAmount;
}

class _ComparisonValueChip extends StatelessWidget {
  const _ComparisonValueChip({
    required this.cell,
    required this.minAmount,
    required this.maxAmount,
    required this.hasVariance,
    this.textStyle,
  });

  final _CompareNutrientCell cell;
  final double? minAmount;
  final double? maxAmount;
  final bool hasVariance;
  final TextStyle? textStyle;

  bool _isSameAmount(double left, double right) {
    return areNutrientComparisonAmountsEquivalent(left, right);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasComparableRange =
        hasVariance && minAmount != null && maxAmount != null;
    final isMaximum =
        hasComparableRange &&
        cell.amount != null &&
        maxAmount != null &&
        _isSameAmount(cell.amount!, maxAmount!);
    final isMinimum =
        hasComparableRange &&
        cell.amount != null &&
        minAmount != null &&
        _isSameAmount(cell.amount!, minAmount!);
    Color chipColor = const Color(0xFFF3F4F6);
    Color textColor = theme.colorScheme.onSurfaceVariant;
    if (!cell.present) {
      textColor = theme.colorScheme.onSurfaceVariant;
      chipColor = const Color(0xFFEFF2F7);
    } else if (isMaximum) {
      textColor = const Color(0xFFB91C1C);
      chipColor = const Color(0xFFFEE2E2);
    } else if (isMinimum) {
      textColor = const Color(0xFF047857);
      chipColor = const Color(0xFFD1FAE5);
    }
    final semanticsHint = !cell.present
        ? 'Missing value in this comparison.'
        : isMaximum
        ? 'This is the highest value among compared foods.'
        : isMinimum
        ? 'This is the lowest value among compared foods.'
        : 'Comparable value in the comparison set.';

    return Semantics(
      label:
          '${cell.foodName}: ${cell.display}${cell.present ? '' : ' (missing)'}',
      hint: semanticsHint,
      container: true,
      child: Chip(
        backgroundColor: chipColor,
        label: Text(
          '${cell.foodName}: ${cell.display}',
          style: (textStyle ?? theme.textTheme.bodySmall)?.copyWith(
            color: textColor,
            fontWeight: isMaximum || isMinimum
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NutrientComparisonReading {
  const _NutrientComparisonReading({
    required this.display,
    required this.canCompare,
    required this.comparableAmount,
    required this.normalizedUnit,
    required this.rawUnit,
    required this.wasNormalized,
  });

  final String display;
  final bool canCompare;
  final double? comparableAmount;
  final String normalizedUnit;
  final String rawUnit;
  final bool wasNormalized;
}

class _FavoriteFoodRef {
  const _FavoriteFoodRef({
    required this.foodId,
    required this.name,
    required this.country,
    required this.category,
    required this.sourceName,
  });

  final String foodId;
  final String name;
  final String country;
  final String category;
  final String sourceName;

  static _FavoriteFoodRef? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final foodId = value['foodId'];
    final name = value['name'];
    final country = value['country'];
    final category = value['category'];
    final sourceName = value['sourceName'];
    if (foodId is! String || name is! String) {
      return null;
    }
    if ((country != null && country is! String) ||
        (category != null && category is! String) ||
        (sourceName != null && sourceName is! String)) {
      return null;
    }
    final trimmedFoodId = foodId.trim();
    final trimmedName = name.trim();
    if (trimmedFoodId.isEmpty || trimmedName.isEmpty) {
      return null;
    }
    return _FavoriteFoodRef(
      foodId: trimmedFoodId,
      name: trimmedName,
      country: (country as String?)?.trim() ?? '',
      category: (category as String?)?.trim() ?? '',
      sourceName: (sourceName as String?)?.trim() ?? '',
    );
  }

  Map<String, String> toJson() {
    return {
      'foodId': foodId,
      'name': name,
      'country': country,
      'category': category,
      'sourceName': sourceName,
    };
  }
}

class _FavoriteTemplate {
  const _FavoriteTemplate({
    required this.id,
    required this.name,
    required this.countryFilter,
    required this.sourceFilter,
    required this.categoryFilter,
    required this.sortMode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? countryFilter;
  final String? sourceFilter;
  final String? categoryFilter;
  final _FavoriteSortMode sortMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  static _FavoriteTemplate? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final id = value['id'];
    final name = value['name'];
    final sortModeRaw = value['sortMode'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (sortModeRaw != null && sortModeRaw is! String)) {
      return null;
    }

    final countryFilter = value['countryFilter'];
    final sourceFilter = value['sourceFilter'];
    final categoryFilter = value['categoryFilter'];
    if ((countryFilter != null && countryFilter is! String) ||
        (sourceFilter != null && sourceFilter is! String) ||
        (categoryFilter != null && categoryFilter is! String)) {
      return null;
    }

    final createdAtRaw = value['createdAt'];
    final updatedAtRaw = value['updatedAt'];
    if ((createdAtRaw != null && createdAtRaw is! String) ||
        (updatedAtRaw != null && updatedAtRaw is! String)) {
      return null;
    }
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)
        : null;
    final updatedAt = updatedAtRaw is String
        ? DateTime.tryParse(updatedAtRaw)
        : null;
    if ((createdAtRaw != null && createdAt == null) ||
        (updatedAtRaw != null && updatedAt == null)) {
      return null;
    }
    return _FavoriteTemplate(
      id: id.trim(),
      name: name.trim(),
      countryFilter: countryFilter is String
          ? countryFilter.trim().isEmpty
                ? null
                : countryFilter.trim()
          : null,
      sourceFilter: sourceFilter is String
          ? sourceFilter.trim().isEmpty
                ? null
                : sourceFilter.trim()
          : null,
      categoryFilter: categoryFilter is String
          ? categoryFilter.trim().isEmpty
                ? null
                : categoryFilter.trim()
          : null,
      sortMode: sortModeRaw is String
          ? switch (sortModeRaw.trim().toLowerCase()) {
              'alpha' => _FavoriteSortMode.alpha,
              _ => _FavoriteSortMode.recent,
            }
          : _FavoriteSortMode.recent,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'countryFilter': countryFilter,
      'sourceFilter': sourceFilter,
      'categoryFilter': categoryFilter,
      'sortMode': sortMode == _FavoriteSortMode.alpha ? 'alpha' : 'recent',
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum _ExportRecallScopeType { search, country, favorites, compare }

class _ExportRecallCandidate {
  const _ExportRecallCandidate({
    required this.scopeType,
    required this.scopeValue,
  });

  final _ExportRecallScopeType scopeType;
  final String scopeValue;
}

class _ActivityTraceSession {
  _ActivityTraceSession({required this.entries})
    : assert(entries.isNotEmpty, 'Activity trace session cannot be empty.');

  final List<_ActivityTraceEntry> entries;
}

class _ActivityTraceEntry {
  const _ActivityTraceEntry({
    required this.occurredAt,
    required this.action,
    required this.summary,
    required this.details,
  });

  final DateTime occurredAt;
  final String action;
  final String summary;
  final Map<String, Object?> details;

  static _ActivityTraceEntry? fromJson(Map<String, Object?> source) {
    final action = source['action'];
    final summary = source['summary'];
    final occurredAtValue = source['occurredAt'];
    if (action is! String || summary is! String) {
      return null;
    }
    if (occurredAtValue is! String) {
      return null;
    }

    final dateTime = DateTime.tryParse(occurredAtValue);
    if (dateTime == null) {
      return null;
    }

    final rawDetails = source['details'];
    final details = <String, Object?>{};
    if (rawDetails is Map) {
      for (final key in rawDetails.keys) {
        final keyString = key.toString();
        if (keyString.trim().isEmpty) {
          continue;
        }
        final value = rawDetails[key];
        details[keyString] = value;
      }
    }

    return _ActivityTraceEntry(
      occurredAt: dateTime,
      action: action,
      summary: summary,
      details: details,
    );
  }
}
