import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/food_repository.dart';
import '../../data/importer_registry.dart';
import '../../domain/activity_trace_store.dart';
import '../../domain/export_share_service.dart';
import '../../domain/merge_review_saved_view_store.dart';
import '../../domain/merge_review_worklist_store.dart';
import '../../domain/settings_service.dart';
import '../../domain/model_budget_controller.dart';
import '../../domain/source_capability_registry.dart';
import '../../domain/storage_budget_manager.dart';
import '../../domain/sync_food_catalog_use_case.dart';
import '../../models/dataset_artifact_entry.dart';
import '../../models/export_history_entry.dart';
import '../../models/fetch_job_entry.dart';
import '../../models/food_details.dart';
import '../../models/import_log_entry.dart';
import '../../models/import_models.dart';
import '../../models/manual_governance.dart';
import '../../models/merge_review_filter.dart';
import '../../models/merge_review_issue.dart';
import '../../models/merge_review_issue_query.dart';
import '../../models/merge_review_saved_view.dart';
import '../../models/merge_review_work_item.dart';
import '../home/home_page.dart';

enum _ReviewWorklistInventoryFilter { all, queued, deferred }

enum _ReviewWorklistInventoryPresenceFilter {
  all,
  onLoadedReviewPage,
  outsideLoadedReviewPage,
}

class OperationsPage extends StatefulWidget {
  const OperationsPage({
    super.key,
    required this.repository,
    required this.syncUseCase,
    required this.importerDescriptors,
    required this.sourceCapabilities,
    required this.storageBudgetManager,
    required this.modelBudgetController,
    required this.settingsService,
    required this.exportShareService,
    required this.onOpenSettings,
  });

  final FoodRepository repository;
  final SyncFoodCatalogUseCase syncUseCase;
  final List<ImporterDescriptor> importerDescriptors;
  final SourceCapabilityRegistry sourceCapabilities;
  final StorageBudgetManager storageBudgetManager;
  final ModelBudgetController modelBudgetController;
  final SettingsService settingsService;
  final ExportShareService exportShareService;
  final VoidCallback onOpenSettings;

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  static const String _reviewFilterMetaKey = 'merge_review_filter_v1';
  static const int _reviewIssuePageSize = 100;
  static const int _reviewWorklistInventoryPageSize = 20;

  List<FetchJobEntry> _jobs = const [];
  List<DatasetArtifactEntry> _artifacts = const [];
  List<ImportLogEntry> _logs = const [];
  MergeReviewIssuePage _reviewPage = MergeReviewIssuePage.empty;
  List<ExportHistoryEntry> _exportHistory = const [];
  List<ManualGovernanceLogEntry> _governanceLogs = const [];
  StorageBudgetSnapshot? _storageBudget;
  MergeReviewFilter _reviewFilter = MergeReviewFilter.all;
  MergeReviewFilter _appliedReviewFilter = MergeReviewFilter.all;
  late final MergeReviewSavedViewStore _reviewSavedViewStore;
  late final MergeReviewWorklistStore _reviewWorklistStore;
  List<MergeReviewSavedView> _reviewSavedViews = const [];
  List<MergeReviewWorkItem> _reviewWorklist = const [];
  String? _selectedReviewSavedViewId;
  Set<String> _selectedReviewIssueIds = <String>{};
  Future<void> _reviewFilterWriteQueue = Future<void>.value();
  bool _reviewSavedViewMutationInProgress = false;
  bool _reviewWorklistMutationInProgress = false;
  bool _reviewGovernanceActionInProgress = false;
  bool _refreshRequestedAfterWorklistMutation = false;
  bool _reviewWorklistInventoryExpanded = false;
  bool _loading = true;
  bool _hasAttemptedOperationsLoad = false;
  bool _reviewLoading = true;
  bool _hasLoadedReviewPage = false;
  bool _reviewWorklistLoading = false;
  bool _hasLoadedReviewWorklist = false;
  bool _hasAttemptedReviewWorklistLoad = false;
  String? _message;
  String? _operationsError;
  String? _reviewError;
  String? _reviewWorklistError;
  String? _reviewWorklistMutationMessage;
  bool _reviewWorklistMutationFailed = false;
  int _operationsRefreshGeneration = 0;
  int _reviewRefreshGeneration = 0;
  int _reviewWorklistRefreshGeneration = 0;
  int _reviewIssueOffset = 0;
  int _reviewWorklistInventoryOffset = 0;
  final TextEditingController _reviewWorklistInventorySearchController =
      TextEditingController();
  String _reviewWorklistInventorySearchQuery = '';
  _ReviewWorklistInventoryFilter _reviewWorklistInventoryFilter =
      _ReviewWorklistInventoryFilter.all;
  _ReviewWorklistInventoryPresenceFilter
  _reviewWorklistInventoryPresenceFilter =
      _ReviewWorklistInventoryPresenceFilter.all;

  @override
  void initState() {
    super.initState();
    _reviewSavedViewStore = MergeReviewSavedViewStore(widget.repository);
    _reviewWorklistStore = MergeReviewWorklistStore(widget.repository);
    _initialize();
  }

  @override
  void dispose() {
    _reviewWorklistInventorySearchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final reviewConfiguration = Future.wait<void>([
      _loadInitialReviewFilter(),
      _loadInitialReviewSavedViews(),
    ]);
    await Future.wait<void>([
      _refreshOperations(),
      _refreshReviewWorklist(),
      _initializeReviewPage(reviewConfiguration),
    ]);
  }

  Future<void> _initializeReviewPage(
    Future<List<void>> reviewConfiguration,
  ) async {
    await reviewConfiguration;
    if (!mounted) {
      return;
    }
    await _refreshReviewPage();
  }

  Future<void> _loadInitialReviewFilter() async {
    try {
      final rawFilter = await widget.repository.getAppMeta(
        _reviewFilterMetaKey,
      );
      _reviewFilter = MergeReviewFilter.decode(rawFilter);
    } catch (_) {
      _reviewFilter = MergeReviewFilter.all;
    }
  }

  Future<void> _loadInitialReviewSavedViews() async {
    try {
      _reviewSavedViews = await _reviewSavedViewStore.load();
    } catch (error) {
      _reviewSavedViews = const [];
      _message = 'Could not load saved review views: $error';
    }
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    if (_reviewWorklistMutationInProgress) {
      _refreshRequestedAfterWorklistMutation = true;
      return;
    }
    await Future.wait<void>([
      _refreshOperations(),
      _refreshReviewPage(),
      _refreshReviewWorklist(),
    ]);
  }

  Future<void> _refreshReviewWorklist() async {
    if (!mounted || _reviewWorklistMutationInProgress) {
      return;
    }
    final generation = ++_reviewWorklistRefreshGeneration;
    setState(() {
      _reviewWorklistLoading = true;
      _reviewWorklistError = null;
    });
    late final List<MergeReviewWorkItem> worklist;
    try {
      worklist = await _reviewWorklistStore.load();
    } catch (error) {
      if (!mounted || generation != _reviewWorklistRefreshGeneration) {
        return;
      }
      setState(() {
        _reviewWorklistLoading = false;
        _hasAttemptedReviewWorklistLoad = true;
        _reviewWorklistError = 'Could not refresh review worklist: $error';
      });
      return;
    }
    if (!mounted || generation != _reviewWorklistRefreshGeneration) {
      return;
    }
    setState(() {
      _applyReviewWorklistSnapshot(worklist);
      _reviewWorklistLoading = false;
      _hasLoadedReviewWorklist = true;
      _hasAttemptedReviewWorklistLoad = true;
      _reviewWorklistError = null;
    });
  }

  Future<void> _refreshOperations() async {
    if (!mounted) {
      return;
    }
    final operationsRefreshGeneration = ++_operationsRefreshGeneration;
    setState(() {
      _loading = true;
      _operationsError = null;
    });
    late final List<FetchJobEntry> jobs;
    late final List<DatasetArtifactEntry> artifacts;
    late final List<ImportLogEntry> logs;
    late final List<ExportHistoryEntry> exportHistory;
    late final List<ManualGovernanceLogEntry> governanceLogs;
    late final StorageBudgetSnapshot budget;
    try {
      jobs = await widget.repository.getRecentFetchJobs(limit: 50);
      artifacts = await widget.repository.getDatasetArtifacts(limit: 50);
      logs = await widget.repository.getImportLogs(limit: 100);
      exportHistory = await widget.repository.getExportHistory(limit: 20);
      governanceLogs = await widget.repository.getManualGovernanceLogs(
        limit: 20,
      );
      budget = await widget.storageBudgetManager.snapshot();
    } catch (error) {
      if (!mounted ||
          operationsRefreshGeneration != _operationsRefreshGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _hasAttemptedOperationsLoad = true;
        _operationsError = 'Could not refresh operations data: $error';
      });
      return;
    }
    if (!mounted ||
        operationsRefreshGeneration != _operationsRefreshGeneration) {
      return;
    }
    setState(() {
      _jobs = jobs;
      _artifacts = artifacts;
      _logs = logs;
      _exportHistory = exportHistory;
      _governanceLogs = governanceLogs;
      _storageBudget = budget;
      _loading = false;
      _hasAttemptedOperationsLoad = true;
      _operationsError = null;
    });
  }

  Future<void> _refreshReviewPage() async {
    if (!mounted || _reviewWorklistMutationInProgress) {
      return;
    }
    final reviewRefreshGeneration = ++_reviewRefreshGeneration;
    final reviewFilter = _reviewFilter;
    final reviewOffset = _reviewIssueOffset;
    final resetInventoryPresenceFilter =
        _reviewWorklistInventoryPresenceFilter !=
        _ReviewWorklistInventoryPresenceFilter.all;
    setState(() {
      _reviewLoading = true;
      _reviewError = null;
      if (resetInventoryPresenceFilter) {
        _reviewWorklistInventoryPresenceFilter =
            _ReviewWorklistInventoryPresenceFilter.all;
        _reviewWorklistInventoryOffset = 0;
      }
    });

    late final MergeReviewIssuePage reviewPage;
    try {
      reviewPage = await _loadReviewPage(
        filter: reviewFilter,
        offset: reviewOffset,
        reviewRefreshGeneration: reviewRefreshGeneration,
      );
    } catch (error) {
      if (!mounted || reviewRefreshGeneration != _reviewRefreshGeneration) {
        return;
      }
      setState(() {
        _reviewLoading = false;
        _reviewError = 'Could not refresh review issues: $error';
      });
      return;
    }

    if (!mounted || reviewRefreshGeneration != _reviewRefreshGeneration) {
      return;
    }
    final sameReviewPageContext =
        _hasLoadedReviewPage &&
        _appliedReviewFilter == reviewFilter &&
        _reviewPage.offset == reviewPage.offset;
    setState(() {
      _reviewPage = reviewPage;
      _reviewIssueOffset = reviewPage.offset;
      _appliedReviewFilter = reviewFilter;
      final visibleIds = reviewPage.items.map((issue) => issue.id).toSet();
      _selectedReviewIssueIds = sameReviewPageContext
          ? _selectedReviewIssueIds.intersection(visibleIds)
          : <String>{};
      _hasLoadedReviewPage = true;
      _reviewLoading = false;
      _reviewError = null;
    });
  }

  Future<MergeReviewIssuePage> _loadReviewPage({
    required MergeReviewFilter filter,
    required int offset,
    required int reviewRefreshGeneration,
  }) async {
    var reviewPage = await widget.repository.queryMergeReviewIssues(
      MergeReviewIssueQuery(
        filter: filter,
        offset: offset,
        limit: _reviewIssuePageSize,
      ),
    );
    if (reviewPage.items.isEmpty &&
        reviewPage.matchingCount > 0 &&
        offset >= reviewPage.matchingCount) {
      final correctedOffset =
          ((reviewPage.matchingCount - 1) ~/ _reviewIssuePageSize) *
          _reviewIssuePageSize;
      if (!mounted || reviewRefreshGeneration != _reviewRefreshGeneration) {
        // The outer generation guard discards this first page. Avoid dispatching
        // a new corrective repository read for a request that no longer owns it.
        return reviewPage;
      }
      reviewPage = await widget.repository.queryMergeReviewIssues(
        MergeReviewIssueQuery(
          filter: filter,
          offset: correctedOffset,
          limit: _reviewIssuePageSize,
        ),
      );
    }
    return reviewPage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleReviewIssues = _reviewPage.items;
    final visibleReviewIssueIds = visibleReviewIssues
        .map((issue) => issue.id)
        .toSet();
    final selectedVisibleReviewIssueCount = _selectedReviewIssueIds
        .where(visibleReviewIssueIds.contains)
        .length;
    final reviewWorklistByIssueId = <String, MergeReviewWorkItem>{
      for (final item in _reviewWorklist) item.issueId: item,
    };
    final selectedTrackedReviewIssueCount = visibleReviewIssues
        .where(
          (issue) =>
              _selectedReviewIssueIds.contains(issue.id) &&
              reviewWorklistByIssueId.containsKey(issue.id),
        )
        .length;
    final queuedReviewWorkItemCount = _reviewWorklist
        .where((item) => item.status == MergeReviewWorkItemStatus.queued)
        .length;
    final deferredReviewWorkItemCount =
        _reviewWorklist.length - queuedReviewWorkItemCount;
    final reviewResultsCurrent = _reviewResultsCurrent;
    final reviewPagePresenceAvailable = _reviewPagePresenceAvailable;
    final ({Set<String> issueIds, int onPageCount})? loadedReviewPagePresence =
        reviewPagePresenceAvailable
        ? (
            issueIds: visibleReviewIssueIds,
            onPageCount: _reviewWorklist
                .where((item) => visibleReviewIssueIds.contains(item.issueId))
                .length,
          )
        : null;
    final effectiveReviewWorklistInventoryPresenceFilter =
        loadedReviewPagePresence == null
        ? _ReviewWorklistInventoryPresenceFilter.all
        : _reviewWorklistInventoryPresenceFilter;
    final matchingReviewWorklistItems = _filterReviewWorklistInventory(
      _reviewWorklist,
      _reviewWorklistInventoryFilter,
      _reviewWorklistInventorySearchQuery,
      effectiveReviewWorklistInventoryPresenceFilter,
      loadedReviewPagePresence?.issueIds,
    );
    final reviewWorklistInventoryOffset =
        _normalizedReviewWorklistInventoryOffsetForCount(
          matchingReviewWorklistItems.length,
          _reviewWorklistInventoryOffset,
        );
    final visibleReviewWorklistItems = matchingReviewWorklistItems
        .skip(reviewWorklistInventoryOffset)
        .take(_reviewWorklistInventoryPageSize)
        .toList(growable: false);
    final reviewWorklistInventoryControlsEnabled =
        !_reviewWorklistLoading && !_reviewWorklistMutationInProgress;
    final canMutateSelectedReviewWorklist =
        !_reviewLoading &&
        !_reviewWorklistLoading &&
        _hasLoadedReviewWorklist &&
        _reviewWorklistError == null &&
        !_reviewGovernanceActionInProgress &&
        !_reviewWorklistMutationInProgress &&
        reviewResultsCurrent &&
        selectedVisibleReviewIssueCount > 0;
    final canClearReviewWorklist =
        !_reviewWorklistLoading &&
        _hasLoadedReviewWorklist &&
        _reviewWorklistError == null &&
        !_reviewGovernanceActionInProgress &&
        !_reviewWorklistMutationInProgress;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [
          IconButton(
            onPressed: _reviewWorklistMutationInProgress
                ? null
                : widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Open settings',
          ),
          IconButton(
            onPressed: _reviewWorklistMutationInProgress ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh operations data',
          ),
        ],
      ),
      body: _loading && !_hasAttemptedOperationsLoad
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading) ...[
                  const LinearProgressIndicator(
                    key: Key('operations_refresh_loading'),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Runtime controls',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inspect fetches, local artifacts, source readiness, and resource budgets before expanding automatic ingestion.',
                ),
                if (_operationsError != null) ...[
                  const SizedBox(height: 12),
                  _RetryErrorCard(
                    cardKey: const Key('operations_refresh_error'),
                    retryKey: const Key('operations_refresh_retry'),
                    message: _operationsError!,
                    onRetry: _loading
                        ? null
                        : () => unawaited(_refreshOperations()),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFF3FBFD),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Operation status'),
                      subtitle: Text(_message!),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _BudgetsCard(
                  storageBudget: _storageBudget,
                  modelBudget: widget.modelBudgetController.snapshot(),
                ),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Export history',
                  count: _exportHistory.length,
                ),
                const SizedBox(height: 8),
                if (_exportHistory.isEmpty)
                  const _EmptyCard(message: 'No exports recorded yet.')
                else
                  ..._exportHistory.map(_buildExportHistoryCard),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Data quality review',
                  count: visibleReviewIssues.length,
                ),
                const SizedBox(height: 8),
                _ReviewFilterCard(
                  filter: _reviewFilter,
                  savedViews: _reviewSavedViews,
                  selectedSavedViewId: _selectedReviewSavedViewId,
                  savedViewMutationInProgress:
                      _reviewSavedViewMutationInProgress,
                  visibleCount: visibleReviewIssues.length,
                  matchingCount: _reviewPage.matchingCount,
                  totalCount: _reviewPage.totalCount,
                  offset: _reviewPage.offset,
                  loading: _reviewLoading,
                  resultsCurrent: reviewResultsCurrent,
                  selectedCount: selectedVisibleReviewIssueCount,
                  queuedWorkItemCount: queuedReviewWorkItemCount,
                  deferredWorkItemCount: deferredReviewWorkItemCount,
                  worklistMutationInProgress: _reviewWorklistMutationInProgress,
                  worklistLoading:
                      _reviewWorklistLoading ||
                      !_hasAttemptedReviewWorklistLoad,
                  worklistAvailable: _hasLoadedReviewWorklist,
                  worklistMutationMessage: _reviewWorklistMutationMessage,
                  worklistMutationFailed: _reviewWorklistMutationFailed,
                  allVisibleSelected:
                      visibleReviewIssues.isNotEmpty &&
                      visibleReviewIssues.every(
                        (issue) => _selectedReviewIssueIds.contains(issue.id),
                      ),
                  onSeverityChanged: (severity) {
                    _setReviewFilter(_reviewFilter.withSeverity(severity));
                  },
                  onTypeChanged: (type) {
                    _setReviewFilter(_reviewFilter.withType(type));
                  },
                  onClear: _reviewFilter.isActive
                      ? () => _setReviewFilter(MergeReviewFilter.all)
                      : null,
                  onSaveView: _reviewFilter.isActive
                      ? () => unawaited(_saveReviewView())
                      : null,
                  onApplyView: _applyReviewSavedView,
                  onDeleteView: (view) {
                    unawaited(_deleteReviewSavedView(view));
                  },
                  onSelectVisible:
                      !_reviewLoading &&
                          !_reviewWorklistMutationInProgress &&
                          reviewResultsCurrent &&
                          visibleReviewIssues.isNotEmpty
                      ? _selectVisibleReviewIssues
                      : null,
                  onClearSelection:
                      !_reviewWorklistMutationInProgress &&
                          _selectedReviewIssueIds.isNotEmpty
                      ? _clearReviewIssueSelection
                      : null,
                  onQueueSelected: canMutateSelectedReviewWorklist
                      ? () => unawaited(
                          _setSelectedReviewWorklistStatus(
                            MergeReviewWorkItemStatus.queued,
                          ),
                        )
                      : null,
                  onDeferSelected: canMutateSelectedReviewWorklist
                      ? () => unawaited(
                          _setSelectedReviewWorklistStatus(
                            MergeReviewWorkItemStatus.deferred,
                          ),
                        )
                      : null,
                  onUntrackSelected:
                      canMutateSelectedReviewWorklist &&
                          selectedTrackedReviewIssueCount > 0
                      ? () => unawaited(_untrackSelectedReviewIssues())
                      : null,
                  onClearWorklist: canClearReviewWorklist
                      ? () => unawaited(_confirmAndClearReviewWorklist())
                      : null,
                  onPrevious:
                      !_reviewLoading &&
                          !_reviewWorklistMutationInProgress &&
                          reviewResultsCurrent &&
                          _reviewPage.hasPrevious
                      ? () => _setReviewOffset(_reviewPage.previousOffset)
                      : null,
                  onNext:
                      !_reviewLoading &&
                          !_reviewWorklistMutationInProgress &&
                          reviewResultsCurrent &&
                          _reviewPage.hasNext
                      ? () => _setReviewOffset(_reviewPage.nextOffset)
                      : null,
                ),
                if (_reviewWorklistLoading) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    label: 'Loading review worklist',
                    child: const LinearProgressIndicator(
                      key: Key('operations_review_worklist_loading'),
                    ),
                  ),
                ],
                if (_reviewWorklistError != null) ...[
                  const SizedBox(height: 8),
                  _RetryErrorCard(
                    cardKey: const Key('operations_review_worklist_error'),
                    retryKey: const Key('operations_review_worklist_retry'),
                    message: _reviewWorklistError!,
                    onRetry:
                        _reviewWorklistLoading ||
                            _reviewWorklistMutationInProgress
                        ? null
                        : () => unawaited(_refreshReviewWorklist()),
                  ),
                ],
                if (_hasLoadedReviewWorklist) ...[
                  const SizedBox(height: 8),
                  _ReviewWorklistInventoryPanel(
                    key: const ValueKey<String>(
                      'operations_review_worklist_inventory_panel',
                    ),
                    items: visibleReviewWorklistItems,
                    totalCount: _reviewWorklist.length,
                    matchingCount: matchingReviewWorklistItems.length,
                    queuedCount: queuedReviewWorkItemCount,
                    deferredCount: deferredReviewWorkItemCount,
                    offset: reviewWorklistInventoryOffset,
                    pageSize: _reviewWorklistInventoryPageSize,
                    filter: _reviewWorklistInventoryFilter,
                    searchController: _reviewWorklistInventorySearchController,
                    searchQuery: _reviewWorklistInventorySearchQuery,
                    loadedReviewPagePresence: loadedReviewPagePresence,
                    presenceFilter:
                        effectiveReviewWorklistInventoryPresenceFilter,
                    expanded: _reviewWorklistInventoryExpanded,
                    onExpansionChanged: (expanded) {
                      if (expanded == _reviewWorklistInventoryExpanded) {
                        return;
                      }
                      setState(() {
                        _reviewWorklistInventoryExpanded = expanded;
                      });
                    },
                    onFilterChanged: reviewWorklistInventoryControlsEnabled
                        ? _setReviewWorklistInventoryFilter
                        : null,
                    onPresenceFilterChanged:
                        reviewWorklistInventoryControlsEnabled &&
                            loadedReviewPagePresence != null
                        ? _setReviewWorklistInventoryPresenceFilter
                        : null,
                    onSearchChanged: reviewWorklistInventoryControlsEnabled
                        ? _setReviewWorklistInventorySearchQuery
                        : null,
                    onClearSearch:
                        reviewWorklistInventoryControlsEnabled &&
                            _reviewWorklistInventorySearchQuery.isNotEmpty
                        ? _clearReviewWorklistInventorySearch
                        : null,
                    onPrevious:
                        reviewWorklistInventoryControlsEnabled &&
                            reviewWorklistInventoryOffset > 0
                        ? () => _setReviewWorklistInventoryOffset(
                            reviewWorklistInventoryOffset -
                                _reviewWorklistInventoryPageSize,
                          )
                        : null,
                    onNext:
                        reviewWorklistInventoryControlsEnabled &&
                            reviewWorklistInventoryOffset +
                                    visibleReviewWorklistItems.length <
                                matchingReviewWorklistItems.length
                        ? () => _setReviewWorklistInventoryOffset(
                            reviewWorklistInventoryOffset +
                                _reviewWorklistInventoryPageSize,
                          )
                        : null,
                  ),
                ],
                if (_reviewLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    key: Key('operations_review_loading'),
                  ),
                ],
                if (_reviewError != null) ...[
                  const SizedBox(height: 8),
                  _RetryErrorCard(
                    cardKey: const Key('operations_review_error'),
                    retryKey: const Key('operations_review_retry'),
                    message: _reviewError!,
                    onRetry: _reviewLoading || _reviewWorklistMutationInProgress
                        ? null
                        : () => unawaited(_refreshReviewPage()),
                  ),
                ],
                const SizedBox(height: 8),
                if (!reviewResultsCurrent)
                  const SizedBox.shrink()
                else if (_reviewPage.totalCount == 0)
                  const _EmptyCard(
                    message: 'No merge or observation review issues found.',
                  )
                else if (_reviewPage.matchingCount == 0)
                  const _EmptyCard(
                    message: 'No review issues match the selected filters.',
                  )
                else if (visibleReviewIssues.isEmpty)
                  const _EmptyCard(
                    message: 'No review issues are available on this page.',
                  )
                else
                  ...visibleReviewIssues.map(
                    (issue) => _buildReviewIssueCard(
                      issue,
                      selectionEnabled:
                          !_reviewLoading && !_reviewWorklistMutationInProgress,
                      workItem: reviewWorklistByIssueId[issue.id],
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Manual governance log',
                  count: _governanceLogs.length,
                ),
                const SizedBox(height: 8),
                if (_governanceLogs.isEmpty)
                  const _EmptyCard(
                    message: 'No manual merge/split/override actions yet.',
                  )
                else
                  ..._governanceLogs.map(_buildGovernanceLogCard),
                const SizedBox(height: 20),
                _SectionTitle(title: 'Fetch jobs', count: _jobs.length),
                const SizedBox(height: 8),
                if (_jobs.isEmpty)
                  const _EmptyCard(message: 'No fetch jobs recorded yet.')
                else
                  ..._jobs.map(_buildJobCard),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Dataset artifacts',
                  count: _artifacts.length,
                ),
                const SizedBox(height: 8),
                if (_artifacts.isEmpty)
                  const _EmptyCard(
                    message: 'No dataset artifacts recorded yet.',
                  )
                else
                  ..._artifacts.map(_buildArtifactCard),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: 'Importer diagnostics',
                  count: widget.sourceCapabilities.all.length,
                ),
                const SizedBox(height: 8),
                ...widget.sourceCapabilities.all.map(_buildDiagnosticCard),
              ],
            ),
    );
  }

  bool get _reviewResultsCurrent =>
      _hasLoadedReviewPage &&
      _appliedReviewFilter == _reviewFilter &&
      _reviewPage.offset == _reviewIssueOffset;

  bool get _reviewPagePresenceAvailable =>
      _reviewResultsCurrent && !_reviewLoading && _reviewError == null;

  Set<String>? get _loadedReviewPageIssueIdsForInventory {
    if (!_reviewPagePresenceAvailable) {
      return null;
    }
    return _reviewPage.items.map((issue) => issue.id).toSet();
  }

  void _setReviewFilter(
    MergeReviewFilter nextFilter, {
    String? savedViewId,
    bool forceClearSelection = false,
  }) {
    if (_reviewWorklistMutationInProgress) {
      return;
    }
    final filterChanged = nextFilter != _reviewFilter;
    final offsetChanged = _reviewIssueOffset != 0;
    final selectionChanged = savedViewId != _selectedReviewSavedViewId;
    final reviewSelectionChanged =
        forceClearSelection && _selectedReviewIssueIds.isNotEmpty;
    if (!filterChanged &&
        !offsetChanged &&
        !selectionChanged &&
        !reviewSelectionChanged) {
      return;
    }
    setState(() {
      _reviewFilter = nextFilter;
      _reviewIssueOffset = 0;
      _selectedReviewSavedViewId = savedViewId;
      _selectedReviewIssueIds = <String>{};
    });

    if (!filterChanged && !offsetChanged) {
      return;
    }

    final payload = nextFilter.encode();
    _reviewFilterWriteQueue = _reviewFilterWriteQueue.then((_) async {
      try {
        await widget.repository.setAppMeta(_reviewFilterMetaKey, payload);
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _message = 'Could not save review filters: $error';
        });
      }
    });
    unawaited(_refreshReviewPage());
  }

  Future<void> _saveReviewView() async {
    if (_reviewSavedViewMutationInProgress ||
        _reviewWorklistMutationInProgress ||
        !_reviewFilter.isActive) {
      return;
    }
    final filter = _reviewFilter;
    final formKey = GlobalKey<FormState>();
    var draftName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save review view'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('operations_review_saved_view_name'),
            autofocus: true,
            maxLength: MergeReviewSavedView.maxNameLength,
            onChanged: (value) {
              draftName = value;
            },
            decoration: const InputDecoration(
              labelText: 'View name',
              hintText: 'High category conflicts',
            ),
            validator: (value) {
              try {
                MergeReviewSavedView.normalizeName(value ?? '');
                return null;
              } on ArgumentError {
                return 'Enter a name between 1 and 80 characters.';
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('operations_review_saved_view_confirm'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(draftName);
              }
            },
            child: const Text('Save view'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) {
      return;
    }

    setState(() {
      _reviewSavedViewMutationInProgress = true;
    });
    try {
      final views = await _reviewSavedViewStore.save(
        name: name,
        filter: filter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSavedViews = views;
        _reviewSavedViewMutationInProgress = false;
        _message =
            'Saved review view: ${MergeReviewSavedView.normalizeName(name)}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSavedViewMutationInProgress = false;
        _message = 'Could not save review view: $error';
      });
    }
  }

  void _applyReviewSavedView(MergeReviewSavedView view) {
    if (_reviewWorklistMutationInProgress) {
      return;
    }
    _setReviewFilter(
      view.filter,
      savedViewId: view.id,
      forceClearSelection: true,
    );
  }

  Future<void> _deleteReviewSavedView(MergeReviewSavedView view) async {
    if (_reviewSavedViewMutationInProgress ||
        _reviewWorklistMutationInProgress) {
      return;
    }
    setState(() {
      _reviewSavedViewMutationInProgress = true;
    });
    try {
      final views = await _reviewSavedViewStore.remove(view.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSavedViews = views;
        _reviewSavedViewMutationInProgress = false;
        if (_selectedReviewSavedViewId == view.id) {
          _selectedReviewSavedViewId = null;
        }
        _message = 'Deleted saved review view: ${view.name}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reviewSavedViewMutationInProgress = false;
        _message = 'Could not delete saved review view: $error';
      });
    }
  }

  void _setReviewOffset(int nextOffset) {
    if (_reviewWorklistMutationInProgress ||
        nextOffset == _reviewIssueOffset ||
        nextOffset < 0) {
      return;
    }
    setState(() {
      _reviewIssueOffset = nextOffset;
      _selectedReviewIssueIds = <String>{};
    });
    unawaited(_refreshReviewPage());
  }

  void _selectVisibleReviewIssues() {
    if (_reviewLoading ||
        _reviewWorklistMutationInProgress ||
        !_reviewResultsCurrent) {
      return;
    }
    final visibleIds = _reviewPage.items.map((issue) => issue.id).toSet();
    if (visibleIds.isEmpty ||
        (visibleIds.length == _selectedReviewIssueIds.length &&
            visibleIds.containsAll(_selectedReviewIssueIds))) {
      return;
    }
    setState(() {
      _selectedReviewIssueIds = visibleIds;
    });
  }

  void _clearReviewIssueSelection() {
    if (_reviewWorklistMutationInProgress || _selectedReviewIssueIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedReviewIssueIds = <String>{};
    });
  }

  void _setReviewIssueSelected(String issueId, {required bool selected}) {
    if (_reviewLoading ||
        _reviewWorklistMutationInProgress ||
        !_reviewResultsCurrent ||
        !_reviewPage.items.any((issue) => issue.id == issueId)) {
      return;
    }
    if (selected == _selectedReviewIssueIds.contains(issueId)) {
      return;
    }
    setState(() {
      final nextIds = Set<String>.of(_selectedReviewIssueIds);
      if (selected) {
        nextIds.add(issueId);
      } else {
        nextIds.remove(issueId);
      }
      _selectedReviewIssueIds = nextIds;
    });
  }

  List<MergeReviewIssue> _selectedVisibleReviewIssues() {
    if (_reviewLoading ||
        _reviewWorklistLoading ||
        !_hasLoadedReviewWorklist ||
        _reviewWorklistError != null ||
        _reviewGovernanceActionInProgress ||
        _reviewWorklistMutationInProgress ||
        !_reviewResultsCurrent) {
      return const [];
    }
    return _reviewPage.items
        .where((issue) => _selectedReviewIssueIds.contains(issue.id))
        .toList(growable: false);
  }

  Future<void> _setSelectedReviewWorklistStatus(
    MergeReviewWorkItemStatus status,
  ) async {
    final selectedIssues = _selectedVisibleReviewIssues();
    if (selectedIssues.isEmpty) {
      return;
    }
    final submittedIds = selectedIssues.map((issue) => issue.id).toSet();
    setState(() {
      _reviewWorklistMutationInProgress = true;
      _reviewWorklistMutationMessage = null;
      _reviewWorklistMutationFailed = false;
    });
    try {
      final worklist = await _reviewWorklistStore.upsertAll([
        for (final issue in selectedIssues)
          MergeReviewWorklistUpsert(issue: issue, status: status),
      ]);
      if (!mounted) {
        return;
      }
      final action = switch (status) {
        MergeReviewWorkItemStatus.queued => 'Queued',
        MergeReviewWorkItemStatus.deferred => 'Deferred',
      };
      final resultMessage =
          '$action ${selectedIssues.length} review '
          '${selectedIssues.length == 1 ? 'issue' : 'issues'}. '
          'No governance action was executed.';
      setState(() {
        _applyReviewWorklistSnapshot(worklist);
        _hasLoadedReviewWorklist = true;
        _hasAttemptedReviewWorklistLoad = true;
        _reviewWorklistError = null;
        _reviewWorklistMutationInProgress = false;
        _selectedReviewIssueIds = Set<String>.of(_selectedReviewIssueIds)
          ..removeAll(submittedIds);
        _reviewWorklistMutationMessage = resultMessage;
        _reviewWorklistMutationFailed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMessage = 'Could not update review worklist: $error';
      setState(() {
        _reviewWorklistMutationInProgress = false;
        _reviewWorklistMutationMessage = errorMessage;
        _reviewWorklistMutationFailed = true;
      });
    }
    _runDeferredRefreshIfNeeded();
  }

  Future<void> _untrackSelectedReviewIssues() async {
    final selectedIssues = _selectedVisibleReviewIssues();
    if (selectedIssues.isEmpty) {
      return;
    }
    final trackedIds = _reviewWorklist.map((item) => item.issueId).toSet();
    final selectedTrackedIds = selectedIssues
        .map((issue) => issue.id)
        .where(trackedIds.contains)
        .toList(growable: false);
    if (selectedTrackedIds.isEmpty) {
      return;
    }
    setState(() {
      _reviewWorklistMutationInProgress = true;
      _reviewWorklistMutationMessage = null;
      _reviewWorklistMutationFailed = false;
    });
    try {
      final worklist = await _reviewWorklistStore.removeAll(selectedTrackedIds);
      if (!mounted) {
        return;
      }
      final resultMessage =
          'Removed ${selectedTrackedIds.length} review '
          '${selectedTrackedIds.length == 1 ? 'issue' : 'issues'} from '
          'the worklist. No governance action was executed.';
      setState(() {
        _applyReviewWorklistSnapshot(worklist);
        _hasLoadedReviewWorklist = true;
        _hasAttemptedReviewWorklistLoad = true;
        _reviewWorklistError = null;
        _reviewWorklistMutationInProgress = false;
        _selectedReviewIssueIds = Set<String>.of(_selectedReviewIssueIds)
          ..removeAll(selectedTrackedIds);
        _reviewWorklistMutationMessage = resultMessage;
        _reviewWorklistMutationFailed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMessage = 'Could not update review worklist: $error';
      setState(() {
        _reviewWorklistMutationInProgress = false;
        _reviewWorklistMutationMessage = errorMessage;
        _reviewWorklistMutationFailed = true;
      });
    }
    _runDeferredRefreshIfNeeded();
  }

  Future<void> _confirmAndClearReviewWorklist() async {
    if (_reviewWorklistLoading ||
        !_hasLoadedReviewWorklist ||
        _reviewWorklistError != null ||
        _reviewGovernanceActionInProgress ||
        _reviewWorklistMutationInProgress) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear review worklist?'),
        content: const Text(
          'This removes every queued and deferred review snapshot. It does '
          'not merge, split, override, or otherwise change food data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('operations_review_worklist_clear_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear worklist'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _reviewWorklistLoading ||
        !_hasLoadedReviewWorklist ||
        _reviewWorklistError != null ||
        _reviewGovernanceActionInProgress ||
        _reviewWorklistMutationInProgress) {
      return;
    }
    setState(() {
      _reviewWorklistMutationInProgress = true;
      _reviewWorklistMutationMessage = null;
      _reviewWorklistMutationFailed = false;
    });
    try {
      await _reviewWorklistStore.clear();
      if (!mounted) {
        return;
      }
      const resultMessage =
          'Cleared the review worklist. No governance action was executed.';
      setState(() {
        _applyReviewWorklistSnapshot(const []);
        _hasLoadedReviewWorklist = true;
        _hasAttemptedReviewWorklistLoad = true;
        _reviewWorklistError = null;
        _reviewWorklistMutationInProgress = false;
        _reviewWorklistMutationMessage = resultMessage;
        _reviewWorklistMutationFailed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMessage = 'Could not clear review worklist: $error';
      setState(() {
        _reviewWorklistMutationInProgress = false;
        _reviewWorklistMutationMessage = errorMessage;
        _reviewWorklistMutationFailed = true;
      });
    }
    _runDeferredRefreshIfNeeded();
  }

  void _runDeferredRefreshIfNeeded() {
    if (!mounted ||
        _reviewWorklistMutationInProgress ||
        !_refreshRequestedAfterWorklistMutation) {
      return;
    }
    _refreshRequestedAfterWorklistMutation = false;
    unawaited(_refresh());
  }

  void _applyReviewWorklistSnapshot(List<MergeReviewWorkItem> worklist) {
    _reviewWorklist = worklist;
    final loadedReviewPageIssueIds = _loadedReviewPageIssueIdsForInventory;
    final presenceFilter = loadedReviewPageIssueIds == null
        ? _ReviewWorklistInventoryPresenceFilter.all
        : _reviewWorklistInventoryPresenceFilter;
    final matchingCount = _filterReviewWorklistInventory(
      worklist,
      _reviewWorklistInventoryFilter,
      _reviewWorklistInventorySearchQuery,
      presenceFilter,
      loadedReviewPageIssueIds,
    ).length;
    _reviewWorklistInventoryOffset =
        _normalizedReviewWorklistInventoryOffsetForCount(
          matchingCount,
          _reviewWorklistInventoryOffset,
        );
  }

  List<MergeReviewWorkItem> _filterReviewWorklistInventory(
    List<MergeReviewWorkItem> worklist,
    _ReviewWorklistInventoryFilter filter,
    String searchQuery,
    _ReviewWorklistInventoryPresenceFilter presenceFilter,
    Set<String>? loadedReviewPageIssueIds,
  ) {
    final statusMatches = switch (filter) {
      _ReviewWorklistInventoryFilter.all => worklist,
      _ReviewWorklistInventoryFilter.queued =>
        worklist
            .where((item) => item.status == MergeReviewWorkItemStatus.queued)
            .toList(growable: false),
      _ReviewWorklistInventoryFilter.deferred =>
        worklist
            .where((item) => item.status == MergeReviewWorkItemStatus.deferred)
            .toList(growable: false),
    };
    final normalizedQuery = _normalizeReviewWorklistInventorySearch(
      searchQuery,
    );
    final searchMatches = normalizedQuery.isEmpty
        ? statusMatches
        : statusMatches
              .where(
                (item) => _reviewWorklistInventoryItemMatchesSearch(
                  item,
                  normalizedQuery,
                ),
              )
              .toList(growable: false);
    if (loadedReviewPageIssueIds == null) {
      return searchMatches;
    }
    return switch (presenceFilter) {
      _ReviewWorklistInventoryPresenceFilter.all => searchMatches,
      _ReviewWorklistInventoryPresenceFilter.onLoadedReviewPage =>
        searchMatches
            .where((item) => loadedReviewPageIssueIds.contains(item.issueId))
            .toList(growable: false),
      _ReviewWorklistInventoryPresenceFilter.outsideLoadedReviewPage =>
        searchMatches
            .where((item) => !loadedReviewPageIssueIds.contains(item.issueId))
            .toList(growable: false),
    };
  }

  String _normalizeReviewWorklistInventorySearch(String value) {
    return value.trim().toLowerCase();
  }

  bool _reviewWorklistInventoryItemMatchesSearch(
    MergeReviewWorkItem item,
    String normalizedQuery,
  ) {
    final searchableFields = <String>[
      item.canonicalFoodId,
      item.targetSourceRecordId,
      item.subjectKey,
      ?item.suggestedCanonicalFoodId,
      item.reason,
      item.candidateSummary,
      item.issueId,
    ];
    return searchableFields.any(
      (field) => field.toLowerCase().contains(normalizedQuery),
    );
  }

  int _normalizedReviewWorklistInventoryOffsetForCount(
    int itemCount,
    int requestedOffset,
  ) {
    if (itemCount == 0) {
      return 0;
    }
    final nonNegativeOffset = requestedOffset < 0 ? 0 : requestedOffset;
    final alignedOffset =
        (nonNegativeOffset ~/ _reviewWorklistInventoryPageSize) *
        _reviewWorklistInventoryPageSize;
    final maximumOffset =
        ((itemCount - 1) ~/ _reviewWorklistInventoryPageSize) *
        _reviewWorklistInventoryPageSize;
    return alignedOffset > maximumOffset ? maximumOffset : alignedOffset;
  }

  void _setReviewWorklistInventoryFilter(
    _ReviewWorklistInventoryFilter filter,
  ) {
    if (_reviewWorklistLoading ||
        _reviewWorklistMutationInProgress ||
        !_hasLoadedReviewWorklist ||
        filter == _reviewWorklistInventoryFilter) {
      return;
    }
    setState(() {
      _reviewWorklistInventoryFilter = filter;
      _reviewWorklistInventoryOffset = 0;
    });
  }

  void _setReviewWorklistInventoryPresenceFilter(
    _ReviewWorklistInventoryPresenceFilter filter,
  ) {
    if (_reviewWorklistLoading ||
        _reviewWorklistMutationInProgress ||
        !_hasLoadedReviewWorklist ||
        !_reviewPagePresenceAvailable ||
        filter == _reviewWorklistInventoryPresenceFilter) {
      return;
    }
    setState(() {
      _reviewWorklistInventoryPresenceFilter = filter;
      _reviewWorklistInventoryOffset = 0;
    });
  }

  void _setReviewWorklistInventorySearchQuery(String query) {
    if (_reviewWorklistLoading ||
        _reviewWorklistMutationInProgress ||
        !_hasLoadedReviewWorklist ||
        query == _reviewWorklistInventorySearchQuery) {
      return;
    }
    setState(() {
      _reviewWorklistInventorySearchQuery = query;
      _reviewWorklistInventoryOffset = 0;
    });
  }

  void _clearReviewWorklistInventorySearch() {
    if (_reviewWorklistLoading ||
        _reviewWorklistMutationInProgress ||
        !_hasLoadedReviewWorklist ||
        _reviewWorklistInventorySearchQuery.isEmpty) {
      return;
    }
    _reviewWorklistInventorySearchController.clear();
    setState(() {
      _reviewWorklistInventorySearchQuery = '';
      _reviewWorklistInventoryOffset = 0;
    });
  }

  void _setReviewWorklistInventoryOffset(int requestedOffset) {
    if (_reviewWorklistLoading ||
        _reviewWorklistMutationInProgress ||
        !_hasLoadedReviewWorklist) {
      return;
    }
    final loadedReviewPageIssueIds = _loadedReviewPageIssueIdsForInventory;
    final presenceFilter = loadedReviewPageIssueIds == null
        ? _ReviewWorklistInventoryPresenceFilter.all
        : _reviewWorklistInventoryPresenceFilter;
    final matchingCount = _filterReviewWorklistInventory(
      _reviewWorklist,
      _reviewWorklistInventoryFilter,
      _reviewWorklistInventorySearchQuery,
      presenceFilter,
      loadedReviewPageIssueIds,
    ).length;
    final nextOffset = _normalizedReviewWorklistInventoryOffsetForCount(
      matchingCount,
      requestedOffset,
    );
    if (nextOffset == _reviewWorklistInventoryOffset) {
      return;
    }
    setState(() {
      _reviewWorklistInventoryOffset = nextOffset;
    });
  }

  Widget _buildReviewIssueCard(
    MergeReviewIssue issue, {
    required bool selectionEnabled,
    required MergeReviewWorkItem? workItem,
  }) {
    final canActOnSource = issue.sourceRecordId.isNotEmpty;
    final suggestedCanonicalId = issue.suggestedCanonicalFoodId;
    final selected = _selectedReviewIssueIds.contains(issue.id);
    final worklistSnapshotChanged =
        workItem != null && !_workItemMatchesIssueSnapshot(workItem, issue);
    final cardActionsEnabled =
        !_reviewWorklistMutationInProgress &&
        !_reviewGovernanceActionInProgress;
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_severityIcon(issue.severity)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${issue.type.name} / ${issue.severity.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Canonical: ${issue.canonicalFoodId}\n'
                        'Source record: ${issue.sourceRecordId.isEmpty ? '(canonical-level)' : issue.sourceRecordId}\n'
                        'Reason: ${issue.reason}\n'
                        'Candidates: ${issue.candidateSummary}',
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  key: ValueKey('operations_review_issue_select_${issue.id}'),
                  value: selected,
                  semanticLabel:
                      'Select ${issue.severity.name} ${issue.type.name} review issue for ${issue.canonicalFoodId}',
                  onChanged: selectionEnabled
                      ? (value) {
                          if (value == null) {
                            return;
                          }
                          _setReviewIssueSelected(issue.id, selected: value);
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (workItem != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    label: 'Review worklist status: ${workItem.status.name}',
                    child: Chip(
                      key: ValueKey(
                        'operations_review_issue_worklist_status_${issue.id}',
                      ),
                      avatar: Icon(
                        workItem.status == MergeReviewWorkItemStatus.queued
                            ? Icons.playlist_add_check_outlined
                            : Icons.schedule_outlined,
                      ),
                      label: Text(
                        workItem.status == MergeReviewWorkItemStatus.queued
                            ? 'Queued'
                            : 'Deferred',
                      ),
                    ),
                  ),
                  if (worklistSnapshotChanged)
                    Semantics(
                      label:
                          'The displayed review snapshot changed after this '
                          'worklist item was saved',
                      child: Chip(
                        key: ValueKey(
                          'operations_review_issue_worklist_stale_${issue.id}',
                        ),
                        avatar: const Icon(Icons.change_circle_outlined),
                        label: const Text('Review snapshot changed'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canActOnSource && suggestedCanonicalId != null)
                  FilledButton(
                    onPressed: cardActionsEnabled
                        ? () => _mergeIssueToCandidate(issue)
                        : null,
                    child: const Text('Merge candidate'),
                  ),
                if (canActOnSource)
                  OutlinedButton(
                    onPressed: cardActionsEnabled
                        ? () => _splitIssueSource(issue)
                        : null,
                    child: const Text('Split source'),
                  ),
                OutlinedButton(
                  onPressed: cardActionsEnabled
                      ? () => _overrideIssueCanonical(issue)
                      : null,
                  child: const Text('Override'),
                ),
                FilledButton(
                  onPressed: cardActionsEnabled
                      ? () => _showFoodDetails(issue.canonicalFoodId)
                      : null,
                  child: const Text('Open details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _workItemMatchesIssueSnapshot(
    MergeReviewWorkItem item,
    MergeReviewIssue issue,
  ) {
    return item.canonicalFoodId == issue.canonicalFoodId &&
        item.targetSourceRecordId == issue.sourceRecordId &&
        item.type == issue.type &&
        item.suggestedCanonicalFoodId ==
            issue.suggestedCanonicalFoodId?.trim() &&
        item.reason == issue.reason &&
        item.candidateSummary == issue.candidateSummary &&
        item.issueCreatedAt == issue.createdAt.toUtc();
  }

  Widget _buildGovernanceLogCard(ManualGovernanceLogEntry entry) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.rule_folder_outlined),
        title: Text('${entry.action} / ${entry.createdAt.toIso8601String()}'),
        subtitle: Text(
          'Source: ${entry.sourceRecordId.isEmpty ? '(canonical-level)' : entry.sourceRecordId}\n'
          'From: ${entry.fromCanonicalFoodId}\n'
          'To: ${entry.toCanonicalFoodId}\n'
          'Note: ${entry.note}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildExportHistoryCard(ExportHistoryEntry entry) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.file_present_outlined),
        title: Text('${entry.scopeLabel} / ${entry.format.name}'),
        subtitle: Text(
          'Records: ${entry.recordCount} / Status: ${entry.status}\n'
          'Path: ${entry.path}\n'
          'Summary: ${entry.summary}',
        ),
        isThreeLine: true,
        trailing: OutlinedButton.icon(
          onPressed: () => _shareExport(entry),
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('Share'),
        ),
      ),
    );
  }

  Widget _buildJobCard(FetchJobEntry job) {
    final capability = widget.sourceCapabilities.byImporterId(job.importerId);
    final retryAllowed =
        job.status == 'failure' &&
        capability != null &&
        capability.supportsAutomaticFetch &&
        !capability.isBlocked;
    final reason = capability == null
        ? 'Unknown importer.'
        : capability.isBlocked
        ? capability.blockedReason
        : !capability.supportsAutomaticFetch
        ? 'This source is manual-only and cannot be retried automatically.'
        : '';
    return Card(
      child: ListTile(
        leading: Icon(_statusIcon(job.status)),
        title: Text('${job.importerId} / ${job.phase} / ${job.status}'),
        subtitle: Text(
          'Query: ${job.query.isEmpty ? '(empty)' : job.query}\n'
          'Started: ${job.startedAt.toIso8601String()}\n'
          'Message: ${job.message}${reason.isEmpty ? '' : '\nRetry disabled: $reason'}',
        ),
        isThreeLine: true,
        trailing: retryAllowed
            ? FilledButton(
                onPressed: () => _retryJob(job),
                child: const Text('Retry'),
              )
            : null,
      ),
    );
  }

  Widget _buildArtifactCard(DatasetArtifactEntry artifact) {
    final capability = widget.sourceCapabilities.byImporterId(
      artifact.importerId,
    );
    final canPrepare =
        capability != null &&
        capability.supportsAutoGrab &&
        !capability.isManualOnly &&
        !capability.isBlocked;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text('${artifact.importerId} / ${artifact.status}'),
        subtitle: Text(
          'Path: ${artifact.localPath}\n'
          'Version: ${artifact.sourceVersion.isEmpty ? '(unknown)' : artifact.sourceVersion}\n'
          'Fetched: ${artifact.fetchedAt.toIso8601String()}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: artifact.status == 'removed'
                  ? null
                  : () => _markArtifactRemoved(artifact.id),
              child: const Text('Mark removed'),
            ),
            FilledButton(
              onPressed: canPrepare
                  ? () => _prepareSource(artifact.importerId)
                  : null,
              child: const Text('Re-prepare'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard(SourceCapability capability) {
    final lastSuccess = _latestLog(capability.importerId, 'success');
    final lastFailure = _latestLog(capability.importerId, 'failure');
    final status = capability.isBlocked
        ? 'blocked'
        : capability.supportsAutomaticFetch
        ? 'automatic'
        : capability.isManualOnly
        ? 'manual-only'
        : 'cataloged';
    return Card(
      child: ListTile(
        leading: Icon(
          capability.isBlocked
              ? Icons.block
              : capability.supportsAutomaticFetch
              ? Icons.bolt_outlined
              : Icons.pan_tool_alt_outlined,
        ),
        title: Text('${capability.displayName} ($status)'),
        subtitle: Text(
          'Country: ${capability.country}\n'
          'Auto-grab: ${capability.supportsAutoGrab} / Parse risk: ${capability.parseRisk.name}\n'
          'Latest: ${capability.latestReleaseLabel.isEmpty ? '(unknown)' : capability.latestReleaseLabel}\n'
          'Last success: ${lastSuccess?.createdAt.toIso8601String() ?? '(none)'}\n'
          'Last failure: ${lastFailure?.message ?? '(none)'}'
          '${capability.blockedReason.isEmpty ? '' : '\nBlocked: ${capability.blockedReason}'}',
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _retryJob(FetchJobEntry job) async {
    final descriptor = _descriptor(job.importerId);
    if (descriptor == null) {
      return;
    }
    final retryId =
        'retry-${job.importerId}-${DateTime.now().microsecondsSinceEpoch}';
    final startedAt = DateTime.now();
    try {
      await _persistFetchJobBestEffort(
        FetchJobEntry(
          id: retryId,
          query: job.query,
          phase: job.phase,
          status: 'running',
          importerId: job.importerId,
          startedAt: startedAt,
          finishedAt: null,
          message: 'Retry started from Operations.',
        ),
      );
      final summary = await widget.syncUseCase.syncSource(
        importerId: job.importerId,
        request: ImportRequest(
          query: job.query,
          limit: descriptor.defaultLimit,
        ),
      );
      await _persistFetchJobBestEffort(
        FetchJobEntry(
          id: retryId,
          query: job.query,
          phase: job.phase,
          status: 'success',
          importerId: job.importerId,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          message: summary.message,
        ),
      );
      _setStatus('Retry succeeded for ${job.importerId}.');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Retry succeeded: ${job.importerId}',
          details: {
            'type': 'retry-job',
            'importerId': job.importerId,
            'query': job.query,
            'records': summary.importedItems,
          },
        ),
      );
    } catch (error) {
      final failureMessage = error.toString();
      await _persistFetchJobBestEffort(
        FetchJobEntry(
          id: retryId,
          query: job.query,
          phase: job.phase,
          status: 'failure',
          importerId: job.importerId,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          message: failureMessage,
        ),
      );
      _setStatus('Retry failed for ${job.importerId}: $failureMessage');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Retry failed: ${job.importerId}',
          details: {
            'type': 'retry-job',
            'importerId': job.importerId,
            'query': job.query,
            'error': failureMessage,
          },
        ),
      );
    }
    await _refresh();
  }

  Future<void> _persistFetchJobBestEffort(FetchJobEntry entry) async {
    try {
      await widget.repository.upsertFetchJob(entry);
    } catch (_) {
      // Fetch-job history is supplemental diagnostics; it must not mask the
      // retry outcome or prevent the requested source operation.
    }
  }

  Future<void> _prepareSource(String importerId) async {
    final descriptor = _descriptor(importerId);
    if (descriptor == null) {
      return;
    }
    try {
      final summary = await widget.syncUseCase.syncSource(
        importerId: importerId,
        request: ImportRequest(query: '', limit: descriptor.defaultLimit),
      );
      _setStatus(summary.message);
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Re-prepare succeeded: $importerId',
          details: {
            'type': 'prepare-source',
            'importerId': importerId,
            'records': summary.importedItems,
          },
        ),
      );
    } catch (error) {
      _setStatus('Re-prepare failed for $importerId: $error');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Re-prepare failed: $importerId',
          details: {
            'type': 'prepare-source',
            'importerId': importerId,
            'error': error.toString(),
          },
        ),
      );
    }
    await _refresh();
  }

  Future<void> _markArtifactRemoved(String id) async {
    try {
      await widget.repository.markDatasetArtifactRemoved(id);
      _setStatus('Artifact marked removed. Local files were not deleted.');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Artifact marked removed',
          details: {'type': 'artifact-removed', 'artifactId': id},
        ),
      );
      await _refreshOperations();
    } catch (error) {
      _setStatus('Could not mark artifact removed: $error');
    }
  }

  Future<void> _mergeIssueToCandidate(MergeReviewIssue issue) async {
    if (_reviewWorklistMutationInProgress ||
        _reviewGovernanceActionInProgress) {
      return;
    }
    final target = issue.suggestedCanonicalFoodId;
    if (target == null) {
      return;
    }
    setState(() {
      _reviewGovernanceActionInProgress = true;
    });
    try {
      try {
        await widget.repository.mergeSourceRecord(
          sourceRecordId: issue.sourceRecordId,
          targetCanonicalFoodId: target,
          note:
              'Manual merge from Operations review issue ${issue.id}: ${issue.reason}',
        );
        _setStatus('Merged ${issue.sourceRecordId} into $target.');
        unawaited(
          _appendActivityTrace(
            action: 'governance',
            summary: 'Merge action: ${issue.sourceRecordId} -> $target',
            details: {
              'type': 'merge-review',
              'issueId': issue.id,
              'sourceRecordId': issue.sourceRecordId,
              'targetCanonicalFoodId': target,
            },
          ),
        );
        await _refresh();
      } catch (error) {
        _setStatus('Manual merge failed: $error');
        unawaited(
          _appendActivityTrace(
            action: 'governance',
            summary: 'Merge action failed',
            details: {
              'type': 'merge-review',
              'issueId': issue.id,
              'sourceRecordId': issue.sourceRecordId,
              'error': error.toString(),
            },
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _reviewGovernanceActionInProgress = false;
        });
      }
    }
  }

  Future<void> _splitIssueSource(MergeReviewIssue issue) async {
    if (_reviewWorklistMutationInProgress ||
        _reviewGovernanceActionInProgress) {
      return;
    }
    setState(() {
      _reviewGovernanceActionInProgress = true;
    });
    try {
      try {
        await widget.repository.splitSourceRecord(
          sourceRecordId: issue.sourceRecordId,
          note:
              'Manual split from Operations review issue ${issue.id}: ${issue.reason}',
        );
        _setStatus('Split ${issue.sourceRecordId} into a new canonical entry.');
        unawaited(
          _appendActivityTrace(
            action: 'governance',
            summary: 'Split action: ${issue.sourceRecordId}',
            details: {
              'type': 'split-review',
              'issueId': issue.id,
              'sourceRecordId': issue.sourceRecordId,
            },
          ),
        );
        await _refresh();
      } catch (error) {
        _setStatus('Manual split failed: $error');
        unawaited(
          _appendActivityTrace(
            action: 'governance',
            summary: 'Split action failed',
            details: {
              'type': 'split-review',
              'issueId': issue.id,
              'sourceRecordId': issue.sourceRecordId,
              'error': error.toString(),
            },
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _reviewGovernanceActionInProgress = false;
        });
      }
    }
  }

  Future<void> _overrideIssueCanonical(MergeReviewIssue issue) async {
    if (_reviewWorklistMutationInProgress ||
        _reviewGovernanceActionInProgress) {
      return;
    }
    setState(() {
      _reviewGovernanceActionInProgress = true;
    });
    try {
      await _performCanonicalOverride(issue);
    } catch (error) {
      _setStatus('Canonical override failed: $error');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Override action failed',
          details: {
            'type': 'override-review',
            'issueId': issue.id,
            'canonicalFoodId': issue.canonicalFoodId,
            'error': error.toString(),
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reviewGovernanceActionInProgress = false;
        });
      }
    }
  }

  Future<void> _performCanonicalOverride(MergeReviewIssue issue) async {
    final details = await widget.repository.getFoodDetails(
      issue.canonicalFoodId,
    );
    if (!mounted || details == null) {
      return;
    }
    final displayController = TextEditingController(text: details.displayName);
    final categoryController = TextEditingController(text: details.category);
    final countryController = TextEditingController(text: details.countryHint);
    final descriptionController = TextEditingController(
      text: details.description,
    );
    final servingController = TextEditingController(text: details.servingBasis);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Override canonical fields'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: displayController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'Country hint'),
              ),
              TextField(
                controller: servingController,
                decoration: const InputDecoration(labelText: 'Serving basis'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save override'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      return;
    }
    try {
      await widget.repository.overrideCanonicalFood(
        canonicalFoodId: issue.canonicalFoodId,
        fields: CanonicalOverrideFields(
          displayName: displayController.text,
          category: categoryController.text,
          countryHint: countryController.text,
          description: descriptionController.text,
          servingBasis: servingController.text,
        ),
        note:
            'Manual canonical override from Operations review issue ${issue.id}.',
      );
      _setStatus('Canonical override saved for ${issue.canonicalFoodId}.');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Override action: ${issue.canonicalFoodId}',
          details: {
            'type': 'override-review',
            'issueId': issue.id,
            'canonicalFoodId': issue.canonicalFoodId,
          },
        ),
      );
      await _refresh();
    } catch (error) {
      _setStatus('Canonical override failed: $error');
      unawaited(
        _appendActivityTrace(
          action: 'governance',
          summary: 'Override action failed',
          details: {
            'type': 'override-review',
            'issueId': issue.id,
            'canonicalFoodId': issue.canonicalFoodId,
            'error': error.toString(),
          },
        ),
      );
    }
  }

  Future<void> _shareExport(ExportHistoryEntry entry) async {
    try {
      await widget.exportShareService.shareFile(entry.path);
      _setStatus('Share sheet opened for ${entry.path}.');
      unawaited(
        _appendActivityTrace(
          action: 'export',
          summary: 'Shared export',
          details: {'type': 'share-export', 'path': entry.path},
        ),
      );
    } catch (error) {
      _setStatus('Share failed: $error');
      unawaited(
        _appendActivityTrace(
          action: 'export',
          summary: 'Share export failed',
          details: {
            'type': 'share-export',
            'path': entry.path,
            'error': error.toString(),
          },
        ),
      );
    }
  }

  void _setStatus(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _message = message;
    });
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
      // Activity trace persistence must not break the requested operation.
    }
  }

  ImportLogEntry? _latestLog(String importerId, String status) {
    for (final log in _logs) {
      if (log.importerId == importerId && log.status == status) {
        return log;
      }
    }
    return null;
  }

  ImporterDescriptor? _descriptor(String importerId) {
    for (final descriptor in widget.importerDescriptors) {
      if (descriptor.importerId == importerId) {
        return descriptor;
      }
    }
    return null;
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'success' => Icons.check_circle_outline,
      'failure' => Icons.error_outline,
      'running' => Icons.sync,
      'queued' => Icons.schedule,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.info_outline,
    };
  }

  IconData _severityIcon(MergeReviewSeverity severity) {
    return switch (severity) {
      MergeReviewSeverity.info => Icons.info_outline,
      MergeReviewSeverity.warning => Icons.warning_amber_outlined,
      MergeReviewSeverity.high => Icons.error_outline,
    };
  }

  Future<void> _showFoodDetails(String canonicalFoodId) async {
    if (_reviewWorklistMutationInProgress) {
      return;
    }
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
              final details = snapshot.data;
              if (snapshot.hasError || details == null) {
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
}

class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({required this.storageBudget, required this.modelBudget});

  final StorageBudgetSnapshot? storageBudget;
  final ModelBudgetSnapshot modelBudget;

  @override
  Widget build(BuildContext context) {
    final storage = storageBudget;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budgets',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (storage == null)
              const Text('Storage budget unavailable.')
            else ...[
              Text(
                'Database ${_formatBytes(storage.databaseBytes)} / ${_formatBytes(storage.limits.databaseBytes)}',
              ),
              Text(
                'Artifacts ${_formatBytes(storage.artifactBytes)} / ${_formatBytes(storage.limits.artifactBytes)}',
              ),
              Text(
                'Exports ${_formatBytes(storage.exportBytes)} / ${_formatBytes(storage.limits.exportBytes)}',
              ),
              Text(
                'Cache ${_formatBytes(storage.cacheBytes)} / ${_formatBytes(storage.limits.cacheBytes)}',
              ),
              if (storage.warnings.isNotEmpty)
                Text('Warnings: ${storage.warnings.join(', ')}'),
            ],
            const Divider(),
            Text(
              'Ollama calls ${modelBudget.callsInWindow}/${modelBudget.maxCallsPerMinute} per minute, timeout ${modelBudget.timeout.inSeconds}s, max tokens ${modelBudget.maxTokens}.',
            ),
            Text(
              'Cooldown until: ${modelBudget.cooldownUntil?.toIso8601String() ?? '(none)'}',
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${bytes}B';
  }
}

class _ReviewWorklistInventoryPanel extends StatelessWidget {
  const _ReviewWorklistInventoryPanel({
    super.key,
    required this.items,
    required this.totalCount,
    required this.matchingCount,
    required this.queuedCount,
    required this.deferredCount,
    required this.offset,
    required this.pageSize,
    required this.filter,
    required this.searchController,
    required this.searchQuery,
    required this.loadedReviewPagePresence,
    required this.presenceFilter,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onFilterChanged,
    required this.onPresenceFilterChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onPrevious,
    required this.onNext,
  });

  final List<MergeReviewWorkItem> items;
  final int totalCount;
  final int matchingCount;
  final int queuedCount;
  final int deferredCount;
  final int offset;
  final int pageSize;
  final _ReviewWorklistInventoryFilter filter;
  final TextEditingController searchController;
  final String searchQuery;
  final ({Set<String> issueIds, int onPageCount})? loadedReviewPagePresence;
  final _ReviewWorklistInventoryPresenceFilter presenceFilter;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<_ReviewWorklistInventoryFilter>? onFilterChanged;
  final ValueChanged<_ReviewWorklistInventoryPresenceFilter>?
  onPresenceFilterChanged;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pageCount = matchingCount == 0
        ? 1
        : ((matchingCount - 1) ~/ pageSize) + 1;
    final pageNumber = matchingCount == 0 ? 1 : (offset ~/ pageSize) + 1;
    final searchActive = searchQuery.trim().isNotEmpty;
    final reviewPagePresence = loadedReviewPagePresence;
    final loadedSnapshotLabel = totalCount == 1
        ? '1 loaded stored snapshot'
        : '$totalCount loaded stored snapshots';
    final reviewPagePresenceLabel = reviewPagePresence == null
        ? 'Loaded review page comparison unavailable until the latest '
              'selected filter/page request succeeds.'
        : 'Across all $loadedSnapshotLabel: '
              '${reviewPagePresence.onPageCount} on this loaded review page, '
              '${totalCount - reviewPagePresence.onPageCount} outside it.';
    final statusPrefix = switch (filter) {
      _ReviewWorklistInventoryFilter.all => '',
      _ReviewWorklistInventoryFilter.queued => 'queued ',
      _ReviewWorklistInventoryFilter.deferred => 'deferred ',
    };
    final presenceEmptyClause = switch (presenceFilter) {
      _ReviewWorklistInventoryPresenceFilter.all => '',
      _ReviewWorklistInventoryPresenceFilter.onLoadedReviewPage =>
        ' on the loaded review page',
      _ReviewWorklistInventoryPresenceFilter.outsideLoadedReviewPage =>
        ' outside the loaded review page',
    };
    final presenceCountClause = switch (presenceFilter) {
      _ReviewWorklistInventoryPresenceFilter.all => '',
      _ReviewWorklistInventoryPresenceFilter.onLoadedReviewPage =>
        ' on loaded review page',
      _ReviewWorklistInventoryPresenceFilter.outsideLoadedReviewPage =>
        ' outside loaded review page',
    };
    final emptyLabel = searchActive
        ? 'No ${statusPrefix}stored review snapshots$presenceEmptyClause '
              'match this search.'
        : 'No ${statusPrefix}stored review snapshots$presenceEmptyClause.';
    final countLabel = matchingCount == 0
        ? emptyLabel
        : presenceFilter != _ReviewWorklistInventoryPresenceFilter.all
        ? 'Showing ${offset + 1}-${offset + items.length} of $matchingCount '
              '${searchActive ? 'matching ' : ''}$statusPrefix'
              'snapshots$presenceCountClause ($totalCount total loaded) / '
              'Page $pageNumber of $pageCount'
        : searchActive
        ? filter == _ReviewWorklistInventoryFilter.all
              ? 'Showing ${offset + 1}-${offset + items.length} of '
                    '$matchingCount matching snapshots '
                    '($totalCount total loaded) / '
                    'Page $pageNumber of $pageCount'
              : 'Showing ${offset + 1}-${offset + items.length} of '
                    '$matchingCount matching ${filter.name} snapshots '
                    '($totalCount total loaded) / '
                    'Page $pageNumber of $pageCount'
        : filter == _ReviewWorklistInventoryFilter.all
        ? 'Showing ${offset + 1}-${offset + items.length} of $totalCount '
              'loaded snapshots / Page $pageNumber of $pageCount'
        : 'Showing ${offset + 1}-${offset + items.length} of $matchingCount '
              '${filter.name} snapshots ($totalCount total loaded) / '
              'Page $pageNumber of $pageCount';
    return Card(
      key: const Key('operations_review_worklist_inventory'),
      child: ExpansionTile(
        key: const Key('operations_review_worklist_inventory_toggle'),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Review worklist inventory'),
        subtitle: Text(
          totalCount == 1
              ? '1 loaded stored snapshot'
              : '$totalCount loaded stored snapshots',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Loaded stored snapshots only. This view does not determine '
              'whether an issue still exists or execute any governance '
              'action.',
              key: const Key('operations_review_worklist_inventory_boundary'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            liveRegion: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                reviewPagePresenceLabel,
                key: const Key(
                  'operations_review_worklist_inventory_presence_summary',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Exact issue-ID membership in this successfully loaded review '
              'page only. Outside can mean another review page or exclusion '
              'by the active review filter; it does not determine orphan, '
              'resolved, stale, current, or live existence.',
              key: const Key(
                'operations_review_worklist_inventory_presence_boundary',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Inventory status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key(
                    'operations_review_worklist_inventory_filter_all',
                  ),
                  label: Text('All ($totalCount)'),
                  selected: filter == _ReviewWorklistInventoryFilter.all,
                  onSelected: _filterCallback(
                    _ReviewWorklistInventoryFilter.all,
                  ),
                ),
                ChoiceChip(
                  key: const Key(
                    'operations_review_worklist_inventory_filter_queued',
                  ),
                  label: Text('Queued ($queuedCount)'),
                  selected: filter == _ReviewWorklistInventoryFilter.queued,
                  onSelected: _filterCallback(
                    _ReviewWorklistInventoryFilter.queued,
                  ),
                ),
                ChoiceChip(
                  key: const Key(
                    'operations_review_worklist_inventory_filter_deferred',
                  ),
                  label: Text('Deferred ($deferredCount)'),
                  selected: filter == _ReviewWorklistInventoryFilter.deferred,
                  onSelected: _filterCallback(
                    _ReviewWorklistInventoryFilter.deferred,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Loaded review page presence',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              key: const Key(
                'operations_review_worklist_inventory_presence_filter_controls',
              ),
              container: true,
              explicitChildNodes: true,
              label: 'Loaded review page presence filters',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key(
                      'operations_review_worklist_inventory_presence_filter_all',
                    ),
                    label: Text('All ($totalCount)'),
                    selected:
                        presenceFilter ==
                        _ReviewWorklistInventoryPresenceFilter.all,
                    onSelected: _presenceFilterCallback(
                      _ReviewWorklistInventoryPresenceFilter.all,
                    ),
                  ),
                  ChoiceChip(
                    key: const Key(
                      'operations_review_worklist_inventory_presence_filter_on_page',
                    ),
                    label: Text(
                      reviewPagePresence == null
                          ? 'On loaded page (unavailable)'
                          : 'On loaded page '
                                '(${reviewPagePresence.onPageCount})',
                    ),
                    selected:
                        presenceFilter ==
                        _ReviewWorklistInventoryPresenceFilter
                            .onLoadedReviewPage,
                    onSelected: _presenceFilterCallback(
                      _ReviewWorklistInventoryPresenceFilter.onLoadedReviewPage,
                    ),
                  ),
                  ChoiceChip(
                    key: const Key(
                      'operations_review_worklist_inventory_presence_filter_outside_page',
                    ),
                    label: Text(
                      reviewPagePresence == null
                          ? 'Outside loaded page (unavailable)'
                          : 'Outside loaded page '
                                '(${totalCount - reviewPagePresence.onPageCount})',
                    ),
                    selected:
                        presenceFilter ==
                        _ReviewWorklistInventoryPresenceFilter
                            .outsideLoadedReviewPage,
                    onSelected: _presenceFilterCallback(
                      _ReviewWorklistInventoryPresenceFilter
                          .outsideLoadedReviewPage,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Presence chip counts cover all loaded stored snapshots. '
              'Result counts combine status, search, and presence. When '
              'review-page comparison is unavailable, the local presence '
              'filter resets to All.',
              key: const Key(
                'operations_review_worklist_inventory_presence_filter_boundary',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('operations_review_worklist_inventory_search'),
            controller: searchController,
            enabled: onSearchChanged != null,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search stored snapshot fields',
              helper: const Text(
                'Case-insensitive literal match in canonical ID, target '
                'source ID, subject key, suggested canonical ID, reason, '
                'candidate summary, or issue identity.',
                key: Key('operations_review_worklist_inventory_search_scope'),
              ),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      key: const Key(
                        'operations_review_worklist_inventory_search_clear',
                      ),
                      tooltip: 'Clear inventory search',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            container: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                countLabel,
                key: const Key('operations_review_worklist_inventory_count'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key(
                    'operations_review_worklist_inventory_previous',
                  ),
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous snapshots'),
                ),
                OutlinedButton.icon(
                  key: const Key('operations_review_worklist_inventory_next'),
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next snapshots'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(emptyLabel),
              contentPadding: EdgeInsets.zero,
            )
          else
            ...items.map(
              (item) => _ReviewWorklistInventoryItemCard(
                item,
                onLoadedReviewPage: loadedReviewPagePresence?.issueIds.contains(
                  item.issueId,
                ),
              ),
            ),
        ],
      ),
    );
  }

  ValueChanged<bool>? _filterCallback(_ReviewWorklistInventoryFilter target) {
    final callback = onFilterChanged;
    if (callback == null) {
      return null;
    }
    return (selected) {
      if (selected) {
        callback(target);
      }
    };
  }

  ValueChanged<bool>? _presenceFilterCallback(
    _ReviewWorklistInventoryPresenceFilter target,
  ) {
    final callback = onPresenceFilterChanged;
    if (callback == null) {
      return null;
    }
    return (selected) {
      if (selected) {
        callback(target);
      }
    };
  }
}

class _ReviewWorklistInventoryItemCard extends StatelessWidget {
  const _ReviewWorklistInventoryItemCard(
    this.item, {
    required this.onLoadedReviewPage,
  });

  final MergeReviewWorkItem item;
  final bool? onLoadedReviewPage;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (item.status) {
      MergeReviewWorkItemStatus.queued => 'Queued',
      MergeReviewWorkItemStatus.deferred => 'Deferred',
    };
    final targetSource = item.targetSourceRecordId.isEmpty
        ? '(canonical-level)'
        : item.targetSourceRecordId;
    final reviewPagePresenceLabel = switch (onLoadedReviewPage) {
      true => 'On loaded review page',
      false => 'Outside loaded review page',
      null => 'Loaded review page comparison unavailable',
    };
    final reviewPagePresenceIcon = switch (onLoadedReviewPage) {
      true => Icons.visibility_outlined,
      false => Icons.layers_outlined,
      null => Icons.help_outline,
    };
    return Card(
      key: ValueKey(
        'operations_review_worklist_inventory_item_${item.issueId}',
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  key: ValueKey(
                    'operations_review_worklist_inventory_status_${item.issueId}',
                  ),
                  avatar: Icon(
                    item.status == MergeReviewWorkItemStatus.queued
                        ? Icons.playlist_add_check_outlined
                        : Icons.schedule_outlined,
                  ),
                  label: Text(statusLabel),
                ),
                Chip(
                  key: ValueKey(
                    'operations_review_worklist_inventory_presence_${item.issueId}',
                  ),
                  avatar: Icon(reviewPagePresenceIcon),
                  label: Text(reviewPagePresenceLabel),
                ),
                Text(
                  item.type.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Canonical: ${item.canonicalFoodId}\n'
              'Target source: $targetSource\n'
              'Subject key: ${item.subjectKey}\n'
              'Suggested canonical: '
              '${item.suggestedCanonicalFoodId ?? '(none)'}\n'
              'Reason: ${item.reason}\n'
              'Candidates: ${item.candidateSummary}\n'
              'Issue snapshot: ${item.issueCreatedAt.toIso8601String()}\n'
              'Saved: ${item.createdAt.toIso8601String()}\n'
              'Updated: ${item.updatedAt.toIso8601String()}',
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Issue identity: ${item.issueId}',
              key: ValueKey(
                'operations_review_worklist_inventory_identity_${item.issueId}',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewFilterCard extends StatelessWidget {
  const _ReviewFilterCard({
    required this.filter,
    required this.savedViews,
    required this.selectedSavedViewId,
    required this.savedViewMutationInProgress,
    required this.visibleCount,
    required this.matchingCount,
    required this.totalCount,
    required this.offset,
    required this.loading,
    required this.resultsCurrent,
    required this.selectedCount,
    required this.queuedWorkItemCount,
    required this.deferredWorkItemCount,
    required this.worklistMutationInProgress,
    required this.worklistLoading,
    required this.worklistAvailable,
    required this.worklistMutationMessage,
    required this.worklistMutationFailed,
    required this.allVisibleSelected,
    required this.onSeverityChanged,
    required this.onTypeChanged,
    required this.onClear,
    required this.onSaveView,
    required this.onApplyView,
    required this.onDeleteView,
    required this.onSelectVisible,
    required this.onClearSelection,
    required this.onQueueSelected,
    required this.onDeferSelected,
    required this.onUntrackSelected,
    required this.onClearWorklist,
    required this.onPrevious,
    required this.onNext,
  });

  static const String _allSeverities = 'all-severities';
  static const String _allTypes = 'all-types';

  final MergeReviewFilter filter;
  final List<MergeReviewSavedView> savedViews;
  final String? selectedSavedViewId;
  final bool savedViewMutationInProgress;
  final int visibleCount;
  final int matchingCount;
  final int totalCount;
  final int offset;
  final bool loading;
  final bool resultsCurrent;
  final int selectedCount;
  final int queuedWorkItemCount;
  final int deferredWorkItemCount;
  final bool worklistMutationInProgress;
  final bool worklistLoading;
  final bool worklistAvailable;
  final String? worklistMutationMessage;
  final bool worklistMutationFailed;
  final bool allVisibleSelected;
  final ValueChanged<MergeReviewSeverity?> onSeverityChanged;
  final ValueChanged<MergeReviewIssueType?> onTypeChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSaveView;
  final ValueChanged<MergeReviewSavedView> onApplyView;
  final ValueChanged<MergeReviewSavedView> onDeleteView;
  final VoidCallback? onSelectVisible;
  final VoidCallback? onClearSelection;
  final VoidCallback? onQueueSelected;
  final VoidCallback? onDeferSelected;
  final VoidCallback? onUntrackSelected;
  final VoidCallback? onClearWorklist;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final worklistControlsLocked = worklistMutationInProgress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 600
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      key: const Key('operations_review_severity_filter'),
                      width: fieldWidth,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'review-severity-${filter.severity?.name ?? _allSeverities}',
                        ),
                        initialValue: filter.severity?.name ?? _allSeverities,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: _allSeverities,
                            child: Text('All severities'),
                          ),
                          ...const [
                            MergeReviewSeverity.high,
                            MergeReviewSeverity.warning,
                            MergeReviewSeverity.info,
                          ].map(
                            (severity) => DropdownMenuItem(
                              value: severity.name,
                              child: Text(_severityLabel(severity)),
                            ),
                          ),
                        ],
                        onChanged: worklistControlsLocked
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                onSeverityChanged(
                                  value == _allSeverities
                                      ? null
                                      : MergeReviewSeverity.values.firstWhere(
                                          (severity) => severity.name == value,
                                        ),
                                );
                              },
                      ),
                    ),
                    SizedBox(
                      key: const Key('operations_review_type_filter'),
                      width: fieldWidth,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'review-type-${filter.type?.name ?? _allTypes}',
                        ),
                        initialValue: filter.type?.name ?? _allTypes,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Issue type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: _allTypes,
                            child: Text('All issue types'),
                          ),
                          ...MergeReviewIssueType.values.map(
                            (type) => DropdownMenuItem(
                              value: type.name,
                              child: Text(_typeLabel(type)),
                            ),
                          ),
                        ],
                        onChanged: worklistControlsLocked
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                onTypeChanged(
                                  value == _allTypes
                                      ? null
                                      : MergeReviewIssueType.values.firstWhere(
                                          (type) => type.name == value,
                                        ),
                                );
                              },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved review views',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('operations_review_saved_view_save'),
                  onPressed:
                      savedViewMutationInProgress || worklistControlsLocked
                      ? null
                      : onSaveView,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save current'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (savedViews.isEmpty)
              Text(
                'No named review views saved.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: savedViews
                    .map(
                      (view) => InputChip(
                        key: ValueKey(
                          'operations_review_saved_view_${view.id}',
                        ),
                        label: Text(view.name),
                        selected: selectedSavedViewId == view.id,
                        onSelected: worklistControlsLocked
                            ? null
                            : (_) => onApplyView(view),
                        onDeleted:
                            savedViewMutationInProgress ||
                                worklistControlsLocked
                            ? null
                            : () => onDeleteView(view),
                        deleteButtonTooltipMessage:
                            'Delete saved review view ${view.name}',
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            Text(
              _countLabel(),
              key: const Key('operations_review_filter_count'),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              container: true,
              child: Text(
                worklistMutationInProgress
                    ? 'Updating review worklist...'
                    : worklistLoading
                    ? 'Loading review worklist...'
                    : !worklistAvailable
                    ? 'Review worklist unavailable'
                    : 'Worklist: $queuedWorkItemCount queued, '
                          '$deferredWorkItemCount deferred',
                key: const Key('operations_review_worklist_count'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('operations_review_queue_selected'),
                  onPressed: onQueueSelected,
                  icon: const Icon(Icons.playlist_add_outlined),
                  label: const Text('Queue selected'),
                ),
                OutlinedButton.icon(
                  key: const Key('operations_review_defer_selected'),
                  onPressed: onDeferSelected,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Defer selected'),
                ),
                TextButton.icon(
                  key: const Key('operations_review_untrack_selected'),
                  onPressed: onUntrackSelected,
                  icon: const Icon(Icons.playlist_remove_outlined),
                  label: const Text('Untrack selected'),
                ),
                TextButton.icon(
                  key: const Key('operations_review_worklist_clear'),
                  onPressed: onClearWorklist,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear worklist'),
                ),
              ],
            ),
            if (worklistMutationMessage != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                container: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      worklistMutationFailed
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: worklistMutationFailed
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        worklistMutationMessage!,
                        key: const Key(
                          'operations_review_worklist_mutation_message',
                        ),
                        style: worklistMutationFailed
                            ? TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Text(
                    'Selected $selectedCount of $visibleCount visible review issues',
                    key: const Key('operations_review_selection_count'),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('operations_review_select_visible'),
                  onPressed: allVisibleSelected ? null : onSelectVisible,
                  icon: const Icon(Icons.select_all_outlined),
                  label: const Text('Select visible'),
                ),
                TextButton.icon(
                  key: const Key('operations_review_clear_selection'),
                  onPressed: onClearSelection,
                  icon: const Icon(Icons.deselect_outlined),
                  label: const Text('Clear selection'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('operations_review_page_previous'),
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                OutlinedButton.icon(
                  key: const Key('operations_review_page_next'),
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
                TextButton.icon(
                  key: const Key('operations_review_filter_clear'),
                  onPressed: worklistControlsLocked ? null : onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear review filters'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Filters are applied before paging across all derived review issues.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _countLabel() {
    if (loading) {
      return 'Loading review issues...';
    }
    if (!resultsCurrent) {
      return 'Review results unavailable for the selected filters';
    }
    if (visibleCount == 0) {
      return 'Showing 0 of $matchingCount matching review issues ($totalCount total)';
    }
    final first = offset + 1;
    final last = offset + visibleCount;
    final range = first == last ? '$first' : '$first-$last';
    return 'Showing $range of $matchingCount matching review issues ($totalCount total)';
  }

  static String _severityLabel(MergeReviewSeverity severity) {
    return switch (severity) {
      MergeReviewSeverity.high => 'High',
      MergeReviewSeverity.warning => 'Warning',
      MergeReviewSeverity.info => 'Info',
    };
  }

  static String _typeLabel(MergeReviewIssueType type) {
    return switch (type) {
      MergeReviewIssueType.lowConfidenceReuse => 'Low-confidence reuse',
      MergeReviewIssueType.categoryConflictCandidate =>
        'Category conflict candidate',
      MergeReviewIssueType.createdWithCandidates => 'Created with candidates',
      MergeReviewIssueType.multiSourceNutrientVariance =>
        'Multi-source nutrient variance',
    };
  }
}

class _RetryErrorCard extends StatelessWidget {
  const _RetryErrorCard({
    required this.cardKey,
    required this.retryKey,
    required this.message,
    required this.onRetry,
  });

  final Key cardKey;
  final Key retryKey;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        key: cardKey,
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                key: retryKey,
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title ($count)',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inbox_outlined),
        title: Text(message),
      ),
    );
  }
}
