import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/export_models.dart';
import '../../api/food_catalog_export_service.dart';
import '../../data/food_repository.dart';
import '../../data/importer_registry.dart';
import '../../data/national_food_sources.dart';
import '../../domain/export_share_service.dart';
import '../../domain/search_orchestrator.dart';
import '../../models/enrichment_queue_state.dart';
import '../../models/food_details.dart';
import '../../domain/sync_food_catalog_use_case.dart';
import '../../models/food_item.dart';
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

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _limitController = TextEditingController(text: '20');
  final _countryFilterController = TextEditingController();
  final _sourceFilterController = TextEditingController();
  final _categoryFilterController = TextEditingController();
  final _nutrientMinController = TextEditingController();
  final _nutrientMaxController = TextEditingController();
  final Map<String, TextEditingController> _apiKeyControllers = {};
  final Map<String, TextEditingController> _queryControllers = {};
  final Map<String, TextEditingController> _pathControllers = {};
  final Map<String, bool> _isImportingById = {};

  List<FoodItem> _results = const [];
  List<ImportLogEntry> _importLogs = const [];
  int _foodCount = 0;
  bool _isLoading = true;
  bool _isExportingSummaryJson = false;
  bool _isExportingDetailedCsv = false;
  bool _isExportingSnapshot = false;
  bool _isSharingExport = false;
  bool _showAdvancedFilters = false;
  String? _statusMessage;
  String? _exportStatusMessage;
  ExportArtifact? _latestExportArtifact;
  NutrientPreset? _selectedNutrientPreset;
  SearchSessionState _searchState = SearchSessionState.idle();
  EnrichmentQueueState _enrichmentState = EnrichmentQueueState.idle();
  StreamSubscription<EnrichmentQueueState>? _enrichmentSubscription;
  Timer? _enrichmentTimer;

  @override
  void initState() {
    super.initState();
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
    _refreshResults();
  }

  @override
  void dispose() {
    _enrichmentTimer?.cancel();
    _enrichmentSubscription?.cancel();
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
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _refreshResults([String? query]) async {
    setState(() {
      _isLoading = true;
    });

    final effectiveQuery = query ?? _searchController.text;
    final results = await widget.repository.searchFoods(effectiveQuery);
    final importLogs = await widget.repository.getImportLogs(limit: 10);
    final count = await widget.repository.countFoods();

    if (!mounted) {
      return;
    }

    setState(() {
      _results = results;
      _importLogs = importLogs;
      _foodCount = count;
      _isLoading = false;
    });
  }

  Future<void> _runImporter(ImporterDescriptor descriptor) async {
    final limit = int.tryParse(_limitController.text.trim()) ?? 20;
    setState(() {
      _isImportingById[descriptor.importerId] = true;
      _statusMessage = null;
    });

    try {
      final summary = await widget.syncUseCase.syncSource(
        importerId: descriptor.importerId,
        request: _buildImportRequest(descriptor, limit),
      );
      await _refreshResults();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = summary.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    final sources = widget.entities
        .expand((entity) => entity.sources)
        .toList(growable: false);

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
                    subtitle: Text(_exportStatusMessage!),
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSearch(String rawQuery) async {
    _enrichmentTimer?.cancel();
    await widget.searchOrchestrator.cancelEnrichment(_searchState.query);
    if (_hasAdvancedFilters) {
      await _runAdvancedSearch(rawQuery);
      return;
    }
    setState(() {
      _isLoading = true;
      _enrichmentState = EnrichmentQueueState.idle();
    });

    await for (final state in widget.searchOrchestrator.search(rawQuery)) {
      final importLogs = await widget.repository.getImportLogs(limit: 10);
      final count = await widget.repository.countFoods();
      if (!mounted) {
        return;
      }
      setState(() {
        _searchState = state;
        _results = state.combinedResults;
        _importLogs = importLogs;
        _foodCount = count;
        _isLoading = state.status == SearchStatus.fetching;
      });
      _scheduleEnrichmentIfNeeded(state);
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

  Future<void> _runAdvancedSearch(String rawQuery) async {
    setState(() {
      _isLoading = true;
      _enrichmentState = EnrichmentQueueState.idle();
    });
    final query = _advancedQuery(rawQuery);
    final results = await widget.repository.searchFoodsAdvanced(query);
    final importLogs = await widget.repository.getImportLogs(limit: 10);
    final count = await widget.repository.countFoods();
    if (!mounted) {
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
      _foodCount = count;
      _isLoading = false;
    });
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
    _enrichmentTimer?.cancel();
    widget.searchOrchestrator.cancelEnrichment(_searchState.query);
    if (!mounted) {
      return;
    }
    setState(() {
      _enrichmentState = EnrichmentQueueState.idle();
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
      await _refreshResults(_searchState.query);
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
    );
  }

  Future<void> _exportDatabaseSnapshot() async {
    await _runExport(
      setLoading: (value) => _isExportingSnapshot = value,
      action: widget.exportService.exportDatabaseSnapshot,
    );
  }

  Future<void> _runExport({
    required void Function(bool value) setLoading,
    required Future<ExportArtifact> Function() action,
  }) async {
    setState(() {
      setLoading(true);
      _exportStatusMessage = null;
    });

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
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _exportStatusMessage = 'Export failed: $error';
      });
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
  const _FoodCard({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Chip(label: Text(food.servingBasis)),
                      const SizedBox(height: 8),
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
