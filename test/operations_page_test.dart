import 'dart:async';
import 'dart:io';

import 'package:data_hook_claws/src/data/importer_registry.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:data_hook_claws/src/domain/export_share_service.dart';
import 'package:data_hook_claws/src/domain/merge_review_saved_view_store.dart';
import 'package:data_hook_claws/src/domain/merge_review_worklist_store.dart';
import 'package:data_hook_claws/src/domain/model_budget_controller.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/settings_service.dart';
import 'package:data_hook_claws/src/domain/source_capability_registry.dart';
import 'package:data_hook_claws/src/domain/storage_budget_manager.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/features/operations/operations_page.dart';
import 'package:data_hook_claws/src/importers/food_importer.dart';
import 'package:data_hook_claws/src/models/dataset_artifact_entry.dart';
import 'package:data_hook_claws/src/models/export_history_entry.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:data_hook_claws/src/models/import_log_entry.dart';
import 'package:data_hook_claws/src/models/manual_governance.dart';
import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_identity.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_query.dart';
import 'package:data_hook_claws/src/models/merge_review_saved_view.dart';
import 'package:data_hook_claws/src/models/merge_review_work_item.dart';
import 'package:data_hook_claws/src/models/raw_food_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders operations sections and blocked New Zealand source', (
    tester,
  ) async {
    final repository = MemoryFoodRepository();
    await repository.upsertFetchJob(
      FetchJobEntry(
        id: 'job-1',
        query: 'salmon',
        phase: 'foreground',
        status: 'failure',
        importerId: 'usda',
        startedAt: DateTime(2026),
        finishedAt: DateTime(2026),
        message: 'network failed',
      ),
    );
    await repository.upsertDatasetArtifact(
      DatasetArtifactEntry(
        id: 'artifact-1',
        importerId: 'canada-cnf',
        artifactType: 'dataset-path',
        localPath: Directory.systemTemp.path,
        sourceUrl: '',
        sourceVersion: 'test',
        fetchedAt: DateTime(2026),
        status: 'ready',
      ),
    );

    await _pumpOperationsPage(tester, repository);

    expect(find.text('Operations'), findsOneWidget);
    expect(find.textContaining('Budgets'), findsOneWidget);
    expect(find.textContaining('Export history'), findsOneWidget);
    await _dragUntilText(tester, 'Fetch jobs');
    expect(find.textContaining('Fetch jobs'), findsOneWidget);
    await _dragUntilText(tester, 'Dataset artifacts');
    expect(find.textContaining('Dataset artifacts'), findsOneWidget);
    await _dragUntilText(tester, 'Importer diagnostics');
    expect(find.textContaining('Importer diagnostics'), findsOneWidget);

    await _dragUntilText(tester, 'New Zealand FOODfiles');
    expect(find.textContaining('blocked'), findsWidgets);
    expect(find.textContaining('Terms of Use'), findsOneWidget);
  });

  testWidgets('retry continues when fetch-job status persistence fails', (
    tester,
  ) async {
    final repository = _FailingFetchJobRepository(_reviewIssues());
    await repository.upsertFetchJob(
      _fetchJob(
        id: 'retry-persistence-source',
        message: 'RETRY_SOURCE',
        status: 'failure',
      ),
    );
    repository.failFetchJobWrites = true;

    await _pumpOperationsPage(tester, repository);
    await _dragUntilText(tester, 'RETRY_SOURCE');
    final retryButton = find.widgetWithText(FilledButton, 'Retry');
    expect(retryButton, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(retryButton));

    await tester.tap(retryButton);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.fetchJobWriteAttempts, 3);
    expect(repository.attemptedFetchJobStatuses, [
      'failure',
      'running',
      'success',
    ]);
    expect(
      (await repository.getImportLogs()).map((log) => log.status),
      contains('success'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filters review issues by severity AND type and reports visible count',
    (tester) async {
      final repository = _ReviewIssueRepository(_reviewIssues());
      await _pumpOperationsPage(tester, repository);

      await _expectReviewCount(
        tester,
        'Showing 1-3 of 3 matching review issues (3 total)',
      );
      await _selectReviewFilter(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      await _expectReviewCount(
        tester,
        'Showing 1-2 of 2 matching review issues (3 total)',
      );
      await _selectReviewFilter(
        tester,
        key: const Key('operations_review_type_filter'),
        option: 'Category conflict candidate',
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (3 total)',
      );
      await _expectReviewTextVisible(tester, 'WARNING_CATEGORY');
    },
  );

  testWidgets('persists review filters and clear across reconstruction', (
    tester,
  ) async {
    final repository = _ReviewIssueRepository(_reviewIssues());
    await _pumpOperationsPage(tester, repository);
    await _selectReviewFilter(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    await _selectReviewFilter(
      tester,
      key: const Key('operations_review_type_filter'),
      option: 'Category conflict candidate',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpOperationsPage(tester, repository);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (3 total)',
    );
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Category conflict candidate'), findsOneWidget);

    await _tapReviewControl(
      tester,
      const Key('operations_review_filter_clear'),
    );
    await _expectReviewCount(
      tester,
      'Showing 1-3 of 3 matching review issues (3 total)',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpOperationsPage(tester, repository);
    await _expectReviewCount(
      tester,
      'Showing 1-3 of 3 matching review issues (3 total)',
    );
    expect(find.text('All severities'), findsOneWidget);
    expect(find.text('All issue types'), findsOneWidget);
  });

  testWidgets(
    'saved review view survives reconstruction, applies, and stays deleted',
    (tester) async {
      final repository = _ReviewIssueRepository(_reviewIssues());
      await _pumpOperationsPage(tester, repository);
      await _selectReviewFilter(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      await _selectReviewFilter(
        tester,
        key: const Key('operations_review_type_filter'),
        option: 'Category conflict candidate',
      );

      await _saveReviewView(tester, 'Needs triage');
      final storedViews = MergeReviewSavedViewCodec.decode(
        await repository.getAppMeta(MergeReviewSavedViewStore.metaKey),
      );
      expect(storedViews, hasLength(1));
      expect(storedViews.single.name, 'Needs triage');
      expect(
        storedViews.single.filter,
        const MergeReviewFilter(
          severity: MergeReviewSeverity.warning,
          type: MergeReviewIssueType.categoryConflictCandidate,
        ),
      );
      final savedViewKey = Key(
        'operations_review_saved_view_${storedViews.single.id}',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpOperationsPage(tester, repository);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);

      await _tapReviewControl(
        tester,
        const Key('operations_review_filter_clear'),
      );
      await _expectReviewCount(
        tester,
        'Showing 1-3 of 3 matching review issues (3 total)',
      );
      await _tapReviewControl(tester, savedViewKey);
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (3 total)',
      );
      expect(repository.queries.last.offset, 0);
      expect(repository.queries.last.filter, storedViews.single.filter);

      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      await _deleteReviewView(tester, 'Needs triage');
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpOperationsPage(tester, repository);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(
        MergeReviewSavedViewCodec.decode(
          await repository.getAppMeta(MergeReviewSavedViewStore.metaKey),
        ),
        isEmpty,
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (3 total)',
      );
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Category conflict candidate'), findsOneWidget);
    },
  );

  testWidgets(
    'applying a saved review view resets paging and only reloads reviews',
    (tester) async {
      final repository = _ReviewIssueRepository(_backlogReviewIssues());
      final savedView = _savedReviewView(
        id: 'warning-reuse',
        name: 'Warning reuse',
        filter: const MergeReviewFilter(
          severity: MergeReviewSeverity.warning,
          type: MergeReviewIssueType.lowConfidenceReuse,
        ),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      await _pumpOperationsPage(tester, repository);
      await _tapReviewPager(tester, const Key('operations_review_page_next'));
      await _expectReviewCount(
        tester,
        'Showing 101-102 of 102 matching review issues (102 total)',
      );
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;

      await _tapReviewControl(
        tester,
        const Key('operations_review_saved_view_warning-reuse'),
      );

      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries.last.offset, 0);
      expect(repository.queries.last.limit, 100);
      expect(repository.queries.last.filter, savedView.filter);
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        savedView.filter,
      );
    },
  );

  testWidgets(
    'corrupt saved views do not replace a valid active review filter',
    (tester) async {
      final repository = _ReviewIssueRepository(_backlogReviewIssues());
      const activeFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
        type: MergeReviewIssueType.lowConfidenceReuse,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        activeFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        '{"schemaVersion":1,"views":['
        '{"id":"corrupt","name":"CORRUPT_VIEW"',
      );

      await _pumpOperationsPage(tester, repository);

      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(repository.queries.last.filter, activeFilter);
      expect(repository.queries.last.offset, 0);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Low-confidence reuse'), findsOneWidget);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
      );
      expect(
        find.byKey(const Key('operations_review_saved_view_corrupt')),
        findsNothing,
      );
      expect(find.text('CORRUPT_VIEW'), findsNothing);
      expect(find.byKey(const Key('operations_refresh_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
    },
  );

  testWidgets('applying the active saved view still returns page 100 to zero', (
    tester,
  ) async {
    final repository = _ReviewIssueRepository(_backlogReviewIssues());
    const activeFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.high,
      type: MergeReviewIssueType.categoryConflictCandidate,
    );
    final savedView = _savedReviewView(
      id: 'active-high-category',
      name: 'Active high category',
      filter: activeFilter,
    );
    await repository.setAppMeta(
      'merge_review_filter_v1',
      activeFilter.encode(),
    );
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([savedView]),
    );
    await _pumpOperationsPage(tester, repository);
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    await _tapReviewPager(tester, const Key('operations_review_page_next'));
    await _expectReviewCount(
      tester,
      'Showing 101 of 101 matching review issues (102 total)',
    );
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;

    await _tapReviewControl(
      tester,
      const Key('operations_review_saved_view_active-high-category'),
    );

    expect(repository.queries, hasLength(baselineReviewQueries + 1));
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.queries.last.filter, activeFilter);
    expect(repository.queries.last.offset, 0);
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
  });

  testWidgets(
    'current-page review selection controls have no repository side effects',
    (tester) async {
      final repository = _ReviewIssueRepository(_reviewIssues());
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_high-category'),
      );
      await _expectReviewSelectionCount(tester, selected: 1, visible: 3);
      await _expectReviewIssueSelected(tester, 'high-category', isTrue);

      await _tapReviewControl(
        tester,
        const Key('operations_review_select_visible'),
      );
      await _expectReviewSelectionCount(tester, selected: 3, visible: 3);

      await _tapReviewControl(
        tester,
        const Key('operations_review_clear_selection'),
      );
      await _expectReviewSelectionCount(tester, selected: 0, visible: 3);
      await _expectReviewIssueSelected(tester, 'high-category', isFalse);

      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    },
  );

  testWidgets(
    'paging, filtering, and applying a saved view clear review selection',
    (tester) async {
      final repository = _ReviewIssueRepository(_backlogReviewIssues());
      final savedView = _savedReviewView(
        id: 'high-category-selection',
        name: 'High category selection',
        filter: const MergeReviewFilter(
          severity: MergeReviewSeverity.high,
          type: MergeReviewIssueType.categoryConflictCandidate,
        ),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_recent-high-100'),
      );
      await _expectReviewSelectionCount(tester, selected: 1, visible: 100);
      await _tapReviewPager(tester, const Key('operations_review_page_next'));
      await _expectReviewSelectionCount(tester, selected: 0, visible: 2);
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.queries.last.offset, 100);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_recent-high-0'),
      );
      await _expectReviewSelectionCount(tester, selected: 1, visible: 2);
      await _selectReviewFilter(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      await _expectReviewSelectionCount(tester, selected: 0, visible: 1);
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(repository.queries.last.offset, 0);
      expect(
        repository.queries.last.filter,
        const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );

      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_backlog-target'),
      );
      await _expectReviewSelectionCount(tester, selected: 1, visible: 1);
      await _tapReviewControl(
        tester,
        const Key('operations_review_saved_view_high-category-selection'),
      );
      await _expectReviewSelectionCount(tester, selected: 0, visible: 100);
      expect(repository.queries, hasLength(baselineReviewQueries + 3));
      expect(repository.queries.last.offset, 0);
      expect(repository.queries.last.filter, savedView.filter);
      expect(repository.operationsReadCounts, baselineReads);
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );

      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_recent-high-100'),
      );
      await _expectReviewSelectionCount(tester, selected: 1, visible: 100);
      final beforeReapplyQueries = repository.queries.length;
      final beforeReapplyMetaWrites = repository.appMetaWrites.length;
      await _tapReviewControl(
        tester,
        const Key('operations_review_saved_view_high-category-selection'),
      );
      await _expectReviewSelectionCount(tester, selected: 0, visible: 100);
      expect(repository.queries, hasLength(beforeReapplyQueries));
      expect(repository.appMetaWrites, hasLength(beforeReapplyMetaWrites));
      expect(repository.operationsReadCounts, baselineReads);
    },
  );

  testWidgets(
    'same-query full refresh retains only still-visible selected issue ids',
    (tester) async {
      final repository = _ReviewIssueRepository(_reviewIssues());
      await _pumpOperationsPage(tester, repository);
      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_high-category'),
      );
      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_warning-category'),
      );
      await _expectReviewSelectionCount(tester, selected: 2, visible: 3);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      repository.reviewIssues.removeWhere(
        (issue) => issue.id == 'warning-category',
      );
      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pumpAndSettle();

      await _expectReviewSelectionCount(tester, selected: 1, visible: 2);
      await _expectReviewIssueSelected(tester, 'high-category', isTrue);
      expect(
        find.byKey(
          const Key('operations_review_issue_select_warning-category'),
        ),
        findsNothing,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.queries.last.filter, MergeReviewFilter.all);
      expect(repository.queries.last.offset, 0);
      expect(repository.recentFetchJobsReadCount, baselineReads.jobs + 1);
      expect(repository.datasetArtifactsReadCount, baselineReads.artifacts + 2);
      expect(repository.importLogsReadCount, baselineReads.logs + 1);
      expect(repository.exportHistoryReadCount, baselineReads.exports + 1);
      expect(repository.governanceLogsReadCount, baselineReads.governance + 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    },
  );

  testWidgets(
    'review selection actions are gated correctly during a pending refresh',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(_reviewIssues());
      await _pumpOperationsPage(tester, repository);
      await _tapReviewControl(
        tester,
        const Key('operations_review_issue_select_high-category'),
      );
      await _expectReviewSelectionCount(tester, selected: 1, visible: 3);
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      repository.holdReviewQueries = true;

      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_issue_select_high-category'),
        settle: false,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(
                const Key('operations_review_issue_select_high-category'),
              ),
            )
            .onChanged,
        isNull,
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_select_visible'),
        settle: false,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('operations_review_select_visible')),
            )
            .onPressed,
        isNull,
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_clear_selection'),
        settle: false,
      );
      final clearButton = tester.widget<TextButton>(
        find.byKey(const Key('operations_review_clear_selection')),
      );
      expect(clearButton.onPressed, isNotNull);
      clearButton.onPressed!();
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('operations_review_selection_count')),
            )
            .data,
        'Selected 0 of 3 visible review issues',
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _expectReviewSelectionCount(tester, selected: 0, visible: 3);
      await _expectReviewIssueSelected(tester, 'high-category', isFalse);
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    },
  );

  testWidgets(
    'queue selected persists a batch, reconstructs chips, and avoids governance',
    (tester) async {
      final issues = [
        _structuredReviewIssue(logicalKey: 'batch-a'),
        _structuredReviewIssue(logicalKey: 'batch-b'),
      ];
      final repository = _ReviewIssueRepository(issues);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _tapReviewControl(
        tester,
        const Key('operations_review_select_visible'),
      );
      await _expectReviewSelectionCount(tester, selected: 2, visible: 2);
      await _tapReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );

      await _expectReviewSelectionCount(tester, selected: 0, visible: 2);
      for (final issue in issues) {
        await _expectReviewWorklistStatus(tester, issue, 'Queued');
      }
      final stored = await MergeReviewWorklistStore(repository).load();
      expect(
        stored.map((item) => item.issueId),
        unorderedEquals([issues[0].id, issues[1].id]),
      );
      expect(
        stored.map((item) => item.status),
        everyElement(MergeReviewWorkItemStatus.queued),
      );
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpOperationsPage(tester, repository);

      for (final issue in issues) {
        await _expectReviewWorklistStatus(tester, issue, 'Queued');
      }
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'worklist inventory exposes exact stored snapshots absent from review page',
    (tester) async {
      final visibleIssue = _structuredReviewIssue(
        logicalKey: 'inventory-visible',
      );
      final storedOnlyIssue = _structuredReviewIssue(
        logicalKey: 'inventory-stored-only',
      );
      final repository = _ReviewIssueRepository([visibleIssue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: storedOnlyIssue,
          status: MergeReviewWorkItemStatus.deferred,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      expect(
        find.byKey(
          Key(
            'operations_review_worklist_inventory_item_${storedOnlyIssue.id}',
          ),
        ),
        findsNothing,
      );

      await _openReviewWorklistInventory(tester);

      expect(
        find.byKey(const Key('operations_review_worklist_inventory')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('operations_review_worklist_inventory_boundary'),
              ),
            )
            .data,
        'Loaded stored snapshots only. This view does not determine whether '
        'an issue still exists or execute any governance action.',
      );
      final itemKey = Key(
        'operations_review_worklist_inventory_item_${storedOnlyIssue.id}',
      );
      await _scrollToReviewControl(tester, itemKey);
      expect(find.byKey(itemKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            Key(
              'operations_review_worklist_inventory_status_${storedOnlyIssue.id}',
            ),
          ),
          matching: find.text('Deferred'),
        ),
        findsOneWidget,
      );

      expect(
        tester
            .widget<SelectableText>(
              find.byKey(
                Key(
                  'operations_review_worklist_inventory_identity_${storedOnlyIssue.id}',
                ),
              ),
            )
            .data,
        'Issue identity: ${storedOnlyIssue.id}',
      );
      expect(find.textContaining(storedOnlyIssue.reason), findsOneWidget);
      expect(
        find.textContaining(storedOnlyIssue.candidateSummary),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistStatusKey(visibleIssue.id)),
        findsNothing,
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'inventory presence uses exact loaded review issue IDs across local views',
    (tester) async {
      final onPageIssue = _structuredReviewIssue(
        logicalKey: 'presence-on-page',
        canonicalFoodId: 'food-presence-shared',
        sourceRecordId: 'source-presence-shared',
        subjectKey: 'subject-presence-on-page',
      );
      final outsideIssue = _structuredReviewIssue(
        logicalKey: 'presence-outside',
        canonicalFoodId: 'food-presence-shared',
        sourceRecordId: 'source-presence-shared',
        subjectKey: 'subject-presence-outside',
      );
      final repository = _ReviewIssueRepository([onPageIssue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: onPageIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: outsideIssue,
          status: MergeReviewWorkItemStatus.deferred,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _openReviewWorklistInventory(tester);

      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key(
                  'operations_review_worklist_inventory_presence_boundary',
                ),
              ),
            )
            .data,
        'Exact issue-ID membership in this successfully loaded review page '
        'only. Outside can mean another review page or exclusion by the '
        'active review filter; it does not determine orphan, resolved, stale, '
        'current, or live existence.',
      );

      final onPagePresenceKey = Key(
        'operations_review_worklist_inventory_presence_${onPageIssue.id}',
      );
      await _scrollToReviewControl(tester, onPagePresenceKey);
      expect(
        find.descendant(
          of: find.byKey(onPagePresenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      final outsidePresenceKey = Key(
        'operations_review_worklist_inventory_presence_${outsideIssue.id}',
      );
      await _scrollToReviewControl(tester, outsidePresenceKey);
      expect(
        find.descendant(
          of: find.byKey(outsidePresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );

      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_filter_deferred'),
      );
      await _enterReviewWorklistInventorySearch(
        tester,
        'subject-presence-outside',
      );
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      expect(find.byKey(onPagePresenceKey), findsNothing);
      await _scrollToReviewControl(tester, outsidePresenceKey);
      expect(
        find.descendant(
          of: find.byKey(outsidePresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('inventory presence swaps exact markers across review pages', (
    tester,
  ) async {
    final firstPageIssue = _structuredReviewIssue(
      logicalKey: 'presence-first-review-page',
      createdAt: DateTime.utc(2026, 1, 3),
    );
    final secondPageIssue = _structuredReviewIssue(
      logicalKey: 'presence-second-review-page',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final issues = [
      firstPageIssue,
      for (var index = 0; index < 99; index++)
        _structuredReviewIssue(
          logicalKey: 'presence-page-filler-$index',
          createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
        ),
      secondPageIssue,
    ];
    final repository = _ReviewIssueRepository(issues);
    await MergeReviewWorklistStore(repository).upsertAll([
      MergeReviewWorklistUpsert(
        issue: firstPageIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
      MergeReviewWorklistUpsert(
        issue: secondPageIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
    ]);
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineMetaWrites = repository.appMetaWrites.length;
    await _openReviewWorklistInventory(tester);

    const summaryKey = Key(
      'operations_review_worklist_inventory_presence_summary',
    );
    final firstPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${firstPageIssue.id}',
    );
    final secondPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${secondPageIssue.id}',
    );
    await _scrollToReviewControl(tester, firstPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(firstPresenceKey),
        matching: find.text('On loaded review page'),
      ),
      findsOneWidget,
    );
    await _scrollToReviewControl(tester, secondPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(secondPresenceKey),
        matching: find.text('Outside loaded review page'),
      ),
      findsOneWidget,
    );

    await _tapReviewPager(tester, const Key('operations_review_page_next'));

    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _scrollToReviewControl(tester, firstPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(firstPresenceKey),
        matching: find.text('Outside loaded review page'),
      ),
      findsOneWidget,
    );
    await _scrollToReviewControl(tester, secondPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(secondPresenceKey),
        matching: find.text('On loaded review page'),
      ),
      findsOneWidget,
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('presence filter composes with status search and local paging', (
    tester,
  ) async {
    final issues = [
      for (var index = 0; index < 23; index++)
        _structuredReviewIssue(
          logicalKey: 'presence-filter-$index',
          reason: index == 20
              ? 'Needle on-page deferred'
              : index == 21
              ? 'Needle outside deferred'
              : index == 22
              ? 'Different outside queued'
              : 'Needle on-page queued $index',
        ),
    ];
    final repository = _ReviewIssueRepository(
      issues.take(21).toList(growable: false),
    );
    await MergeReviewWorklistStore(repository).upsertAll([
      for (var index = 0; index < issues.length; index++)
        MergeReviewWorklistUpsert(
          issue: issues[index],
          status: index == 20 || index == 21
              ? MergeReviewWorkItemStatus.deferred
              : MergeReviewWorkItemStatus.queued,
        ),
    ]);
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    await _openReviewWorklistInventory(tester);

    const allPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_all',
    );
    const onPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_on_page',
    );
    const outsidePresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_outside_page',
    );
    await _scrollToReviewControl(tester, onPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(onPresenceKey),
        matching: find.text('On loaded page (21)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(outsidePresenceKey),
        matching: find.text('Outside loaded page (2)'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const Key(
                'operations_review_worklist_inventory_presence_filter_boundary',
              ),
            ),
          )
          .data,
      'Presence chip counts cover all loaded stored snapshots. Result '
      'counts combine status, search, and presence. When review-page '
      'comparison is unavailable, the local presence filter resets to All.',
    );

    await _tapReviewControl(tester, onPresenceKey);
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      onPresenceKey,
      true,
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-20 of 21 snapshots on loaded review page '
      '(23 total loaded) / Page 1 of 2',
    );
    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_next'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 21-21 of 21 snapshots on loaded review page '
      '(23 total loaded) / Page 2 of 2',
    );

    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_filter_deferred'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 deferred snapshots on loaded review page '
      '(23 total loaded) / Page 1 of 1',
    );
    await _enterReviewWorklistInventorySearch(tester, 'outside deferred');
    await _expectReviewWorklistInventoryCount(
      tester,
      'No deferred stored review snapshots on the loaded review page '
      'match this search.',
    );

    await _tapReviewControl(tester, outsidePresenceKey);
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 matching deferred snapshots outside loaded review '
      'page (23 total loaded) / Page 1 of 1',
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(issues[21].id)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(issues[20].id)),
      findsNothing,
    );
    await _scrollToReviewControl(tester, allPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(onPresenceKey),
        matching: find.text('On loaded page (21)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(outsidePresenceKey),
        matching: find.text('Outside loaded page (2)'),
      ),
      findsOneWidget,
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.queries, hasLength(baselineReviewQueries));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'successful empty review page enables a true zero presence filter',
    (tester) async {
      final issue = _structuredReviewIssue(
        logicalKey: 'presence-filter-empty-review-page',
        severity: MergeReviewSeverity.high,
      );
      final repository = _ReviewIssueRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      await _openReviewWorklistInventory(tester);

      const allPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_all',
      );
      const onPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      const outsidePresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      await _tapReviewControl(tester, onPresenceKey);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_severity_filter'),
      );
      await _selectReviewFilter(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 1 loaded stored snapshot: 0 on this loaded review page, '
        '1 outside it.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _scrollToReviewControl(tester, onPresenceKey);
      final presenceFilterSemantics = tester.widget<Semantics>(
        find.byKey(
          const Key(
            'operations_review_worklist_inventory_presence_filter_controls',
          ),
        ),
      );
      expect(
        presenceFilterSemantics.properties.label,
        'Loaded review page presence filters',
      );
      expect(presenceFilterSemantics.explicitChildNodes, isTrue);
      expect(
        find.descendant(
          of: find.byKey(onPresenceKey),
          matching: find.text('On loaded page (0)'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<ChoiceChip>(find.byKey(onPresenceKey)).onSelected,
        isNotNull,
      );

      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryCount(
        tester,
        'No stored review snapshots on the loaded review page.',
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_previous'),
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_inventory_previous'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_inventory_next'),
        false,
      );

      await _tapReviewControl(tester, outsidePresenceKey);
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots outside loaded review page '
        '(1 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(issue.id)),
        findsOneWidget,
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 loaded snapshots / Page 1 of 1',
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'inventory presence is unavailable through review refresh failure and retry',
    (tester) async {
      final onPageIssue = _structuredReviewIssue(
        logicalKey: 'presence-refresh-recovery',
      );
      final outsideIssue = _structuredReviewIssue(
        logicalKey: 'presence-refresh-recovery-outside',
      );
      final repository = _ControlledReviewIssueRepository([onPageIssue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: onPageIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: outsideIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      final presenceKey = Key(
        'operations_review_worklist_inventory_presence_${onPageIssue.id}',
      );
      const allPresenceFilterKey = Key(
        'operations_review_worklist_inventory_presence_filter_all',
      );
      const onPresenceFilterKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      const outsidePresenceFilterKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );

      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _scrollToReviewControl(tester, presenceKey);
      expect(
        find.descendant(
          of: find.byKey(presenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      await _tapReviewControl(tester, onPresenceFilterKey);
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots on loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      await _scrollToReviewControl(tester, outsidePresenceFilterKey);
      final staleOutsideFilter = tester
          .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
          .onSelected!;

      repository.holdReviewQueries = true;
      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceFilterKey,
        true,
        settle: false,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
        settle: false,
      );
      await _scrollToReviewControl(tester, onPresenceFilterKey, settle: false);
      expect(
        find.descendant(
          of: find.byKey(onPresenceFilterKey),
          matching: find.text('On loaded page (unavailable)'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<ChoiceChip>(find.byKey(onPresenceFilterKey)).onSelected,
        isNull,
      );
      await _scrollToReviewControl(
        tester,
        outsidePresenceFilterKey,
        settle: false,
      );
      expect(
        find.descendant(
          of: find.byKey(outsidePresenceFilterKey),
          matching: find.text('Outside loaded page (unavailable)'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
            .onSelected,
        isNull,
      );
      staleOutsideFilter(true);
      await tester.pump();
      expect(repository.pendingReviewQueries, hasLength(1));
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceFilterKey,
        true,
        settle: false,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
        settle: false,
      );
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      await _scrollToReviewControl(tester, presenceKey, settle: false);
      expect(
        find.descendant(
          of: find.byKey(presenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );

      repository.failReviewQuery(0);
      await tester.pumpAndSettle();

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_error'),
      );
      expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      await _scrollToReviewControl(tester, presenceKey);
      expect(
        find.descendant(
          of: find.byKey(presenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceFilterKey,
        true,
        settle: false,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
      );

      const retryKey = Key('operations_review_retry');
      await _scrollToReviewControl(tester, retryKey);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceFilterKey,
        true,
        settle: false,
      );
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );

      repository.completeReviewQuery(1);
      await tester.pumpAndSettle();

      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _scrollToReviewControl(tester, presenceKey);
      expect(
        find.descendant(
          of: find.byKey(presenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceFilterKey,
        true,
      );
      await _scrollToReviewControl(tester, outsidePresenceFilterKey);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
            .onSelected,
        isNotNull,
      );
      await _tapReviewControl(tester, outsidePresenceFilterKey);
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots outside loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(outsideIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(onPageIssue.id)),
        findsNothing,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'worklist inventory pages 21 snapshots locally without side effects',
    (tester) async {
      final issues = [
        for (var index = 0; index < 21; index++)
          _structuredReviewIssue(
            logicalKey: 'inventory-page-${index.toString().padLeft(2, '0')}',
          ),
      ];
      final repository = _ReviewIssueRepository([issues.first]);
      final store = MergeReviewWorklistStore(repository);
      await store.upsertAll([
        for (final issue in issues)
          MergeReviewWorklistUpsert(
            issue: issue,
            status: MergeReviewWorkItemStatus.queued,
          ),
      ]);
      final stored = await store.load();
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _openReviewWorklistInventory(tester);

      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-20 of 21 loaded snapshots / Page 1 of 2',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(stored.first.issueId)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(stored.last.issueId)),
        findsNothing,
      );

      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_next'),
      );

      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 21-21 of 21 loaded snapshots / Page 2 of 2',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(stored.first.issueId)),
        findsNothing,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(stored.last.issueId)),
        findsOneWidget,
      );

      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_previous'),
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-20 of 21 loaded snapshots / Page 1 of 2',
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('worklist inventory filters statuses locally and resets paging', (
    tester,
  ) async {
    final issues = [
      for (var index = 0; index < 23; index++)
        _structuredReviewIssue(
          logicalKey: 'inventory-filter-${index.toString().padLeft(2, '0')}',
        ),
    ];
    final repository = _ReviewIssueRepository([issues.first]);
    final store = MergeReviewWorklistStore(repository);
    await store.upsertAll([
      for (var index = 0; index < issues.length; index++)
        MergeReviewWorklistUpsert(
          issue: issues[index],
          status: index < 21
              ? MergeReviewWorkItemStatus.queued
              : MergeReviewWorkItemStatus.deferred,
        ),
    ]);
    final stored = await store.load();
    final queued = stored
        .where((item) => item.status == MergeReviewWorkItemStatus.queued)
        .toList(growable: false);
    final deferred = stored
        .where((item) => item.status == MergeReviewWorkItemStatus.deferred)
        .toList(growable: false);
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _openReviewWorklistInventory(tester);
    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_filter_queued'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-20 of 21 queued snapshots (23 total loaded) / Page 1 of 2',
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      const Key('operations_review_worklist_inventory_filter_queued'),
      true,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(queued.first.issueId)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(deferred.first.issueId)),
      findsNothing,
    );

    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_next'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 21-21 of 21 queued snapshots (23 total loaded) / Page 2 of 2',
    );
    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_filter_deferred'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-2 of 2 deferred snapshots (23 total loaded) / Page 1 of 1',
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      const Key('operations_review_worklist_inventory_filter_deferred'),
      true,
    );
    for (final item in deferred) {
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(item.issueId)),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(queued.first.issueId)),
      findsNothing,
    );

    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_filter_all'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-20 of 23 loaded snapshots / Page 1 of 2',
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.queries, hasLength(baselineReviewQueries));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'worklist inventory search uses only explicit stored snapshot fields',
    (tester) async {
      final canonicalIssue = _structuredReviewIssue(
        logicalKey: 'search-canonical',
        canonicalFoodId: 'Food-CANONICAL-Needle',
      );
      final targetSourceIssue = _structuredReviewIssue(
        logicalKey: 'search-source',
        sourceRecordId: 'Source-TARGET-Needle',
      );
      final subjectIssue = _structuredReviewIssue(
        logicalKey: 'search-subject',
        subjectKey: 'Subject-SUBJECT-Needle',
      );
      final suggestedIssue = _structuredReviewIssue(
        logicalKey: 'search-suggested',
        suggestedCanonicalFoodId: 'Food-SUGGESTED-Needle',
      );
      final reasonIssue = _structuredReviewIssue(
        logicalKey: 'search-reason',
        reason: 'Reason REASON-Needle',
      );
      final candidateIssue = _structuredReviewIssue(
        logicalKey: 'search-candidate',
        candidateSummary: 'Candidate CANDIDATE-Needle',
      );
      final identityIssue = _structuredReviewIssue(
        logicalKey: 'search-identity',
      );
      final issues = [
        canonicalIssue,
        targetSourceIssue,
        subjectIssue,
        suggestedIssue,
        reasonIssue,
        candidateIssue,
        identityIssue,
      ];
      final repository = _ReviewIssueRepository([issues.first]);
      await MergeReviewWorklistStore(repository).upsertAll([
        for (final issue in issues)
          MergeReviewWorklistUpsert(
            issue: issue,
            status: MergeReviewWorkItemStatus.queued,
          ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      await _openReviewWorklistInventory(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_search_scope'),
      );
      expect(
        find.byKey(
          const Key('operations_review_worklist_inventory_search_scope'),
        ),
        findsOneWidget,
      );
      final cases = <({String query, MergeReviewIssue issue})>[
        (query: '  canonical-needle  ', issue: canonicalIssue),
        (query: 'target-needle', issue: targetSourceIssue),
        (query: 'subject-needle', issue: subjectIssue),
        (query: 'suggested-needle', issue: suggestedIssue),
        (query: 'reason-needle', issue: reasonIssue),
        (query: 'candidate-needle', issue: candidateIssue),
        (query: identityIssue.id, issue: identityIssue),
      ];
      for (final searchCase in cases) {
        await _enterReviewWorklistInventorySearch(tester, searchCase.query);
        await _expectReviewWorklistInventoryCount(
          tester,
          'Showing 1-1 of 1 matching snapshots '
          '(${issues.length} total loaded) / Page 1 of 1',
        );
        for (final issue in issues) {
          expect(
            find.byKey(_reviewWorklistInventoryItemKey(issue.id)),
            issue.id == searchCase.issue.id ? findsOneWidget : findsNothing,
          );
        }
      }

      for (final excludedQuery in const [
        'categoryConflictCandidate',
        'queued',
        '2026-01-01',
        '(none)',
      ]) {
        await _enterReviewWorklistInventorySearch(tester, excludedQuery);
        await _expectReviewWorklistInventoryCount(
          tester,
          'No stored review snapshots match this search.',
        );
      }

      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_search_clear'),
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-7 of 7 loaded snapshots / Page 1 of 1',
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('inventory search composes with status and resets local paging', (
    tester,
  ) async {
    final issues = [
      for (var index = 0; index < 23; index++)
        _structuredReviewIssue(
          logicalKey: 'inventory-search-${index.toString().padLeft(2, '0')}',
          reason: index < 21
              ? 'Needle queued-only $index'
              : index == 21
              ? 'Needle deferred-only'
              : 'Different deferred snapshot',
        ),
    ];
    final repository = _ReviewIssueRepository([issues.first]);
    final store = MergeReviewWorklistStore(repository);
    await store.upsertAll([
      for (var index = 0; index < issues.length; index++)
        MergeReviewWorklistUpsert(
          issue: issues[index],
          status: index < 21
              ? MergeReviewWorkItemStatus.queued
              : MergeReviewWorkItemStatus.deferred,
        ),
    ]);
    final stored = await store.load();
    final queued = stored
        .where((item) => item.status == MergeReviewWorkItemStatus.queued)
        .toList(growable: false);
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    await _openReviewWorklistInventory(tester);

    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_next'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 21-23 of 23 loaded snapshots / Page 2 of 2',
    );
    await _enterReviewWorklistInventorySearch(tester, '  NEEDLE  ');
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-20 of 22 matching snapshots '
      '(23 total loaded) / Page 1 of 2',
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(queued.first.issueId)),
      findsOneWidget,
    );

    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_filter_deferred'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 matching deferred snapshots '
      '(23 total loaded) / Page 1 of 1',
    );
    expect(find.text('Deferred (2)'), findsOneWidget);

    await _enterReviewWorklistInventorySearch(tester, 'queued-only');
    await _expectReviewWorklistInventoryCount(
      tester,
      'No deferred stored review snapshots match this search.',
    );
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_previous'),
    );
    _expectReviewWorklistActionEnabled(
      tester,
      const Key('operations_review_worklist_inventory_previous'),
      false,
    );
    _expectReviewWorklistActionEnabled(
      tester,
      const Key('operations_review_worklist_inventory_next'),
      false,
    );

    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_filter_queued'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-20 of 21 matching queued snapshots '
      '(23 total loaded) / Page 1 of 2',
    );
    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_next'),
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(queued.last.issueId)),
      findsOneWidget,
    );
    await _tapReviewControl(
      tester,
      const Key('operations_review_worklist_inventory_search_clear'),
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-20 of 21 queued snapshots '
      '(23 total loaded) / Page 1 of 2',
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.queries, hasLength(baselineReviewQueries));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'empty inventory filter is bounded and resets to ephemeral All on rebuild',
    (tester) async {
      final issue = _structuredReviewIssue(
        logicalKey: 'inventory-empty-filter',
      );
      final repository = _ReviewIssueRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _openReviewWorklistInventory(tester);
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_filter_deferred'),
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'No deferred stored review snapshots.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_filter_deferred'),
        true,
      );
      await _enterReviewWorklistInventorySearch(
        tester,
        '  FOOD-INVENTORY-EMPTY-FILTER  ',
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'No deferred stored review snapshots match this search.',
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_previous'),
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_inventory_previous'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_inventory_next'),
        false,
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_filter_all'),
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 loaded snapshots / Page 1 of 1',
      );
      const searchKey = Key('operations_review_worklist_inventory_search');
      await _scrollToReviewControl(tester, searchKey);
      expect(
        tester.widget<TextField>(find.byKey(searchKey)).controller!.text,
        '',
      );
      expect(
        find.byKey(
          const Key('operations_review_worklist_inventory_search_clear'),
        ),
        findsNothing,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'filtered inventory normalizes after a status mutation shrinks its last page',
    (tester) async {
      final issues = [
        for (var index = 0; index < 22; index++)
          _structuredReviewIssue(
            logicalKey:
                'inventory-filter-shrink-${index.toString().padLeft(2, '0')}',
          ),
      ];
      final repository = _ReviewIssueRepository(issues);
      final store = MergeReviewWorklistStore(repository);
      await store.upsertAll([
        for (var index = 0; index < issues.length; index++)
          MergeReviewWorklistUpsert(
            issue: issues[index],
            status: index == 0
                ? MergeReviewWorkItemStatus.queued
                : MergeReviewWorkItemStatus.deferred,
          ),
      ]);
      final stored = await store.load();
      final lastDeferredItem = stored
          .where((item) => item.status == MergeReviewWorkItemStatus.deferred)
          .last;
      final lastDeferredIssue = issues.singleWhere(
        (issue) => issue.id == lastDeferredItem.issueId,
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _openReviewWorklistInventory(tester);
      await _enterReviewWorklistInventorySearch(
        tester,
        'structured_inventory-filter-shrink',
      );
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_filter_deferred'),
      );
      await _tapReviewControl(
        tester,
        const Key(
          'operations_review_worklist_inventory_presence_filter_on_page',
        ),
      );
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_next'),
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 21-21 of 21 matching deferred snapshots '
        'on loaded review page (22 total loaded) / Page 2 of 2',
      );

      await _selectReviewIssue(tester, lastDeferredIssue);
      await _tapReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );

      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-20 of 20 matching deferred snapshots '
        'on loaded review page (22 total loaded) / Page 1 of 1',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_filter_deferred'),
        true,
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key(
          'operations_review_worklist_inventory_presence_filter_on_page',
        ),
        true,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(lastDeferredItem.issueId)),
        findsNothing,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_inventory_next'),
        false,
      );
      const searchKey = Key('operations_review_worklist_inventory_search');
      await _scrollToReviewControl(tester, searchKey);
      expect(
        tester.widget<TextField>(find.byKey(searchKey)).controller!.text,
        'structured_inventory-filter-shrink',
      );
      final updated = await store.load();
      expect(
        updated
            .singleWhere((item) => item.issueId == lastDeferredItem.issueId)
            .status,
        MergeReviewWorkItemStatus.queued,
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'untracking the last inventory page normalizes back to the remaining page',
    (tester) async {
      final issues = [
        for (var index = 0; index < 21; index++)
          _structuredReviewIssue(
            logicalKey: 'inventory-shrink-${index.toString().padLeft(2, '0')}',
          ),
      ];
      final repository = _ReviewIssueRepository(issues);
      final store = MergeReviewWorklistStore(repository);
      await store.upsertAll([
        for (final issue in issues)
          MergeReviewWorklistUpsert(
            issue: issue,
            status: MergeReviewWorkItemStatus.queued,
          ),
      ]);
      final stored = await store.load();
      final lastPageIssue = issues.singleWhere(
        (issue) => issue.id == stored.last.issueId,
      );
      await _pumpOperationsPage(tester, repository);

      await _openReviewWorklistInventory(tester);
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_next'),
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 21-21 of 21 loaded snapshots / Page 2 of 2',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(lastPageIssue.id)),
        findsOneWidget,
      );

      await _selectReviewIssue(tester, lastPageIssue);
      await _tapReviewControl(
        tester,
        const Key('operations_review_untrack_selected'),
      );

      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-20 of 20 loaded snapshots / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(lastPageIssue.id)),
        findsNothing,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(stored.first.issueId)),
        findsOneWidget,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_inventory_next'),
        false,
      );
      expect(await store.load(), hasLength(20));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'defer and untrack selected update only the matching worklist chips',
    (tester) async {
      final issues = [
        _structuredReviewIssue(logicalKey: 'status-a'),
        _structuredReviewIssue(logicalKey: 'status-b'),
      ];
      final repository = _ReviewIssueRepository(issues);
      await MergeReviewWorklistStore(repository).upsertAll([
        for (final issue in issues)
          MergeReviewWorklistUpsert(
            issue: issue,
            status: MergeReviewWorkItemStatus.queued,
          ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _selectReviewIssue(tester, issues[0]);
      await _tapReviewControl(
        tester,
        const Key('operations_review_defer_selected'),
      );

      await _expectReviewSelectionCount(tester, selected: 0, visible: 2);
      await _expectReviewWorklistStatus(tester, issues[0], 'Deferred');
      await _expectReviewWorklistStatus(tester, issues[1], 'Queued');

      await _selectReviewIssue(tester, issues[0]);
      await _tapReviewControl(
        tester,
        const Key('operations_review_untrack_selected'),
      );

      await _expectReviewSelectionCount(tester, selected: 0, visible: 2);
      await _scrollToReviewControl(
        tester,
        Key('operations_review_issue_select_${issues[0].id}'),
      );
      expect(find.byKey(_reviewWorklistStatusKey(issues[0].id)), findsNothing);
      await _expectReviewWorklistStatus(tester, issues[1], 'Queued');
      final stored = await MergeReviewWorklistStore(repository).load();
      expect(stored, hasLength(1));
      expect(stored.single.issueId, issues[1].id);
      expect(stored.single.status, MergeReviewWorkItemStatus.queued);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'failed worklist mutation retains selection and the prior status chip',
    (tester) async {
      final issue = _structuredReviewIssue(logicalKey: 'write-failure');
      final repository = _FailOnceWorklistWriteRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _selectReviewIssue(tester, issue);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      repository.failNextWorklistWrite = true;

      await _tapReviewControl(
        tester,
        const Key('operations_review_defer_selected'),
      );

      final errorStatus = find.textContaining(
        'Could not update review worklist',
      );
      await tester.scrollUntilVisible(
        errorStatus,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(errorStatus, findsOneWidget);
      await _expectReviewSelectionCount(tester, selected: 1, visible: 1);
      await _expectReviewWorklistStatus(tester, issue, 'Queued');
      final stored = await MergeReviewWorklistStore(repository).load();
      expect(stored, hasLength(1));
      expect(stored.single.status, MergeReviewWorkItemStatus.queued);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.worklistWriteFailures, 1);
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'corrupt worklist refuses mutation until confirmed clear recovers it',
    (tester) async {
      final issue = _structuredReviewIssue(logicalKey: 'corrupt-recovery');
      final repository = _ReviewIssueRepository([issue]);
      const corruptPayload =
          '{"schemaVersion":1,"items":[{"unexpected":true}]}';
      await repository.setAppMeta(
        MergeReviewWorklistStore.metaKey,
        corruptPayload,
      );
      await _pumpOperationsPage(tester, repository);
      await _selectReviewIssue(tester, issue);
      final baselineWrites = repository.appMetaWrites.length;
      final baselineReviewQueries = repository.queries.length;
      final baselineReads = repository.operationsReadCounts;

      await _tapReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );

      await _expectReviewSelectionCount(tester, selected: 1, visible: 1);
      expect(
        await repository.getAppMeta(MergeReviewWorklistStore.metaKey),
        corruptPayload,
      );
      expect(repository.appMetaWrites, hasLength(baselineWrites));
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);

      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_clear'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        await repository.getAppMeta(MergeReviewWorklistStore.metaKey),
        corruptPayload,
      );
      expect(repository.appMetaWrites, hasLength(baselineWrites));

      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_clear'),
      );
      await tester.tap(
        find.byKey(const Key('operations_review_worklist_clear_confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        await repository.getAppMeta(MergeReviewWorklistStore.metaKey),
        MergeReviewWorkItemCodec.emptyPayload,
      );
      expect(repository.appMetaWrites, hasLength(baselineWrites + 1));
      await _expectReviewSelectionCount(tester, selected: 1, visible: 1);

      await _tapReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );

      await _expectReviewSelectionCount(tester, selected: 0, visible: 1);
      await _expectReviewWorklistStatus(tester, issue, 'Queued');
      final stored = await MergeReviewWorklistStore(repository).load();
      expect(stored, hasLength(1));
      expect(stored.single.issueId, issue.id);
      expect(stored.single.status, MergeReviewWorkItemStatus.queued);
      expect(repository.appMetaWrites, hasLength(baselineWrites + 2));
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'held worklist write gates duplicate actions and review context changes',
    (tester) async {
      final issues = [
        for (var index = 0; index < 101; index++)
          _structuredReviewIssue(
            logicalKey: 'held-$index',
            severity: MergeReviewSeverity.high,
            createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
          ),
      ];
      final selectedIssue = issues.last;
      final repository = _ControlledWorklistWriteRepository(issues);
      const activeFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.high,
      );
      final savedView = _savedReviewView(
        id: 'held-write-view',
        name: 'Held write view',
        filter: activeFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        activeFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: selectedIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);
      await _enterReviewWorklistInventorySearch(tester, 'held-100');
      const inventorySearchKey = Key(
        'operations_review_worklist_inventory_search',
      );
      const inventorySearchClearKey = Key(
        'operations_review_worklist_inventory_search_clear',
      );
      await _scrollToReviewControl(tester, inventorySearchKey);
      final staleInventorySearch = tester
          .widget<TextField>(find.byKey(inventorySearchKey))
          .onChanged!;
      await _scrollToReviewControl(tester, inventorySearchClearKey);
      final staleInventorySearchClear = tester
          .widget<IconButton>(find.byKey(inventorySearchClearKey))
          .onPressed!;
      const queuedInventoryFilterKey = Key(
        'operations_review_worklist_inventory_filter_queued',
      );
      await _scrollToReviewControl(tester, queuedInventoryFilterKey);
      final staleQueuedInventoryFilter = tester
          .widget<ChoiceChip>(find.byKey(queuedInventoryFilterKey))
          .onSelected!;
      const outsidePresenceFilterKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      await _scrollToReviewControl(tester, outsidePresenceFilterKey);
      final staleOutsidePresenceFilter = tester
          .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
          .onSelected!;
      await _selectReviewIssue(tester, selectedIssue);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_defer_selected'),
      );
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;

      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_defer_selected'),
        true,
      );
      _expectReviewContextControlsEnabled(tester, enabled: true);
      repository.holdWorklistWrites = true;
      await tester.tap(
        find.byKey(const Key('operations_review_defer_selected')),
      );
      await tester.pump();

      expect(repository.pendingWorklistWrites, hasLength(1));
      final pendingItems = MergeReviewWorkItemCodec.decode(
        repository.pendingWorklistWrites.single.value,
      );
      expect(pendingItems, hasLength(1));
      expect(pendingItems.single.status, MergeReviewWorkItemStatus.deferred);
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_queue_selected'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_defer_selected'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_untrack_selected'),
        false,
      );
      final selectedCheckboxKey = Key(
        'operations_review_issue_select_${selectedIssue.id}',
      );
      await _scrollToReviewControl(tester, selectedCheckboxKey);
      expect(
        tester.widget<Checkbox>(find.byKey(selectedCheckboxKey)).onChanged,
        isNull,
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_select_visible'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_clear_selection'),
        false,
      );
      _expectReviewContextControlsEnabled(tester, enabled: false);
      for (final key in const [
        Key('operations_review_worklist_inventory_filter_all'),
        Key('operations_review_worklist_inventory_filter_queued'),
        Key('operations_review_worklist_inventory_filter_deferred'),
        Key('operations_review_worklist_inventory_presence_filter_all'),
        Key('operations_review_worklist_inventory_presence_filter_on_page'),
        Key(
          'operations_review_worklist_inventory_presence_filter_outside_page',
        ),
      ]) {
        await _scrollToReviewControl(tester, key);
        expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
      }
      await _scrollToReviewControl(tester, inventorySearchKey);
      final disabledSearch = tester.widget<TextField>(
        find.byKey(inventorySearchKey),
      );
      expect(disabledSearch.enabled, isFalse);
      expect(disabledSearch.onChanged, isNull);
      expect(disabledSearch.controller!.text, 'held-100');
      await _scrollToReviewControl(tester, inventorySearchClearKey);
      expect(
        tester
            .widget<IconButton>(find.byKey(inventorySearchClearKey))
            .onPressed,
        isNull,
      );
      staleQueuedInventoryFilter(true);
      staleOutsidePresenceFilter(true);
      staleInventorySearch('no-match');
      staleInventorySearchClear();
      await tester.pump();
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_filter_all'),
        true,
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_presence_filter_all'),
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 matching snapshots '
        '(1 total loaded) / Page 1 of 1',
      );
      await _scrollToReviewControl(tester, inventorySearchKey);
      expect(
        tester
            .widget<TextField>(find.byKey(inventorySearchKey))
            .controller!
            .text,
        'held-100',
      );
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);

      repository.completeWorklistWrite(0);
      await tester.pumpAndSettle();

      await _expectReviewSelectionCount(tester, selected: 0, visible: 100);
      await _expectReviewWorklistStatus(tester, selectedIssue, 'Deferred');
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
      );
      _expectReviewContextControlsEnabled(tester, enabled: true);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_filter_all'),
        true,
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_presence_filter_all'),
        true,
      );
      await _scrollToReviewControl(tester, queuedInventoryFilterKey);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(queuedInventoryFilterKey))
            .onSelected,
        isNotNull,
      );
      await _scrollToReviewControl(tester, outsidePresenceFilterKey);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
            .onSelected,
        isNotNull,
      );
      await _scrollToReviewControl(tester, inventorySearchKey);
      final enabledSearch = tester.widget<TextField>(
        find.byKey(inventorySearchKey),
      );
      expect(enabledSearch.enabled, isTrue);
      expect(enabledSearch.onChanged, isNotNull);
      expect(enabledSearch.controller!.text, 'held-100');
      await _scrollToReviewControl(tester, inventorySearchClearKey);
      expect(
        tester
            .widget<IconButton>(find.byKey(inventorySearchClearKey))
            .onPressed,
        isNotNull,
      );
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'stale refresh callback defers one full refresh until worklist commit',
    (tester) async {
      final issue = _structuredReviewIssue(logicalKey: 'deferred-refresh');
      final repository = _ControlledWorklistWriteRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final staleRefresh = tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed!;
      await _selectReviewIssue(tester, issue);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_defer_selected'),
      );
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineWorklistReads = repository.worklistReadCount;
      repository.holdWorklistWrites = true;

      await tester.tap(
        find.byKey(const Key('operations_review_defer_selected')),
      );
      await tester.pump();

      expect(repository.pendingWorklistWrites, hasLength(1));
      expect(repository.worklistReadCount, baselineWorklistReads + 1);
      final readsAfterMutationLoad = repository.worklistReadCount;
      staleRefresh();
      await tester.pump();

      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.worklistReadCount, readsAfterMutationLoad);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
            .onPressed,
        isNull,
      );

      repository.completeWorklistWrite(0);
      await tester.pumpAndSettle();

      expect(repository.recentFetchJobsReadCount, baselineReads.jobs + 1);
      expect(repository.datasetArtifactsReadCount, baselineReads.artifacts + 2);
      expect(repository.importLogsReadCount, baselineReads.logs + 1);
      expect(repository.exportHistoryReadCount, baselineReads.exports + 1);
      expect(repository.governanceLogsReadCount, baselineReads.governance + 1);
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.worklistReadCount, readsAfterMutationLoad + 1);
      await _expectReviewSelectionCount(tester, selected: 0, visible: 1);
      await _expectReviewWorklistStatus(tester, issue, 'Deferred');
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_count'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('operations_review_worklist_count')),
            )
            .data,
        'Worklist: 0 queued, 1 deferred',
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'pending manual split gates worklist actions until its refresh completes',
    (tester) async {
      final issue = _structuredReviewIssue(logicalKey: 'held-governance');
      final repository = _ControlledGovernanceRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _selectReviewIssue(tester, issue);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineWorklistPayload = await repository.getAppMeta(
        MergeReviewWorklistStore.metaKey,
      );
      repository.holdSplitActions = true;

      await tester.tap(find.widgetWithText(OutlinedButton, 'Split source'));
      await tester.pump();

      expect(repository.pendingSplitActions, hasLength(1));
      final queueKey = const Key('operations_review_queue_selected');
      await tester.scrollUntilVisible(
        find.byKey(queueKey),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(queueKey)),
        alignment: 0.5,
      );
      await tester.pump();
      _expectReviewWorklistActionEnabled(tester, queueKey, false);
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_defer_selected'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_untrack_selected'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_clear'),
        false,
      );
      expect(
        await repository.getAppMeta(MergeReviewWorklistStore.metaKey),
        baselineWorklistPayload,
      );
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);

      repository.completeSplitAction(0);
      await tester.pumpAndSettle();

      await _expectReviewSelectionCount(tester, selected: 1, visible: 1);
      _expectReviewWorklistActionEnabled(tester, queueKey, true);
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_defer_selected'),
        true,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_untrack_selected'),
        true,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_worklist_clear'),
        true,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(repository.recentFetchJobsReadCount, baselineReads.jobs + 1);
      expect(repository.datasetArtifactsReadCount, baselineReads.artifacts + 2);
      expect(repository.importLogsReadCount, baselineReads.logs + 1);
      expect(repository.exportHistoryReadCount, baselineReads.exports + 1);
      expect(repository.governanceLogsReadCount, baselineReads.governance + 1);
      expect(repository.splitSourceRecordCallCount, 1);
      expect(
        await repository.getAppMeta(MergeReviewWorklistStore.metaKey),
        baselineWorklistPayload,
      );
    },
  );

  testWidgets(
    'same-id snapshot drift is marked stale until the live issue is re-queued',
    (tester) async {
      final storedIssue = _structuredReviewIssue(logicalKey: 'snapshot-drift');
      final liveIssue = MergeReviewIssue(
        id: storedIssue.id,
        canonicalFoodId: storedIssue.canonicalFoodId,
        sourceRecordId: storedIssue.sourceRecordId,
        type: storedIssue.type,
        severity: storedIssue.severity,
        reason: 'SNAPSHOT_CHANGED_REASON',
        candidateSummary: 'snapshot-changed-candidate',
        createdAt: storedIssue.createdAt.add(const Duration(days: 1)),
      );
      final repository = _ReviewIssueRepository([liveIssue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: storedIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);

      await _expectReviewWorklistStatus(tester, liveIssue, 'Queued');
      final staleKey = Key(
        'operations_review_issue_worklist_stale_${liveIssue.id}',
      );
      await _scrollToReviewControl(tester, staleKey);
      expect(
        find.descendant(
          of: find.byKey(staleKey),
          matching: find.text('Review snapshot changed'),
        ),
        findsOneWidget,
      );
      final baselineReviewQueries = repository.queries.length;

      await _selectReviewIssue(tester, liveIssue);
      await _tapReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );

      await _expectReviewSelectionCount(tester, selected: 0, visible: 1);
      await _expectReviewWorklistStatus(tester, liveIssue, 'Queued');
      expect(find.byKey(staleKey), findsNothing);
      final stored = await MergeReviewWorklistStore(repository).load();
      expect(stored, hasLength(1));
      expect(stored.single.reason, liveIssue.reason);
      expect(stored.single.candidateSummary, liveIssue.candidateSummary);
      expect(stored.single.issueCreatedAt, liveIssue.createdAt.toUtc());
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('suggested canonical whitespace does not mark a snapshot stale', (
    tester,
  ) async {
    final base = _structuredReviewIssue(logicalKey: 'trimmed-suggestion');
    final issue = MergeReviewIssue(
      id: base.id,
      canonicalFoodId: base.canonicalFoodId,
      sourceRecordId: base.sourceRecordId,
      type: base.type,
      severity: base.severity,
      reason: base.reason,
      candidateSummary: base.candidateSummary,
      createdAt: base.createdAt,
      suggestedCanonicalFoodId: '  suggested-food  ',
    );
    final repository = _ReviewIssueRepository([issue]);
    await MergeReviewWorklistStore(repository).upsertAll([
      MergeReviewWorklistUpsert(
        issue: issue,
        status: MergeReviewWorkItemStatus.queued,
      ),
    ]);

    await _pumpOperationsPage(tester, repository);

    await _expectReviewWorklistStatus(tester, issue, 'Queued');
    expect(
      find.byKey(Key('operations_review_issue_worklist_stale_${issue.id}')),
      findsNothing,
    );
    final stored = await MergeReviewWorklistStore(repository).load();
    expect(stored.single.suggestedCanonicalFoodId, 'suggested-food');
  });

  testWidgets(
    'worklist actions gate during review loading and ignore unmatched items',
    (tester) async {
      final visibleIssue = _structuredReviewIssue(
        logicalKey: 'visible',
        canonicalFoodId: 'food-shared',
        sourceRecordId: 'source-shared',
      );
      final unmatchedIssue = _structuredReviewIssue(
        logicalKey: 'unmatched',
        canonicalFoodId: 'food-shared',
        sourceRecordId: 'source-shared',
      );
      final repository = _ControlledReviewIssueRepository([visibleIssue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: unmatchedIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);

      await _scrollToReviewControl(
        tester,
        Key('operations_review_issue_select_${visibleIssue.id}'),
      );
      expect(
        find.byKey(_reviewWorklistStatusKey(visibleIssue.id)),
        findsNothing,
      );
      expect(
        find.byKey(_reviewWorklistStatusKey(unmatchedIssue.id)),
        findsNothing,
      );

      await _selectReviewIssue(tester, visibleIssue);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_queue_selected'),
      );
      repository.holdReviewQueries = true;
      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.pendingReviewQueries, hasLength(1));
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_queue_selected'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_defer_selected'),
        false,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_untrack_selected'),
        false,
      );

      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _expectReviewSelectionCount(tester, selected: 1, visible: 1);
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_queue_selected'),
        true,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_defer_selected'),
        true,
      );
      _expectReviewWorklistActionEnabled(
        tester,
        const Key('operations_review_untrack_selected'),
        false,
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'worklist read failure is isolated and inline retry restores its snapshot',
    (tester) async {
      final issue = _structuredReviewIssue(logicalKey: 'read-retry');
      final repository = _FailOnceWorklistReadRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await repository.upsertFetchJob(
        _fetchJob(
          id: 'worklist-read-isolation-job',
          message: 'WORKLIST_READ_OPERATIONS_LOADED',
        ),
      );
      repository.failNextWorklistRead = true;

      await _pumpOperationsPage(tester, repository);

      expect(find.text('Operations'), findsOneWidget);
      expect(find.byKey(const Key('operations_refresh_error')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (1 total)',
      );
      expect(repository.worklistReadFailures, 1);
      expect(
        find.byKey(const Key('operations_review_worklist_inventory')),
        findsNothing,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(issue.id)),
        findsNothing,
      );
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_retry'),
      );

      expect(
        find.byKey(const Key('operations_review_worklist_error')),
        findsNothing,
      );
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_count'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('operations_review_worklist_count')),
            )
            .data,
        'Worklist: 1 queued, 0 deferred',
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 loaded snapshots / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(issue.id)),
        findsOneWidget,
      );
      await _expectReviewWorklistStatus(tester, issue, 'Queued');
      await _enterReviewWorklistInventorySearch(tester, 'read-retry');
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 matching snapshots '
        '(1 total loaded) / Page 1 of 1',
      );
      expect(repository.queries, hasLength(baselineReviewQueries));
      expect(repository.operationsReadCounts, baselineReads);
      await _expectReviewTextVisible(tester, 'WORKLIST_READ_OPERATIONS_LOADED');
      expect(repository.governanceMutationCount, 0);

      repository.failNextWorklistRead = true;
      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pumpAndSettle();

      expect(repository.worklistReadFailures, 2);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_error'),
      );
      expect(
        find.byKey(const Key('operations_review_worklist_error')),
        findsOneWidget,
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_count'),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const Key('operations_review_worklist_inventory_count'),
              ),
            )
            .data,
        'Showing 1-1 of 1 matching snapshots '
        '(1 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(const Key('operations_review_worklist_inventory_boundary')),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(issue.id)),
        findsOneWidget,
      );
      const searchKey = Key('operations_review_worklist_inventory_search');
      await _scrollToReviewControl(tester, searchKey);
      final search = tester.widget<TextField>(find.byKey(searchKey));
      expect(search.enabled, isTrue);
      expect(search.controller!.text, 'read-retry');
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'held worklist read locks inventory and clamps a refreshed search page',
    (tester) async {
      final issues = [
        for (var index = 0; index < 22; index++)
          _structuredReviewIssue(
            logicalKey: 'held-read-${index.toString().padLeft(2, '0')}',
            reason: index < 21
                ? 'Needle held read $index'
                : 'Different deferred snapshot',
          ),
      ];
      final repository = _ControlledWorklistReadRepository(
        issues.take(21).toList(growable: false),
      );
      final store = MergeReviewWorklistStore(repository);
      await store.upsertAll([
        for (var index = 0; index < issues.length; index++)
          MergeReviewWorklistUpsert(
            issue: issues[index],
            status: index < 21
                ? MergeReviewWorkItemStatus.queued
                : MergeReviewWorkItemStatus.deferred,
          ),
      ]);
      final stored = await store.load();
      final queued = stored
          .where((item) => item.status == MergeReviewWorkItemStatus.queued)
          .toList(growable: false);
      final removedItem = queued.last;
      await _pumpOperationsPage(tester, repository);
      repository.failNextWorklistRead = true;
      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pumpAndSettle();

      expect(repository.worklistReadFailures, 1);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_error'),
      );
      expect(
        find.byKey(const Key('operations_review_worklist_error')),
        findsOneWidget,
      );
      await _openReviewWorklistInventory(tester);
      await _enterReviewWorklistInventorySearch(tester, 'needle');
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_filter_queued'),
      );
      const onPresenceFilterKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      const outsidePresenceFilterKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      await _tapReviewControl(tester, onPresenceFilterKey);
      await _tapReviewControl(
        tester,
        const Key('operations_review_worklist_inventory_next'),
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 21-21 of 21 matching queued snapshots '
        'on loaded review page (22 total loaded) / Page 2 of 2',
      );

      const searchKey = Key('operations_review_worklist_inventory_search');
      const clearKey = Key('operations_review_worklist_inventory_search_clear');
      const allFilterKey = Key(
        'operations_review_worklist_inventory_filter_all',
      );
      const previousKey = Key('operations_review_worklist_inventory_previous');
      await _scrollToReviewControl(tester, searchKey);
      final staleSearch = tester
          .widget<TextField>(find.byKey(searchKey))
          .onChanged!;
      await _scrollToReviewControl(tester, clearKey);
      final staleClear = tester
          .widget<IconButton>(find.byKey(clearKey))
          .onPressed!;
      await _scrollToReviewControl(tester, allFilterKey);
      final staleAllFilter = tester
          .widget<ChoiceChip>(find.byKey(allFilterKey))
          .onSelected!;
      await _scrollToReviewControl(tester, outsidePresenceFilterKey);
      final staleOutsidePresenceFilter = tester
          .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
          .onSelected!;
      await _scrollToReviewControl(tester, previousKey);
      final stalePrevious = tester
          .widget<ButtonStyleButton>(find.byKey(previousKey))
          .onPressed!;

      final baselineMetaWrites = repository.appMetaWrites.length;
      await repository.setAppMeta(
        MergeReviewWorklistStore.metaKey,
        MergeReviewWorkItemCodec.encode(
          stored.where((item) => item.issueId != removedItem.issueId),
        ),
      );
      repository.holdWorklistReads = true;
      final baselineWorklistReads = repository.worklistReadCount;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_retry'),
      );
      await tester.tap(
        find.byKey(const Key('operations_review_worklist_retry')),
      );
      await tester.pump();

      expect(repository.pendingWorklistReads, hasLength(1));
      expect(repository.worklistReadCount, baselineWorklistReads + 1);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_worklist_loading'),
        settle: false,
      );
      expect(
        find.byKey(const Key('operations_review_worklist_loading')),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, searchKey, settle: false);
      final disabledSearch = tester.widget<TextField>(find.byKey(searchKey));
      expect(disabledSearch.enabled, isFalse);
      expect(disabledSearch.onChanged, isNull);
      expect(disabledSearch.controller!.text, 'needle');
      await _scrollToReviewControl(tester, clearKey, settle: false);
      expect(tester.widget<IconButton>(find.byKey(clearKey)).onPressed, isNull);
      await _scrollToReviewControl(tester, allFilterKey, settle: false);
      expect(
        tester.widget<ChoiceChip>(find.byKey(allFilterKey)).onSelected,
        isNull,
      );
      await _scrollToReviewControl(
        tester,
        outsidePresenceFilterKey,
        settle: false,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
            .onSelected,
        isNull,
      );
      await _scrollToReviewControl(tester, previousKey, settle: false);
      _expectReviewWorklistActionEnabled(tester, previousKey, false);

      final reviewQueriesAfterRefreshStarted = repository.queries.length;
      final operationsReadsAfterRefreshStarted =
          repository.operationsReadCounts;
      staleSearch('no-match');
      staleClear();
      staleAllFilter(true);
      staleOutsidePresenceFilter(true);
      stalePrevious();
      await tester.pump();

      const queuedFilterKey = Key(
        'operations_review_worklist_inventory_filter_queued',
      );
      await _scrollToReviewControl(tester, queuedFilterKey, settle: false);
      expect(
        tester.widget<ChoiceChip>(find.byKey(queuedFilterKey)).selected,
        isTrue,
      );
      await _scrollToReviewControl(tester, onPresenceFilterKey, settle: false);
      expect(
        tester.widget<ChoiceChip>(find.byKey(onPresenceFilterKey)).selected,
        isTrue,
      );
      const countKey = Key('operations_review_worklist_inventory_count');
      await _scrollToReviewControl(tester, countKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(countKey)).data,
        'Showing 21-21 of 21 matching queued snapshots '
        'on loaded review page (22 total loaded) / Page 2 of 2',
      );
      await _scrollToReviewControl(tester, searchKey, settle: false);
      expect(
        tester.widget<TextField>(find.byKey(searchKey)).controller!.text,
        'needle',
      );
      expect(repository.queries, hasLength(reviewQueriesAfterRefreshStarted));
      expect(
        repository.operationsReadCounts,
        operationsReadsAfterRefreshStarted,
      );

      await repository.completeWorklistRead(0);
      await tester.pumpAndSettle();

      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        const Key('operations_review_worklist_inventory_filter_queued'),
        true,
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceFilterKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-20 of 20 matching queued snapshots '
        'on loaded review page (21 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(removedItem.issueId)),
        findsNothing,
      );
      await _scrollToReviewControl(tester, searchKey);
      final enabledSearch = tester.widget<TextField>(find.byKey(searchKey));
      expect(enabledSearch.enabled, isTrue);
      expect(enabledSearch.onChanged, isNotNull);
      expect(enabledSearch.controller!.text, 'needle');
      await _scrollToReviewControl(tester, clearKey);
      expect(
        tester.widget<IconButton>(find.byKey(clearKey)).onPressed,
        isNotNull,
      );
      await _scrollToReviewControl(tester, outsidePresenceFilterKey);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(outsidePresenceFilterKey))
            .onSelected,
        isNotNull,
      );
      expect(
        find.descendant(
          of: find.byKey(onPresenceFilterKey),
          matching: find.text('On loaded page (20)'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(outsidePresenceFilterKey),
          matching: find.text('Outside loaded page (1)'),
        ),
        findsOneWidget,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'held saved-view init does not block operations or worklist lanes',
    (tester) async {
      final issue = _structuredReviewIssue(logicalKey: 'saved-view-init');
      final repository = _ControlledSavedViewReadRepository([issue]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: issue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await repository.upsertFetchJob(
        _fetchJob(
          id: 'saved-view-init-job',
          message: 'SAVED_VIEW_INIT_OPERATIONS_READY',
        ),
      );
      repository.holdSavedViewReads = true;

      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(repository.pendingSavedViewReads, hasLength(1));
      expect(repository.queries, isEmpty);
      expect(repository.operationsReadCounts, (
        jobs: 1,
        artifacts: 2,
        logs: 1,
        exports: 1,
        governance: 1,
      ));
      final worklistCount = find.byKey(
        const Key('operations_review_worklist_count'),
      );
      await tester.scrollUntilVisible(
        worklistCount,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(
        tester.widget<Text>(worklistCount).data,
        'Worklist: 1 queued, 0 deferred',
      );
      await _expectReviewLoading(tester);
      final operationsMessage = find.textContaining(
        'SAVED_VIEW_INIT_OPERATIONS_READY',
      );
      await tester.scrollUntilVisible(
        operationsMessage,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(operationsMessage, findsOneWidget);
      expect(repository.queries, isEmpty);

      repository.completeSavedViewRead(0);
      await tester.pumpAndSettle();

      expect(repository.queries, hasLength(1));
      final statusKey = _reviewWorklistStatusKey(issue.id);
      await tester.scrollUntilVisible(
        find.byKey(statusKey),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(statusKey)),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(statusKey),
          matching: find.text('Queued'),
        ),
        findsOneWidget,
      );
      final reviewCount = find.byKey(
        const Key('operations_review_filter_count'),
      );
      await tester.scrollUntilVisible(
        reviewCount,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(reviewCount).data,
        'Showing 1 of 1 matching review issues (1 total)',
      );
    },
  );

  testWidgets('invalid saved review filters fail open to All', (tester) async {
    const invalidPayloads = [
      '{"schemaVersion":1,"severity":',
      '{"schemaVersion":2,"severity":"warning",'
          '"type":"categoryConflictCandidate"}',
      '{"schemaVersion":1,"severity":"critical",'
          '"type":"categoryConflictCandidate"}',
      '{"schemaVersion":1,"severity":"warning","type":"futureType"}',
    ];

    for (final payload in invalidPayloads) {
      final repository = _ReviewIssueRepository(_reviewIssues());
      await repository.setAppMeta('merge_review_filter_v1', payload);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpOperationsPage(tester, repository);

      await _expectReviewCount(
        tester,
        'Showing 1-3 of 3 matching review issues (3 total)',
      );
      expect(find.text('All severities'), findsOneWidget);
      expect(find.text('All issue types'), findsOneWidget);
    }
  });

  testWidgets('repository filter reaches a match beyond the first page', (
    tester,
  ) async {
    final repository = _ReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 102 matching review issues (102 total)',
    );

    await _selectReviewFilter(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    await _selectReviewFilter(
      tester,
      key: const Key('operations_review_type_filter'),
      option: 'Low-confidence reuse',
    );

    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    final query = repository.queries.last;
    expect(query.offset, 0);
    expect(query.filter.severity, MergeReviewSeverity.warning);
    expect(query.filter.type, MergeReviewIssueType.lowConfidenceReuse);
  });

  testWidgets('review pager requests next and previous backlog offsets', (
    tester,
  ) async {
    final repository = _ReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);

    await _tapReviewPager(tester, const Key('operations_review_page_next'));
    await _expectReviewCount(
      tester,
      'Showing 101-102 of 102 matching review issues (102 total)',
    );
    expect(repository.queries.last.offset, 100);

    await _tapReviewPager(tester, const Key('operations_review_page_previous'));
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 102 matching review issues (102 total)',
    );
    expect(repository.queries.last.offset, 0);
  });

  testWidgets('review filter and pager avoid unrelated operations reads', (
    tester,
  ) async {
    final repository = _ReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;

    await _selectReviewFilter(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'High',
    );

    expect(repository.queries, hasLength(baselineReviewQueries + 1));
    expect(repository.operationsReadCounts, baselineReads);

    await _tapReviewPager(tester, const Key('operations_review_page_next'));

    expect(repository.queries, hasLength(baselineReviewQueries + 2));
    expect(repository.queries.last.offset, 100);
    expect(repository.operationsReadCounts, baselineReads);
  });

  testWidgets('toolbar Refresh still reloads every operations read', (
    tester,
  ) async {
    final repository = _ReviewIssueRepository(_reviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;

    await tester.tap(find.byTooltip('Refresh operations data'));
    await tester.pumpAndSettle();

    expect(repository.recentFetchJobsReadCount, baselineReads.jobs + 1);
    expect(repository.datasetArtifactsReadCount, baselineReads.artifacts + 2);
    expect(repository.importLogsReadCount, baselineReads.logs + 1);
    expect(repository.exportHistoryReadCount, baselineReads.exports + 1);
    expect(repository.governanceLogsReadCount, baselineReads.governance + 1);
    expect(repository.queries, hasLength(baselineReviewQueries + 1));
  });

  testWidgets('latest review filter wins when requests finish out of order', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    repository.holdReviewQueries = true;

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(1));
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('operations_review_page_next')),
          )
          .onPressed,
      isNull,
    );
    final reviewLoading = find.byKey(const Key('operations_review_loading'));
    await tester.scrollUntilVisible(
      reviewLoading,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(reviewLoading, findsOneWidget);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_type_filter'),
      option: 'Low-confidence reuse',
      scrollDelta: -250,
    );
    expect(repository.pendingReviewQueries, hasLength(2));

    repository.completeReviewQuery(1);
    await tester.pumpAndSettle();
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');

    repository.completeReviewQuery(0);
    await tester.pumpAndSettle();
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
  });

  testWidgets('latest review request owns a stale corrective second query', (
    tester,
  ) async {
    final highIssues = [
      for (var index = 0; index < 101; index++)
        _structuredReviewIssue(
          logicalKey: 'corrective-high-$index',
          severity: MergeReviewSeverity.high,
          createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
        ),
    ];
    final warningReuseIssue = _structuredReviewIssue(
      logicalKey: 'corrective-warning-reuse',
      type: MergeReviewIssueType.lowConfidenceReuse,
      severity: MergeReviewSeverity.warning,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final trackedHighIssue = highIssues.last;
    final reviewIssues = [...highIssues, warningReuseIssue];
    final repository = _ControlledReviewIssueRepository(reviewIssues);
    await MergeReviewWorklistStore(repository).upsertAll([
      MergeReviewWorklistUpsert(
        issue: trackedHighIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
      MergeReviewWorklistUpsert(
        issue: warningReuseIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
    ]);
    await _pumpOperationsPage(tester, repository);
    await _openReviewWorklistInventory(tester);

    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;
    const summaryKey = Key(
      'operations_review_worklist_inventory_presence_summary',
    );
    const allPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_all',
    );
    const onPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_on_page',
    );
    final highPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${trackedHighIssue.id}',
    );
    final warningPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
    );
    final warningReviewSelectKey = Key(
      'operations_review_issue_select_${warningReuseIssue.id}',
    );

    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _tapReviewControl(tester, onPresenceKey);
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
      findsNothing,
    );

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      allPresenceKey,
      true,
      settle: false,
    );
    await _scrollToReviewControl(tester, summaryKey, settle: false);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Loaded review page comparison unavailable until the latest selected '
      'filter/page request succeeds.',
    );

    repository.completeReviewQueryWithPage(
      0,
      MergeReviewIssuePage(
        items: const [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    repository.completeReviewQuery(2);
    await tester.pumpAndSettle();

    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _scrollToReviewControl(tester, warningReviewSelectKey);
    expect(find.byKey(warningReviewSelectKey), findsOneWidget);
    await _openReviewWorklistInventory(tester);
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _scrollToReviewControl(tester, highPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(highPresenceKey),
        matching: find.text('Outside loaded review page'),
      ),
      findsOneWidget,
    );
    await _scrollToReviewControl(tester, warningPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(warningPresenceKey),
        matching: find.text('On loaded review page'),
      ),
      findsOneWidget,
    );
    await _tapReviewControl(tester, onPresenceKey);
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      onPresenceKey,
      true,
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 snapshots on loaded review page '
      '(2 total loaded) / Page 1 of 1',
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
      findsNothing,
    );
    final readsAfterLatestSuccess = repository.operationsReadCounts;
    final metaWritesAfterLatestSuccess = repository.appMetaWrites.length;

    repository.completeReviewQuery(1);
    await tester.pumpAndSettle();

    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _scrollToReviewControl(tester, warningReviewSelectKey);
    expect(find.byKey(warningReviewSelectKey), findsOneWidget);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      onPresenceKey,
      true,
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 snapshots on loaded review page '
      '(2 total loaded) / Page 1 of 1',
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
      findsNothing,
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestSuccess);
    expect(repository.queries, hasLength(baselineReviewQueries + 3));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestSuccess));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('latest review success ignores an older corrective failure', (
    tester,
  ) async {
    final highIssues = [
      for (var index = 0; index < 101; index++)
        _structuredReviewIssue(
          logicalKey: 'stale-corrective-failure-high-$index',
          severity: MergeReviewSeverity.high,
          createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
        ),
    ];
    final warningReuseIssue = _structuredReviewIssue(
      logicalKey: 'stale-corrective-failure-warning-reuse',
      type: MergeReviewIssueType.lowConfidenceReuse,
      severity: MergeReviewSeverity.warning,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final trackedHighIssue = highIssues.last;
    final repository = _ControlledReviewIssueRepository([
      ...highIssues,
      warningReuseIssue,
    ]);
    await MergeReviewWorklistStore(repository).upsertAll([
      MergeReviewWorklistUpsert(
        issue: trackedHighIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
      MergeReviewWorklistUpsert(
        issue: warningReuseIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
    ]);
    await _pumpOperationsPage(tester, repository);
    await _openReviewWorklistInventory(tester);

    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;
    const summaryKey = Key(
      'operations_review_worklist_inventory_presence_summary',
    );
    const onPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_on_page',
    );
    const outsidePresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_outside_page',
    );
    final highPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${trackedHighIssue.id}',
    );
    final warningPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
    );
    final highReviewSelectKey = Key(
      'operations_review_issue_select_${trackedHighIssue.id}',
    );
    final warningReviewSelectKey = Key(
      'operations_review_issue_select_${warningReuseIssue.id}',
    );

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    repository.completeReviewQuery(2);
    await tester.pumpAndSettle();

    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _scrollToReviewControl(tester, warningReviewSelectKey);
    expect(find.byKey(warningReviewSelectKey), findsOneWidget);
    expect(find.byKey(highReviewSelectKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _scrollToReviewControl(tester, highPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(highPresenceKey),
        matching: find.text('Outside loaded review page'),
      ),
      findsOneWidget,
    );
    await _scrollToReviewControl(tester, warningPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(warningPresenceKey),
        matching: find.text('On loaded review page'),
      ),
      findsOneWidget,
    );
    await _tapReviewControl(tester, onPresenceKey);
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      onPresenceKey,
      true,
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 snapshots on loaded review page '
      '(2 total loaded) / Page 1 of 1',
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true],
    );
    expect(tester.takeException(), isNull);
    final readsAfterLatestSuccess = repository.operationsReadCounts;
    final metaWritesAfterLatestSuccess = repository.appMetaWrites.length;

    repository.failReviewQuery(1, message: 'STALE_CORRECTIVE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('STALE_CORRECTIVE_FAILURE'), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _scrollToReviewControl(tester, warningReviewSelectKey);
    expect(find.byKey(warningReviewSelectKey), findsOneWidget);
    expect(find.byKey(highReviewSelectKey), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      onPresenceKey,
      true,
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 snapshots on loaded review page '
      '(2 total loaded) / Page 1 of 1',
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
      findsOneWidget,
    );
    expect(
      find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
      findsNothing,
    );
    await _scrollToReviewControl(tester, warningPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(warningPresenceKey),
        matching: find.text('On loaded review page'),
      ),
      findsOneWidget,
    );
    for (final key in const [onPresenceKey, outsidePresenceKey]) {
      await _scrollToReviewControl(tester, key);
      expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNotNull);
    }
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(
      repository.pendingReviewQueries.every(
        (pending) => pending.completer.isCompleted,
      ),
      isTrue,
    );
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestSuccess);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestSuccess));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'latest review failure owns retry after an older corrective failure',
    (tester) async {
      final highIssues = [
        for (var index = 0; index < 101; index++)
          _structuredReviewIssue(
            logicalKey: 'double-stale-corrective-high-$index',
            severity: MergeReviewSeverity.high,
            createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
          ),
      ];
      final warningReuseIssue = _structuredReviewIssue(
        logicalKey: 'double-stale-corrective-warning-reuse',
        type: MergeReviewIssueType.lowConfidenceReuse,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final trackedHighIssue = highIssues.last;
      final repository = _ControlledReviewIssueRepository([
        ...highIssues,
        warningReuseIssue,
      ]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: trackedHighIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: warningReuseIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);

      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      const allPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_all',
      );
      const onPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      const outsidePresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      final highPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${trackedHighIssue.id}',
      );
      final warningPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
      );
      final highReviewSelectKey = Key(
        'operations_review_issue_select_${trackedHighIssue.id}',
      );
      final warningReviewSelectKey = Key(
        'operations_review_issue_select_${warningReuseIssue.id}',
      );

      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsNothing,
      );

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 100);
      expect(
        repository.pendingReviewQueries[0].query.filter,
        MergeReviewFilter.all,
      );
      repository.completeReviewQueryWithPage(
        0,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(
        repository.pendingReviewQueries[1].query.filter,
        MergeReviewFilter.all,
      );
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(
        repository.pendingReviewQueries[2].query.filter,
        const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, false, false],
      );

      repository.failReviewQuery(2, message: 'LATEST_CORRECTIVE_RACE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_error'),
      );
      expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
      expect(
        find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
        findsOneWidget,
      );
      expect(find.textContaining('STALE_CORRECTIVE_FAILURE'), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
      );
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
      }
      for (final key in [highPresenceKey, warningPresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.text('Loaded review page comparison unavailable'),
          ),
          findsOneWidget,
        );
      }
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, false, true],
      );
      final readsAfterLatestFailure = repository.operationsReadCounts;
      final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

      repository.failReviewQuery(1, message: 'STALE_CORRECTIVE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_error'),
      );
      expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
      expect(
        find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
        findsOneWidget,
      );
      expect(find.textContaining('STALE_CORRECTIVE_FAILURE'), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
      );
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
      }
      await _scrollToReviewControl(tester, highPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(highPresenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, warningPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(warningPresenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.operationsReadCounts, readsAfterLatestFailure);
      expect(
        repository.pendingReviewQueries.every(
          (pending) => pending.completer.isCompleted,
        ),
        isTrue,
      );

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_retry'),
      );
      await tester.tap(find.byKey(const Key('operations_review_retry')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(
        repository.pendingReviewQueries[3].query.filter,
        const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(
        find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
        findsNothing,
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_loading'),
        settle: false,
      );
      expect(
        find.byKey(const Key('operations_review_loading')),
        findsOneWidget,
      );
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
        settle: false,
      );
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      await _scrollToReviewControl(tester, warningReviewSelectKey);
      expect(find.byKey(warningReviewSelectKey), findsOneWidget);
      expect(find.byKey(highReviewSelectKey), findsNothing);
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(
          tester.widget<ChoiceChip>(find.byKey(key)).onSelected,
          isNotNull,
        );
      }
      await _scrollToReviewControl(tester, highPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(highPresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, warningPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(warningPresenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots on loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
        findsNothing,
      );
      expect(
        repository.pendingReviewQueries.every(
          (pending) => pending.completer.isCompleted,
        ),
        isTrue,
      );
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 100, filter: MergeReviewFilter.all),
          (offset: 0, filter: MergeReviewFilter.all),
          (
            offset: 0,
            filter: const MergeReviewFilter(
              severity: MergeReviewSeverity.warning,
            ),
          ),
          (
            offset: 0,
            filter: const MergeReviewFilter(
              severity: MergeReviewSeverity.warning,
            ),
          ),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'stale primary skips a corrective second query after newer success',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(
        _backlogReviewIssues(),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 100);
      expect(
        repository.pendingReviewQueries[0].query.filter,
        MergeReviewFilter.all,
      );

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(
        repository.pendingReviewQueries[1].query.filter,
        const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );
      repository.completeReviewQuery(1);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      const warningReviewSelectKey = Key(
        'operations_review_issue_select_backlog-target',
      );
      await _scrollToReviewControl(tester, warningReviewSelectKey);
      expect(find.byKey(warningReviewSelectKey), findsOneWidget);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      final readsAfterLatestSuccess = repository.operationsReadCounts;
      final metaWritesAfterLatestSuccess = repository.appMetaWrites.length;

      repository.completeReviewQueryWithPage(
        0,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 100, filter: MergeReviewFilter.all),
          (
            offset: 0,
            filter: const MergeReviewFilter(
              severity: MergeReviewSeverity.warning,
            ),
          ),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      await _scrollToReviewControl(tester, warningReviewSelectKey);
      expect(find.byKey(warningReviewSelectKey), findsOneWidget);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.operationsReadCounts, readsAfterLatestSuccess);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestSuccess));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'disposed review page skips corrective query after held primary completes',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(
        _backlogReviewIssues(),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries.single.query.offset, 100);
      expect(repository.pendingReviewQueries.single.query.limit, 100);
      expect(
        repository.pendingReviewQueries.single.query.filter,
        MergeReviewFilter.all,
      );
      expect(
        repository.pendingReviewQueries.single.completer.isCompleted,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(OperationsPage), findsNothing);
      expect(tester.takeException(), isNull);

      repository.completeReviewQueryWithPage(
        0,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(OperationsPage), findsNothing);
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(
        repository.pendingReviewQueries.single.completer.isCompleted,
        isTrue,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [(offset: 100, filter: MergeReviewFilter.all)],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'disposed review page ignores an already-dispatched corrective failure',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(
        _backlogReviewIssues(),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries.single.query.offset, 100);
      expect(
        repository.pendingReviewQueries.single.query.filter,
        MergeReviewFilter.all,
      );
      expect(
        repository.pendingReviewQueries.single.completer.isCompleted,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      repository.completeReviewQueryWithPage(
        0,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(
        repository.pendingReviewQueries[1].query.filter,
        MergeReviewFilter.all,
      );
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(OperationsPage), findsNothing);
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

      repository.failReviewQuery(1, message: 'DISPOSED_CORRECTIVE_FAILURE');
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(OperationsPage), findsNothing);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true],
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 100, filter: MergeReviewFilter.all),
          (offset: 0, filter: MergeReviewFilter.all),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'disposed review page ignores an already-dispatched corrective success',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(
        _backlogReviewIssues(),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries.single.query.offset, 100);
      expect(
        repository.pendingReviewQueries.single.query.filter,
        MergeReviewFilter.all,
      );
      expect(
        repository.pendingReviewQueries.single.completer.isCompleted,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      repository.completeReviewQueryWithPage(
        0,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(
        repository.pendingReviewQueries[1].query.filter,
        MergeReviewFilter.all,
      );
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(OperationsPage), findsNothing);
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(OperationsPage), findsNothing);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true],
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 100, filter: MergeReviewFilter.all),
          (offset: 0, filter: MergeReviewFilter.all),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('latest review failure survives a stale corrective success', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, false],
    );

    repository.failReviewQuery(2, message: 'LATEST_CORRECTIVE_RACE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(
      find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
      findsOneWidget,
    );
    expect(find.textContaining('STALE_CORRECTIVE_SUCCESS'), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true],
    );
    final readsAfterLatestFailure = repository.operationsReadCounts;
    final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

    repository.completeReviewQuery(1);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(
      find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
      findsOneWidget,
    );
    expect(find.textContaining('STALE_CORRECTIVE_SUCCESS'), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestFailure);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_retry'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(
      repository.pendingReviewQueries[3].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('stale corrective success cannot replace an active retry', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, false],
    );

    repository.failReviewQuery(2, message: 'LATEST_CORRECTIVE_RACE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(
      find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true],
    );
    final readsAfterLatestFailure = repository.operationsReadCounts;
    final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_retry'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(
      repository.pendingReviewQueries[3].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true, false],
    );

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, false],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestFailure);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('stale corrective failure cannot replace an active retry', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, false],
    );

    repository.failReviewQuery(2, message: 'LATEST_CORRECTIVE_RACE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(
      find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true],
    );
    final readsAfterLatestFailure = repository.operationsReadCounts;
    final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_retry'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(
      repository.pendingReviewQueries[3].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true, false],
    );

    repository.failReviewQuery(1, message: 'STALE_CORRECTIVE_FAILURE');
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );
    expect(find.textContaining('STALE_CORRECTIVE_FAILURE'), findsNothing);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, false],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestFailure);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('stale corrective failure stays isolated after retry success', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, false],
    );

    repository.failReviewQuery(2, message: 'LATEST_CORRECTIVE_RACE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(
      find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true],
    );
    final readsAfterLatestFailure = repository.operationsReadCounts;
    final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_retry'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(
      repository.pendingReviewQueries[3].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true, false],
    );

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
    final readsAfterRetrySuccess = repository.operationsReadCounts;
    final metaWritesAfterRetrySuccess = repository.appMetaWrites.length;

    repository.failReviewQuery(1, message: 'STALE_CORRECTIVE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('STALE_CORRECTIVE_FAILURE'), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestFailure);
    expect(repository.operationsReadCounts, readsAfterRetrySuccess);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
    expect(repository.appMetaWrites, hasLength(metaWritesAfterRetrySuccess));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('stale corrective success stays isolated after retry success', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, false],
    );

    repository.failReviewQuery(2, message: 'LATEST_CORRECTIVE_RACE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(
      find.textContaining('LATEST_CORRECTIVE_RACE_FAILURE'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true],
    );
    final readsAfterLatestFailure = repository.operationsReadCounts;
    final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_retry'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(
      repository.pendingReviewQueries[3].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_filter_count'),
      settle: false,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('operations_review_filter_count')))
          .data,
      'Loading review issues...',
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, false, true, false],
    );

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
    final readsAfterRetrySuccess = repository.operationsReadCounts;
    final metaWritesAfterRetrySuccess = repository.appMetaWrites.length;

    repository.completeReviewQuery(1);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('STALE_CORRECTIVE_SUCCESS'), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-0')),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 4));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterLatestFailure);
    expect(repository.operationsReadCounts, readsAfterRetrySuccess);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
    expect(repository.appMetaWrites, hasLength(metaWritesAfterRetrySuccess));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('toolbar refresh owns page over a stale corrective failure', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await tester.tap(find.byTooltip('Refresh operations data'));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 100);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

    repository.completeReviewQuery(2);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 101-102 of 102 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-100')),
      findsNothing,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    final readsAfterRefresh = repository.operationsReadCounts;
    final metaWritesAfterRefresh = repository.appMetaWrites.length;

    repository.failReviewQuery(1, message: 'STALE_TOOLBAR_CORRECTIVE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('STALE_TOOLBAR_CORRECTIVE_FAILURE'),
      findsNothing,
    );
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 101-102 of 102 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(
      find.byKey(const Key('operations_review_issue_select_recent-high-100')),
      findsNothing,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 3));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (offset: 100, filter: MergeReviewFilter.all),
      ],
    );
    expect(repository.operationsReadCounts, readsAfterRefresh);
    expect(repository.operationsReadCounts.jobs, baselineReads.jobs + 1);
    expect(
      repository.operationsReadCounts.artifacts,
      baselineReads.artifacts + 2,
    );
    expect(repository.operationsReadCounts.logs, baselineReads.logs + 1);
    expect(repository.operationsReadCounts.exports, baselineReads.exports + 1);
    expect(
      repository.operationsReadCounts.governance,
      baselineReads.governance + 1,
    );
    expect(repository.appMetaWrites, hasLength(metaWritesAfterRefresh));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'clearing review filters owns page over a stale corrective success',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(
        _backlogReviewIssues(),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, highFilter);
      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 100);
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      repository.completeReviewQueryWithPage(
        1,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

      const clearFilterKey = Key('operations_review_filter_clear');
      await _scrollToReviewControl(tester, clearFilterKey, settle: false);
      expect(
        tester.widget<TextButton>(find.byKey(clearFilterKey)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(clearFilterKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(
        repository.pendingReviewQueries[3].query.filter,
        MergeReviewFilter.all,
      );
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 102 matching review issues (102 total)',
      );
      expect(find.text('All severities'), findsOneWidget);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      final readsAfterClear = repository.operationsReadCounts;
      final metaWritesAfterClear = repository.appMetaWrites.length;

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 102 matching review issues (102 total)',
      );
      expect(find.text('All severities'), findsOneWidget);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 4));
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 100, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: MergeReviewFilter.all),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.operationsReadCounts, readsAfterClear);
      expect(repository.appMetaWrites, hasLength(metaWritesAfterClear));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('saved view owns page over a stale corrective failure', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    final savedView = _savedReviewView(
      id: 'saved-warning-corrective',
      name: 'Warning saved',
      filter: const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([savedView]),
    );
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 100);
    expect(
      repository.pendingReviewQueries[0].query.filter,
      MergeReviewFilter.all,
    );
    repository.completeReviewQueryWithPage(
      0,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(
      repository.pendingReviewQueries[1].query.filter,
      MergeReviewFilter.all,
    );
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    final savedViewKey = const Key(
      'operations_review_saved_view_saved-warning-corrective',
    );
    await _scrollToReviewControl(tester, savedViewKey, settle: false);
    await tester.tap(find.byKey(savedViewKey));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(severity: MergeReviewSeverity.warning),
    );
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);

    repository.completeReviewQuery(2);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(tester.widget<InputChip>(find.byKey(savedViewKey)).selected, isTrue);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    final readsAfterSavedView = repository.operationsReadCounts;
    final metaWritesAfterSavedView = repository.appMetaWrites.length;

    repository.failReviewQuery(
      1,
      message: 'STALE_SAVED_VIEW_CORRECTIVE_FAILURE',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('STALE_SAVED_VIEW_CORRECTIVE_FAILURE'),
      findsNothing,
    );
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(find.byKey(const Key('operations_review_retry')), findsNothing);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    await _expectReviewTextVisible(tester, 'BACKLOG_TARGET');
    expect(tester.widget<InputChip>(find.byKey(savedViewKey)).selected, isTrue);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true],
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 3));
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 100, filter: MergeReviewFilter.all),
        (offset: 0, filter: MergeReviewFilter.all),
        (
          offset: 0,
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        ),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterSavedView);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterSavedView));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      ['merge_review_filter_v1'],
    );
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'reapplying a saved view owns page over a stale corrective failure',
    (tester) async {
      final repository = _ControlledReviewIssueRepository(
        _backlogReviewIssues(),
      );
      final savedView = _savedReviewView(
        id: 'saved-high-reapply',
        name: 'High saved',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.high),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-reapply',
      );

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      await tester.tap(find.byKey(savedViewKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, highFilter);
      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 100);
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      repository.completeReviewQueryWithPage(
        1,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      await tester.tap(find.byKey(savedViewKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      final readsAfterReapply = repository.operationsReadCounts;
      final metaWritesAfterReapply = repository.appMetaWrites.length;

      repository.failReviewQuery(
        2,
        message: 'STALE_SAVED_VIEW_REAPPLY_CORRECTIVE_FAILURE',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('STALE_SAVED_VIEW_REAPPLY_CORRECTIVE_FAILURE'),
        findsNothing,
      );
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 4));
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 100, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.operationsReadCounts, readsAfterReapply);
      expect(repository.appMetaWrites, hasLength(metaWritesAfterReapply));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('deleting a saved view preserves current corrective ownership', (
    tester,
  ) async {
    final repository = _ControlledReviewIssueRepository(_backlogReviewIssues());
    final savedView = _savedReviewView(
      id: 'saved-high-delete',
      name: 'High delete',
      filter: const MergeReviewFilter(severity: MergeReviewSeverity.high),
    );
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([savedView]),
    );
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineMetaWrites = repository.appMetaWrites.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    final savedViewKey = const Key(
      'operations_review_saved_view_saved-high-delete',
    );

    repository.holdReviewQueries = true;
    await _scrollToReviewControl(tester, savedViewKey, settle: false);
    await tester.tap(find.byKey(savedViewKey));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 0);
    expect(repository.pendingReviewQueries[0].query.filter, highFilter);
    repository.completeReviewQuery(0);
    await tester.pumpAndSettle();

    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(tester.widget<InputChip>(find.byKey(savedViewKey)).selected, isTrue);

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_page_next'),
      settle: false,
    );
    await tester.tap(find.byKey(const Key('operations_review_page_next')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 100);
    expect(repository.pendingReviewQueries[1].query.filter, highFilter);
    repository.completeReviewQueryWithPage(
      1,
      const MergeReviewIssuePage(
        items: [],
        totalCount: 1,
        matchingCount: 1,
        offset: 100,
        limit: 100,
      ),
    );
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(repository.pendingReviewQueries[2].query.filter, highFilter);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

    final deleteFinder = find.byTooltip(
      'Delete saved review view ${savedView.name}',
    );
    await tester.scrollUntilVisible(
      deleteFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(deleteFinder),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(deleteFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(savedViewKey), findsNothing);
    expect(
      MergeReviewSavedViewCodec.decode(
        await repository.getAppMeta(MergeReviewSavedViewStore.metaKey),
      ),
      isEmpty,
    );
    expect(repository.queries, hasLength(baselineReviewQueries + 3));
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_loading'),
      settle: false,
    );
    expect(find.byKey(const Key('operations_review_loading')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('operations_review_severity_filter')),
        matching: find.text('High'),
      ),
      findsOneWidget,
    );

    final readsAfterDelete = repository.operationsReadCounts;
    final metaWritesAfterDelete = repository.appMetaWrites.length;
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterDelete);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
    );
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );

    repository.failReviewQuery(
      2,
      message: 'OWNED_SAVED_VIEW_DELETE_CORRECTIVE_FAILURE',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(
      find.textContaining('OWNED_SAVED_VIEW_DELETE_CORRECTIVE_FAILURE'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
    expect(find.byKey(const Key('operations_review_loading')), findsNothing);
    await _expectReviewCount(
      tester,
      'Review results unavailable for the selected filters',
    );
    expect(find.byKey(savedViewKey), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('operations_review_severity_filter')),
        matching: find.text('High'),
      ),
      findsOneWidget,
    );
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true],
    );
    expect(
      repository.queries
          .skip(baselineReviewQueries)
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 100, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.operationsReadCounts, readsAfterDelete);
    expect(repository.appMetaWrites, hasLength(metaWritesAfterDelete));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'saved-view deletion failure preserves identity during current corrective',
    (tester) async {
      final repository = _ControlledSavedViewMutationRepository(
        _backlogReviewIssues(),
      );
      final savedView = _savedReviewView(
        id: 'saved-high-delete-failure',
        name: 'High delete failure',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.high),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-delete-failure',
      );

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      await tester.tap(find.byKey(savedViewKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, highFilter);
      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 100);
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      repository.completeReviewQueryWithPage(
        1,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

      repository.failSavedViewWrites = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.savedViewWriteAttempts, 1);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(
        MergeReviewSavedViewCodec.decode(
          await repository.getAppMeta(MergeReviewSavedViewStore.metaKey),
        ),
        [savedView],
      );
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(
        find.textContaining('Could not delete saved review view'),
        findsOneWidget,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 3));
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );

      repository.failReviewQuery(
        2,
        message: 'OWNED_SAVED_VIEW_DELETE_FAILURE_CORRECTIVE_FAILURE',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(
        find.textContaining(
          'OWNED_SAVED_VIEW_DELETE_FAILURE_CORRECTIVE_FAILURE',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Review results unavailable for the selected filters',
      );
      await _scrollToReviewControl(tester, savedViewKey);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('operations_review_severity_filter')),
          matching: find.text('High'),
        ),
        findsOneWidget,
      );
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true],
      );
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 100, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view metadata read failure preserves identity during current corrective',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      final savedView = _savedReviewView(
        id: 'saved-high-read-failure',
        name: 'High read failure',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.high),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-read-failure',
      );

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      await tester.tap(find.byKey(savedViewKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, highFilter);
      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 100);
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      repository.completeReviewQueryWithPage(
        1,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

      repository.failSavedViewReads = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.savedViewReadAttempts, 1);
      repository.failSavedViewReads = false;
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(
        MergeReviewSavedViewCodec.decode(
          await repository.getAppMeta(MergeReviewSavedViewStore.metaKey),
        ),
        [savedView],
      );
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(
        find.textContaining('Could not delete saved review view'),
        findsOneWidget,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 3));
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );

      repository.failReviewQuery(
        2,
        message: 'OWNED_SAVED_VIEW_READ_FAILURE_CORRECTIVE_FAILURE',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(
        find.textContaining('OWNED_SAVED_VIEW_READ_FAILURE_CORRECTIVE_FAILURE'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Review results unavailable for the selected filters',
      );
      await _scrollToReviewControl(tester, savedViewKey);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('operations_review_severity_filter')),
          matching: find.text('High'),
        ),
        findsOneWidget,
      );
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true],
      );
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 100, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view initial metadata read failure fails open without blocking review',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      final savedView = _savedReviewView(
        id: 'saved-high-initial-read-failure',
        name: 'High initial read failure',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;
      repository.failSavedViewReads = true;

      await _pumpOperationsPage(tester, repository);

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewReadCallCount, 1);
      expect(repository.queries, hasLength(1));
      expect(repository.queries.single.offset, 0);
      expect(repository.queries.single.filter, highFilter);
      expect(
        find.byKey(
          const Key(
            'operations_review_saved_view_saved-high-initial-read-failure',
          ),
        ),
        findsNothing,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsOneWidget,
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.operationsReadCounts, (
        jobs: 1,
        artifacts: 2,
        logs: 1,
        exports: 1,
        governance: 1,
      ));
    },
  );

  testWidgets(
    'transient initial saved-view metadata read failure recovers on reconstruction',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      final savedView = _savedReviewView(
        id: 'saved-high-transient-recovery',
        name: 'High transient recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;
      repository.failSavedViewReads = true;

      await _pumpOperationsPage(tester, repository);

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.queries, hasLength(1));
      expect(repository.queries.single.offset, 0);
      expect(repository.queries.single.filter, highFilter);
      expect(
        find.byKey(
          const Key(
            'operations_review_saved_view_saved-high-transient-recovery',
          ),
        ),
        findsNothing,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsOneWidget,
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.operationsReadCounts, (
        jobs: 1,
        artifacts: 2,
        logs: 1,
        exports: 1,
        governance: 1,
      ));

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpOperationsPage(tester, repository);

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.queries, hasLength(2));
      for (final query in repository.queries) {
        expect(query.offset, 0);
        expect(query.filter, highFilter);
      }
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_saved-high-transient-recovery'),
      );
      expect(
        find.byKey(
          const Key(
            'operations_review_saved_view_saved-high-transient-recovery',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.operationsReadCounts, (
        jobs: 2,
        artifacts: 4,
        logs: 2,
        exports: 2,
        governance: 2,
      ));
    },
  );

  testWidgets(
    'transient saved-view read recovery isolates a disposed in-flight review request',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      final savedView = _savedReviewView(
        id: 'saved-high-inflight-recovery',
        name: 'High in-flight recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-inflight-recovery',
      );
      await _scrollToReviewControl(tester, savedViewKey);
      expect(find.byKey(savedViewKey), findsOneWidget);

      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries.single.query.offset, 100);
      expect(repository.pendingReviewQueries.single.query.filter, highFilter);
      expect(
        repository.pendingReviewQueries.single.completer.isCompleted,
        isFalse,
      );

      repository.failSavedViewReads = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(OperationsPage), findsOneWidget);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);

      repository.completeReviewQuery(0);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 100, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view read recovery isolates a disposed filter-mutation request',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-filter-recovery',
        name: 'High filter recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-filter-recovery',
      );

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isFalse);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));

      repository.failSavedViewReads = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(0);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view read recovery observes a completed filter write after disposal',
    (tester) async {
      final repository = _ControlledFilterWriteSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-filter-write-recovery',
        name: 'High filter write recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-filter-write-recovery',
      );

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites.single.value,
        warningFilter.encode(),
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(0);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view read recovery isolates a disposed filter retry request',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-filter-retry-recovery',
        name: 'High filter retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-filter-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'FILTER_MUTATION_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.textContaining('FILTER_MUTATION_FAILURE'), findsOneWidget);
      expect(find.byKey(retryKey), findsOneWidget);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'toolbar refresh owns a saved-view read recovery over a disposed retry',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-toolbar-retry-recovery',
        name: 'High toolbar retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-toolbar-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'TOOLBAR_FILTER_MUTATION_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(
        find.textContaining('TOOLBAR_FILTER_MUTATION_FAILURE'),
        findsOneWidget,
      );
      expect(find.byKey(retryKey), findsOneWidget);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      final readsBeforeToolbarRefresh = repository.operationsReadCounts;
      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(
        repository.operationsReadCounts.jobs,
        readsBeforeToolbarRefresh.jobs + 1,
      );
      expect(
        repository.operationsReadCounts.artifacts,
        readsBeforeToolbarRefresh.artifacts + 2,
      );
      expect(
        repository.operationsReadCounts.logs,
        readsBeforeToolbarRefresh.logs + 1,
      );
      expect(
        repository.operationsReadCounts.exports,
        readsBeforeToolbarRefresh.exports + 1,
      );
      expect(
        repository.operationsReadCounts.governance,
        readsBeforeToolbarRefresh.governance + 1,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.offset, 0);
      expect(repository.pendingReviewQueries[4].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 3,
        artifacts: baselineReads.artifacts + 6,
        logs: baselineReads.logs + 3,
        exports: baselineReads.exports + 3,
        governance: baselineReads.governance + 3,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view deletion failure preserves identity across retry recovery',
    (tester) async {
      final repository = _ControlledSavedViewMutationReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-delete-retry-recovery',
        name: 'High delete retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-delete-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'DELETE_RETRY_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(
        find.textContaining('Could not delete saved review view'),
        findsOneWidget,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view deletion success preserves absence across retry recovery',
    (tester) async {
      final repository = _ControlledSavedViewMutationReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-delete-success-retry-recovery',
        name: 'High delete success retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-delete-success-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'DELETE_SUCCESS_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 0);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 0);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view apply success preserves ownership across retry recovery',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-apply-success-retry-recovery',
        name: 'High apply success retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-apply-success-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'APPLY_SUCCESS_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      await tester.tap(find.byKey(savedViewKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.offset, 0);
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view apply failure preserves persisted filter across retry recovery',
    (tester) async {
      final repository =
          _ControlledFilterWriteFailureSavedViewReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-apply-failure-retry-recovery',
        name: 'High apply failure retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-apply-failure-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'APPLY_FAILURE_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failReviewFilterWrites = true;
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      await tester.tap(find.byKey(savedViewKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(repository.appMetaWrites.last.value, warningFilter.encode());
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isTrue,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failReviewFilterWrites = false;
      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.offset, 0);
      expect(repository.pendingReviewQueries[4].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view save success preserves identity across retry recovery',
    (tester) async {
      final repository = _ControlledSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-save-success-retry-recovery',
        name: 'High save success retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'SAVE_SUCCESS_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        'Warning saved during retry',
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
      );
      final savedViewsAfterSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      final savedDuringRetry = savedViewsAfterSave.singleWhere(
        (view) => view.name == 'Warning saved during retry',
      );
      final savedDuringRetryKey = Key(
        'operations_review_saved_view_${savedDuringRetry.id}',
      );
      expect(savedDuringRetry.filter, warningFilter);
      await _scrollToReviewControl(tester, savedDuringRetryKey, settle: false);
      expect(find.byKey(savedDuringRetryKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedDuringRetryKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedDuringRetryKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedDuringRetryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedDuringRetryKey, settle: false);
      expect(find.byKey(savedDuringRetryKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedDuringRetryKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedDuringRetryKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedDuringRetryKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedDuringRetryKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedDuringRetryKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view save failure preserves identity across retry recovery',
    (tester) async {
      final repository = _ControlledSavedViewMutationReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-save-failure-retry-recovery',
        name: 'High save failure retry recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-save-failure-retry-recovery',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'SAVE_FAILURE_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        'Warning saved during failed retry',
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(repository.appMetaWrites.last.value, warningFilter.encode());
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(find.text('Warning saved during failed retry'), findsNothing);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewWrites = false;
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view save failure keeps successful reconstruction identity',
    (tester) async {
      final repository = _ControlledSavedViewMutationReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-save-failure-success-read',
        name: 'High save failure success read',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-save-failure-success-read',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      repository.failReviewQuery(0, message: 'SAVE_FAILURE_SUCCESS_READ');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        'Warning save failure success read',
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 0);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(find.text('Warning save failure success read'), findsNothing);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 0);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 0);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 1,
        artifacts: baselineReads.artifacts + 2,
        logs: baselineReads.logs + 1,
        exports: baselineReads.exports + 1,
        governance: baselineReads.governance + 1,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('disposed saved-view save completes before read recovery', (
    tester,
  ) async {
    final repository = _ControlledSavedViewWriteSavedViewReadFailureRepository(
      _backlogReviewIssues(),
    );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final savedView = _savedReviewView(
      id: 'saved-high-disposed-save-recovery',
      name: 'High disposed save recovery',
      filter: highFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([savedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final savedViewKey = const Key(
      'operations_review_saved_view_saved-high-disposed-save-recovery',
    );
    const retryKey = Key('operations_review_retry');

    repository.holdReviewQueries = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 0);
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    repository.failReviewQuery(0, message: 'DISPOSED_SAVE_FILTER_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);

    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.holdSavedViewWrites = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      'Warning disposed save recovery',
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingSavedViewWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      ['merge_review_filter_v1'],
    );
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(find.text('Warning disposed save recovery'), findsNothing);
    await _scrollToReviewControl(tester, savedViewKey, settle: false);
    expect(find.byKey(savedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
      isFalse,
    );
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository.completeSavedViewWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
    );
    final persistedViews = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    final disposedSavedView = persistedViews.singleWhere(
      (view) => view.name == 'Warning disposed save recovery',
    );
    final disposedSavedViewKey = Key(
      'operations_review_saved_view_${disposedSavedView.id}',
    );
    expect(disposedSavedView.filter, warningFilter);

    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
    expect(find.byKey(disposedSavedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(find.byKey(disposedSavedViewKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
    await _scrollToReviewControl(tester, disposedSavedViewKey, settle: false);
    expect(find.byKey(disposedSavedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(disposedSavedViewKey)).selected,
      isFalse,
    );
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(disposedSavedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(disposedSavedViewKey)).selected,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    expect(find.byKey(disposedSavedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(disposedSavedViewKey)).selected,
      isFalse,
    );
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingSavedViewWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('saved-view deletion waits for a pending save before recovery', (
    tester,
  ) async {
    final repository = _ControlledSavedViewWriteSavedViewReadFailureRepository(
      _backlogReviewIssues(),
    );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final savedView = _savedReviewView(
      id: 'saved-high-pending-save-delete',
      name: 'High pending save delete',
      filter: highFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([savedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final savedViewKey = const Key(
      'operations_review_saved_view_saved-high-pending-save-delete',
    );
    const retryKey = Key('operations_review_retry');

    repository.holdReviewQueries = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 0);
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    repository.failReviewQuery(0, message: 'PENDING_SAVE_DELETE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);

    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.holdSavedViewWrites = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      'Warning pending save then delete',
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingSavedViewWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(find.text('Warning pending save then delete'), findsNothing);
    final deleteFinder = find.byTooltip(
      'Delete saved review view ${savedView.name}',
    );
    expect(deleteFinder, findsNothing);
    expect(find.byKey(savedViewKey), findsOneWidget);
    await _expectReviewLoading(tester);

    repository.completeSavedViewWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingSavedViewWrites[0].completer.isCompleted, isTrue);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    final savedAfterCompletion = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    final newSavedView = savedAfterCompletion.singleWhere(
      (view) => view.name == 'Warning pending save then delete',
    );
    final newSavedViewKey = Key(
      'operations_review_saved_view_${newSavedView.id}',
    );
    expect(newSavedView.filter, warningFilter);
    await _scrollToReviewControl(tester, savedViewKey, settle: false);
    expect(find.byKey(savedViewKey), findsOneWidget);
    await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    expect(
      find.byTooltip('Delete saved review view ${savedView.name}'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Delete saved review view ${savedView.name}'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final oldDeleteFinder = find.byTooltip(
      'Delete saved review view ${savedView.name}',
    );
    await Scrollable.ensureVisible(
      tester.element(oldDeleteFinder),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(oldDeleteFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      [
        'merge_review_filter_v1',
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewStore.metaKey,
      ],
    );
    final savedAfterDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(savedAfterDelete, [newSavedView]);
    expect(find.byKey(savedViewKey), findsNothing);
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
    expect(find.byKey(savedViewKey), findsNothing);
    expect(find.byKey(newSavedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(find.byKey(savedViewKey), findsNothing);
    expect(find.byKey(newSavedViewKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
    await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    expect(find.byKey(savedViewKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
      isFalse,
    );
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    expect(find.byKey(savedViewKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    expect(find.byKey(savedViewKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
      isFalse,
    );
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingSavedViewWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'saved-view deletion remains independent while filter write is pending',
    (tester) async {
      final repository = _ControlledFilterWriteSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-delete',
        name: 'High pending filter delete',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-delete',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites.single.value,
        warningFilter.encode(),
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

      repository.failReviewQuery(0, message: 'PENDING_FILTER_DELETE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [MergeReviewSavedViewStore.metaKey, 'merge_review_filter_v1'],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(
        MergeReviewSavedViewCodec.decode(
          repository.appMetaWrites
              .where((write) => write.key == MergeReviewSavedViewStore.metaKey)
              .last
              .value,
        ),
        isEmpty,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view apply queues behind a pending filter write and owns recovery',
    (tester) async {
      final repository = _ControlledFilterWriteSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final highSavedView = _savedReviewView(
        id: 'saved-high-pending-filter-apply',
        name: 'High pending filter apply',
        filter: highFilter,
      );
      final warningSavedView = _savedReviewView(
        id: 'saved-warning-pending-filter-apply',
        name: 'Warning pending filter apply',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([highSavedView, warningSavedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final highSavedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-apply',
      );
      final warningSavedViewKey = const Key(
        'operations_review_saved_view_saved-warning-pending-filter-apply',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'PENDING_FILTER_APPLY_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
      await tester.tap(find.byKey(highSavedViewKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isTrue,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failReviewQuery(
        1,
        message: 'STALE_PENDING_FILTER_APPLY_RETRY_FAILURE',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isTrue,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => MergeReviewFilter.decode(write.value))
            .toList(growable: false),
        [warningFilter, highFilter],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isTrue,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(warningSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.offset, 0);
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view save remains independent while filter write is pending',
    (tester) async {
      final repository = _ControlledFilterWriteSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-save',
        name: 'High pending filter save',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-save',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning pending filter save';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'PENDING_FILTER_SAVE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      final savedAfterSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterSave, hasLength(2));
      final newSavedView = savedAfterSave.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [MergeReviewSavedViewStore.metaKey, 'merge_review_filter_v1'],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('saved-view save failure leaves a pending filter write intact', (
    tester,
  ) async {
    final repository =
        _ControlledFilterWriteSavedViewMutationReadFailureRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final savedView = _savedReviewView(
      id: 'saved-high-pending-filter-save-failure',
      name: 'High pending filter save failure',
      filter: highFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([savedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final savedViewKey = const Key(
      'operations_review_saved_view_saved-high-pending-filter-save-failure',
    );
    const retryKey = Key('operations_review_retry');
    const newSavedViewName = 'Warning pending filter save failure';

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 0);
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    repository.failReviewQuery(0, message: 'PENDING_FILTER_SAVE_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);

    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewWrites = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      newSavedViewName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewWriteAttempts, 1);
    expect(repository.savedViewReadCallCount, 2);
    expect(
      repository.pendingReviewFilterWrites[0].completer.isCompleted,
      isFalse,
    );
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(find.byKey(savedViewKey), findsOneWidget);
    expect(find.byKey(retryKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
      isFalse,
    );
    expect(find.text(newSavedViewName), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewWrites = false;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewFilterWrites[0].completer.isCompleted,
      isTrue,
    );
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.appMetaWrites.last, (
      key: 'merge_review_filter_v1',
      value: warningFilter.encode(),
    ));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      warningFilter,
    );
    expect(find.byKey(savedViewKey), findsOneWidget);
    expect(find.text(newSavedViewName), findsNothing);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
    expect(find.byKey(savedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(find.byKey(savedViewKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
    await _scrollToReviewControl(tester, savedViewKey, settle: false);
    expect(find.byKey(savedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
      isFalse,
    );
    expect(find.text(newSavedViewName), findsNothing);
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(find.byKey(savedViewKey), findsOneWidget);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1 of 1 matching review issues (102 total)',
    );
    expect(find.byKey(savedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
      isFalse,
    );
    expect(find.text(newSavedViewName), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.savedViewWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'saved-view deletion failure leaves a pending filter write intact',
    (tester) async {
      final repository =
          _ControlledFilterWriteSavedViewMutationReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-delete-failure',
        name: 'High pending filter delete failure',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-delete-failure',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'PENDING_FILTER_DELETE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(retryKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(
        find.textContaining('Could not delete saved review view'),
        findsOneWidget,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view save then deletion serialize while filter write is pending',
    (tester) async {
      final repository = _ControlledFilterWriteSavedViewReadFailureRepository(
        _backlogReviewIssues(),
      );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-save-delete',
        name: 'High pending filter save delete',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-save-delete',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning pending filter save delete';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(
        0,
        message: 'PENDING_FILTER_SAVE_DELETE_FAILURE',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      final savedAfterSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterSave, hasLength(2));
      final newSavedView = savedAfterSave.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        [newSavedView],
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          MergeReviewSavedViewStore.metaKey,
          MergeReviewSavedViewStore.metaKey,
          'merge_review_filter_v1',
        ],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view deletion failure preserves prior save with filter write pending',
    (tester) async {
      final repository =
          _ControlledFilterWriteSavedViewMutationReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-save-delete-failure',
        name: 'High pending filter save delete failure',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-save-delete-failure',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning pending filter save delete failure';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(
        0,
        message: 'PENDING_FILTER_SAVE_DELETE_FAILURE',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      final savedAfterSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterSave, hasLength(2));
      final newSavedView = savedAfterSave.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 3);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(
        find.textContaining('Could not delete saved review view'),
        findsOneWidget,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view deletion follows a failed save while filter write is pending',
    (tester) async {
      final repository =
          _ControlledFilterWriteSavedViewMutationReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-failed-save-delete',
        name: 'High pending filter failed save delete',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-failed-save-delete',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning pending filter failed save delete';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'FAILED_SAVE_THEN_DELETE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.text(newSavedViewName), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [MergeReviewSavedViewStore.metaKey, 'merge_review_filter_v1'],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view save failure follows deletion while filter write is pending',
    (tester) async {
      final repository =
          _ControlledFilterWriteSavedViewMutationReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-delete-save-failure',
        name: 'High pending filter delete save failure',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-delete-save-failure',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning pending filter delete save failure';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'DELETE_THEN_SAVE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 3);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [MergeReviewSavedViewStore.metaKey, 'merge_review_filter_v1'],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.text(newSavedViewName), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view second save failure preserves the first while filter write is pending',
    (tester) async {
      final repository =
          _ControlledFilterWriteSavedViewMutationReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-double-save',
        name: 'High pending filter double save',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-double-save',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning pending filter double save';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'PENDING_DOUBLE_SAVE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      final savedAfterFirstSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterFirstSave, hasLength(2));
      final newSavedView = savedAfterFirstSave.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 3);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        savedAfterFirstSave,
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [MergeReviewSavedViewStore.metaKey, 'merge_review_filter_v1'],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'successful saved-view save survives pending filter write failure',
    (tester) async {
      final repository =
          _ControlledFilterWriteFailureAfterSavedViewReadFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-pending-filter-write-failure-after-save',
        name: 'High pending filter write failure after save',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-pending-filter-write-failure-after-save',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName =
          'Warning pending filter write failure after save';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'PENDING_FILTER_WRITE_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      final savedAfterSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterSave, hasLength(2));
      final newSavedView = savedAfterSave.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, warningFilter);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.failReviewFilterWritesAfterRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);
      await _scrollToReviewControl(tester, savedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'filter-write failure recovers while saved-view mutation is queued',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-filter-failure-queued-save',
        name: 'High filter failure queued save',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-filter-failure-queued-save',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning filter failure queued save';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      repository.failReviewQuery(0, message: 'FILTER_FAILURE_QUEUED_SAVE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.holdSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingSavedViewWrites, hasLength(1));
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.text(newSavedViewName), findsNothing);
      await _expectReviewLoading(tester);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      await _expectReviewLoading(tester);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(repository.appMetaWrites.last.value, highFilter.encode());
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeSavedViewWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
      );
      final savedAfterQueueRecovery = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterQueueRecovery, hasLength(2));
      final newSavedView = savedAfterQueueRecovery.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, warningFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.offset, 0);
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(savedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'filter-write failure recovers while saved-view deletion is queued',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final savedView = _savedReviewView(
        id: 'saved-high-filter-failure-queued-delete',
        name: 'High filter failure queued delete',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([savedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final savedViewKey = const Key(
        'operations_review_saved_view_saved-high-filter-failure-queued-delete',
      );
      const retryKey = Key('operations_review_retry');
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${savedView.name}',
      );

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      repository.holdSavedViewWrites = true;
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingSavedViewWrites, hasLength(1));
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(savedViewKey), findsOneWidget);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 0);
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      repository.failReviewQuery(0, message: 'FILTER_FAILURE_QUEUED_DELETE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 0);
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      await _expectReviewLoading(tester);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1'],
      );
      expect(repository.appMetaWrites.last.value, highFilter.encode());
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(find.byKey(savedViewKey), findsOneWidget);
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeSavedViewWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.offset, 0);
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(savedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('queued saved-view apply survives filter-write failure recovery', (
    tester,
  ) async {
    final repository =
        _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final highSavedView = _savedReviewView(
      id: 'saved-high-filter-failure-queued-apply',
      name: 'High filter failure queued apply',
      filter: highFilter,
    );
    final warningSavedView = _savedReviewView(
      id: 'saved-warning-filter-failure-queued-apply',
      name: 'Warning filter failure queued apply',
      filter: warningFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([highSavedView, warningSavedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final highSavedViewKey = const Key(
      'operations_review_saved_view_saved-high-filter-failure-queued-apply',
    );
    final warningSavedViewKey = const Key(
      'operations_review_saved_view_saved-warning-filter-failure-queued-apply',
    );
    const retryKey = Key('operations_review_retry');

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.offset, 0);
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    repository.failReviewQuery(0, message: 'FILTER_FAILURE_QUEUED_APPLY');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);

    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.offset, 0);
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
    await tester.tap(find.byKey(highSavedViewKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.offset, 0);
    expect(repository.pendingReviewQueries[2].query.filter, highFilter);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    expect(
      repository.pendingReviewFilterWrites[0].completer.isCompleted,
      isFalse,
    );
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(
      tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
      isTrue,
    );
    expect(
      tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.failNextReviewFilterWriteOnRelease = true;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      ['merge_review_filter_v1'],
    );
    expect(repository.appMetaWrites.last.value, highFilter.encode());
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(
      tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
      isTrue,
    );
    expect(
      tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
      isFalse,
    );
    final filterWriteError = find.textContaining(
      'Could not save review filters',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(filterWriteError, findsOneWidget);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 2);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.offset, 0);
    expect(repository.pendingReviewQueries[3].query.filter, highFilter);
    expect(find.byKey(highSavedViewKey), findsNothing);
    expect(find.byKey(warningSavedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(5));
    expect(repository.pendingReviewQueries[4].query.offset, 0);
    expect(repository.pendingReviewQueries[4].query.filter, highFilter);
    await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(warningSavedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
      isFalse,
    );
    expect(
      tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
      isFalse,
    );
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(4);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(warningSavedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
      isFalse,
    );
    expect(
      tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
      isFalse,
    );
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'queued saved-view apply survives filter failure during deletion',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final highSavedView = _savedReviewView(
        id: 'saved-high-queued-apply-during-delete',
        name: 'High queued apply during delete',
        filter: highFilter,
      );
      final warningSavedView = _savedReviewView(
        id: 'saved-warning-queued-apply-during-delete',
        name: 'Warning queued apply during delete',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([highSavedView, warningSavedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final highSavedViewKey = const Key(
        'operations_review_saved_view_saved-high-queued-apply-during-delete',
      );
      final warningSavedViewKey = const Key(
        'operations_review_saved_view_saved-warning-queued-apply-during-delete',
      );
      const retryKey = Key('operations_review_retry');
      final warningDeleteFinder = find.byTooltip(
        'Delete saved review view ${warningSavedView.name}',
      );

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      repository.holdSavedViewWrites = true;
      await tester.scrollUntilVisible(
        warningDeleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(warningDeleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingSavedViewWrites, hasLength(1));
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      repository.failReviewQuery(0, message: 'FILTER_FAILURE_DURING_DELETE');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);

      await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
      await tester.tap(find.byKey(highSavedViewKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isTrue,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last.value, highFilter.encode());
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);

      repository.completeSavedViewWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', MergeReviewSavedViewStore.metaKey],
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        [highSavedView],
      );
      await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(warningSavedViewKey), findsNothing);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();
      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isFalse,
      );

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'repeated queued saved-view applies survive filter failure during deletion',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final highSavedView = _savedReviewView(
        id: 'saved-high-repeated-apply-during-delete',
        name: 'High repeated apply during delete',
        filter: highFilter,
      );
      final warningSavedView = _savedReviewView(
        id: 'saved-warning-repeated-apply-during-delete',
        name: 'Warning repeated apply during delete',
        filter: warningFilter,
      );
      final infoSavedView = _savedReviewView(
        id: 'saved-info-repeated-apply-during-delete',
        name: 'Info repeated apply during delete',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.info),
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([
          highSavedView,
          warningSavedView,
          infoSavedView,
        ]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final highSavedViewKey = const Key(
        'operations_review_saved_view_saved-high-repeated-apply-during-delete',
      );
      final warningSavedViewKey = const Key(
        'operations_review_saved_view_saved-warning-repeated-apply-during-delete',
      );
      final infoSavedViewKey = const Key(
        'operations_review_saved_view_saved-info-repeated-apply-during-delete',
      );
      const retryKey = Key('operations_review_retry');
      final infoDeleteFinder = find.byTooltip(
        'Delete saved review view ${infoSavedView.name}',
      );

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      repository.holdSavedViewWrites = true;
      await tester.scrollUntilVisible(
        infoDeleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(infoDeleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingSavedViewWrites, hasLength(1));
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(find.byKey(infoSavedViewKey), findsOneWidget);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      repository.failReviewQuery(0, message: 'REPEATED_APPLY_FILTER_FAILURE');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);

      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);

      await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
      await tester.tap(find.byKey(highSavedViewKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isTrue,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, warningSavedViewKey, settle: false);
      await tester.tap(find.byKey(warningSavedViewKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isTrue,
      );
      expect(find.byKey(infoSavedViewKey), findsOneWidget);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.value)
            .toList(growable: false),
        [highFilter.encode(), warningFilter.encode()],
      );
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isTrue,
      );
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);

      repository.completeSavedViewWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
        ],
      );
      final savedAfterDeletion = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterDeletion, hasLength(2));
      expect(savedAfterDeletion.map((view) => view.id).toSet(), {
        highSavedView.id,
        warningSavedView.id,
      });
      await _scrollToReviewControl(tester, warningSavedViewKey, settle: false);
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(find.byKey(infoSavedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, warningFilter);
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(warningSavedViewKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(6));
      expect(repository.pendingReviewQueries[5].query.filter, warningFilter);
      await _scrollToReviewControl(tester, warningSavedViewKey, settle: false);
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(find.byKey(infoSavedViewKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(warningSavedViewKey)).selected,
        isFalse,
      );

      repository.completeReviewQuery(4);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(5);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(warningSavedViewKey), findsOneWidget);
      expect(find.byKey(infoSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('saved-view mutations recover after filter-write failure', (
    tester,
  ) async {
    final repository =
        _ControlledFilterWriteFailureAfterSavedViewReadFailureRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final highSavedView = _savedReviewView(
      id: 'saved-high-mutations-after-filter-failure',
      name: 'High mutations after filter failure',
      filter: highFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([highSavedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final highSavedViewKey = const Key(
      'operations_review_saved_view_saved-high-mutations-after-filter-failure',
    );
    const retryKey = Key('operations_review_retry');
    const newSavedViewName = 'Warning mutations after filter failure';

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    repository.failReviewQuery(0, message: 'MUTATIONS_FILTER_FAILURE');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);

    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      newSavedViewName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    final savedAfterSave = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(savedAfterSave, hasLength(2));
    final newSavedView = savedAfterSave.singleWhere(
      (view) => view.name == newSavedViewName,
    );
    final newSavedViewKey = Key(
      'operations_review_saved_view_${newSavedView.id}',
    );
    expect(newSavedView.filter, warningFilter);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    expect(
      repository.pendingReviewFilterWrites[0].completer.isCompleted,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.failReviewFilterWritesAfterRelease = true;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(newSavedViewKey), findsOneWidget);
    final filterWriteError = find.textContaining(
      'Could not save review filters',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(filterWriteError, findsOneWidget);

    final deleteFinder = find.byTooltip(
      'Delete saved review view $newSavedViewName',
    );
    await tester.scrollUntilVisible(
      deleteFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(deleteFinder),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(deleteFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(
      MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
      [highSavedView],
    );
    await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(newSavedViewKey), findsNothing);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.filter, highFilter);
    expect(find.byKey(highSavedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.filter, highFilter);
    await _scrollToReviewControl(tester, highSavedViewKey, settle: false);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(newSavedViewKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(newSavedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('repeated saved-view mutations survive filter-write failure', (
    tester,
  ) async {
    final repository =
        _ControlledFilterWriteFailureAfterSavedViewReadFailureRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final highSavedView = _savedReviewView(
      id: 'saved-high-repeated-mutations-after-filter-failure',
      name: 'High repeated mutations after filter failure',
      filter: highFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([highSavedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final highSavedViewKey = const Key(
      'operations_review_saved_view_saved-high-repeated-mutations-after-filter-failure',
    );
    const retryKey = Key('operations_review_retry');
    const preFailureName = 'Warning before filter failure repeated';
    const postFailureFirstName = 'Warning after filter failure first';
    const postFailureSecondName = 'Warning after filter failure second';

    Future<MergeReviewSavedView> saveView(String name) async {
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        name,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final storedViews = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      return storedViews.singleWhere((view) => view.name == name);
    }

    Future<void> deleteView(String name) async {
      final finder = find.byTooltip('Delete saved review view $name');
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    repository.failReviewQuery(0, message: 'REPEATED_MUTATIONS_FILTER_FAILURE');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);
    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    final preFailureView = await saveView(preFailureName);
    final preFailureViewKey = Key(
      'operations_review_saved_view_${preFailureView.id}',
    );
    expect(repository.savedViewReadCallCount, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(preFailureView.filter, warningFilter);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(preFailureViewKey), findsOneWidget);
    expect(
      repository.pendingReviewFilterWrites[0].completer.isCompleted,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.failReviewFilterWritesAfterRelease = true;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    final filterWriteError = find.textContaining(
      'Could not save review filters',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(filterWriteError, findsOneWidget);
    await _expectReviewLoading(tester);

    final postFailureFirstView = await saveView(postFailureFirstName);
    final postFailureFirstKey = Key(
      'operations_review_saved_view_${postFailureFirstView.id}',
    );
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(postFailureFirstView.filter, warningFilter);
    expect(find.byKey(postFailureFirstKey), findsOneWidget);
    await _expectReviewLoading(tester);

    await deleteView(postFailureFirstName);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    final storedAfterFirstDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(storedAfterFirstDelete, hasLength(2));
    expect(
      storedAfterFirstDelete.map((view) => view.id).toList(growable: false),
      containsAll([highSavedView.id, preFailureView.id]),
    );
    await _scrollToReviewControl(tester, preFailureViewKey, settle: false);
    expect(find.byKey(postFailureFirstKey), findsNothing);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(preFailureViewKey), findsOneWidget);
    await _expectReviewLoading(tester);

    final postFailureSecondView = await saveView(postFailureSecondName);
    final postFailureSecondKey = Key(
      'operations_review_saved_view_${postFailureSecondView.id}',
    );
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    expect(postFailureSecondView.filter, warningFilter);
    expect(find.byKey(postFailureSecondKey), findsOneWidget);
    await _expectReviewLoading(tester);

    await deleteView(postFailureSecondName);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
    final storedAfterSecondDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(storedAfterSecondDelete, hasLength(2));
    expect(
      storedAfterSecondDelete.map((view) => view.id).toList(growable: false),
      containsAll([highSavedView.id, preFailureView.id]),
    );
    await _scrollToReviewControl(tester, preFailureViewKey, settle: false);
    expect(find.byKey(postFailureSecondKey), findsNothing);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(preFailureViewKey), findsOneWidget);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 7);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.filter, highFilter);
    expect(find.byKey(highSavedViewKey), findsNothing);
    expect(find.byKey(preFailureViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 8);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.filter, highFilter);
    await _scrollToReviewControl(tester, preFailureViewKey, settle: false);
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(preFailureViewKey), findsOneWidget);
    expect(find.byKey(postFailureFirstKey), findsNothing);
    expect(find.byKey(postFailureSecondKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(highSavedViewKey)).selected,
      isFalse,
    );
    expect(
      tester.widget<InputChip>(find.byKey(preFailureViewKey)).selected,
      isFalse,
    );
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(preFailureViewKey), findsOneWidget);
    expect(find.byKey(postFailureFirstKey), findsNothing);
    expect(find.byKey(postFailureSecondKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 8);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      [
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewStore.metaKey,
      ],
    );
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'saved-view save/delete queue survives filter-write failure recovery',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final highSavedView = _savedReviewView(
        id: 'saved-high-save-delete-filter-recovery',
        name: 'High save delete filter recovery',
        filter: highFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([highSavedView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final highSavedViewKey = const Key(
        'operations_review_saved_view_saved-high-save-delete-filter-recovery',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'Warning save delete filter recovery';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      repository.holdSavedViewWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      repository.failReviewQuery(0, message: 'SAVE_DELETE_FILTER_FAILURE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await _expectReviewError(tester);
      expect(find.byKey(retryKey), findsOneWidget);
      await _scrollToReviewControl(tester, retryKey, settle: false);
      await tester.tap(find.byKey(retryKey));
      await tester.pump();
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.pendingSavedViewWrites, hasLength(1));
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.text(newSavedViewName), findsNothing);
      await _expectReviewLoading(tester);

      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      await _expectReviewLoading(tester);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: highFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);
      await _expectReviewLoading(tester);

      final pendingSavedViews = MergeReviewSavedViewCodec.decode(
        repository.pendingSavedViewWrites[0].value,
      );
      final newSavedView = pendingSavedViews.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(pendingSavedViews, hasLength(2));
      expect(newSavedView.filter, warningFilter);

      repository.completeSavedViewWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(find.byKey(highSavedViewKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);

      final oldDeleteFinder = find.byTooltip(
        'Delete saved review view ${highSavedView.name}',
      );
      await tester.scrollUntilVisible(
        oldDeleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(oldDeleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(oldDeleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
          MergeReviewSavedViewStore.metaKey,
        ],
      );
      final savedAfterDelete = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterDelete, hasLength(1));
      expect(savedAfterDelete.single.id, newSavedView.id);
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(highSavedViewKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('later filter failure isolates a queued saved-view mutation', (
    tester,
  ) async {
    final repository =
        _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final highSavedView = _savedReviewView(
      id: 'saved-high-later-filter-failure',
      name: 'High later filter failure',
      filter: highFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([highSavedView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final highSavedViewKey = const Key(
      'operations_review_saved_view_saved-high-later-filter-failure',
    );
    const retryKey = Key('operations_review_retry');
    const firstSavedViewName = 'Warning first later filter failure';
    const secondSavedViewName = 'Warning second later filter failure';

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    repository.failReviewQuery(0, message: 'LATER_FILTER_FAILURE_FIRST');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await _expectReviewError(tester);
    expect(find.byKey(retryKey), findsOneWidget);
    await _scrollToReviewControl(tester, retryKey, settle: false);
    await tester.tap(find.byKey(retryKey));
    await tester.pump();
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.holdSavedViewWrites = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      firstSavedViewName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingSavedViewWrites, hasLength(1));
    expect(repository.pendingSavedViewWrites[0].completer.isCompleted, isFalse);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.text(firstSavedViewName), findsNothing);
    await _expectReviewLoading(tester);

    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'High',
    );
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.filter, highFilter);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    await _expectReviewLoading(tester);

    repository.failNextReviewFilterWriteOnRelease = true;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    expect(repository.pendingSavedViewWrites[0].completer.isCompleted, isFalse);
    final firstFilterError = find.textContaining(
      'Could not save review filters',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(firstFilterError, findsOneWidget);
    await _expectReviewLoading(tester);

    final firstPendingViews = MergeReviewSavedViewCodec.decode(
      repository.pendingSavedViewWrites[0].value,
    );
    final firstSavedView = firstPendingViews.singleWhere(
      (view) => view.name == firstSavedViewName,
    );
    final firstSavedViewKey = Key(
      'operations_review_saved_view_${firstSavedView.id}',
    );
    expect(firstPendingViews, hasLength(2));
    expect(firstSavedView.filter, warningFilter);

    repository.completeSavedViewWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(find.byKey(highSavedViewKey), findsOneWidget);
    expect(find.byKey(firstSavedViewKey), findsOneWidget);

    final oldDeleteFinder = find.byTooltip(
      'Delete saved review view ${highSavedView.name}',
    );
    await tester.scrollUntilVisible(
      oldDeleteFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(oldDeleteFinder),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(oldDeleteFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    final afterFirstDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(afterFirstDelete, hasLength(1));
    expect(afterFirstDelete.single.id, firstSavedView.id);
    expect(find.byKey(highSavedViewKey), findsNothing);
    expect(find.byKey(firstSavedViewKey), findsOneWidget);
    await _expectReviewLoading(tester);

    repository.holdReviewFilterWrites = true;
    repository.holdSavedViewWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(repository.pendingReviewFilterWrites, hasLength(2));

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      secondSavedViewName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingSavedViewWrites, hasLength(2));
    expect(repository.pendingSavedViewWrites[1].completer.isCompleted, isFalse);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    expect(find.byKey(firstSavedViewKey), findsOneWidget);
    expect(find.text(secondSavedViewName), findsNothing);
    await _expectReviewLoading(tester);

    repository.failNextReviewFilterWriteOnRelease = true;
    repository.completeReviewFilterWrite(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    expect(repository.pendingSavedViewWrites[1].completer.isCompleted, isFalse);
    final secondFilterError = find.textContaining(
      'Could not save review filters',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(secondFilterError, findsOneWidget);
    await _expectReviewLoading(tester);

    final secondPendingViews = MergeReviewSavedViewCodec.decode(
      repository.pendingSavedViewWrites[1].value,
    );
    final secondSavedView = secondPendingViews.singleWhere(
      (view) => view.name == secondSavedViewName,
    );
    final secondSavedViewKey = Key(
      'operations_review_saved_view_${secondSavedView.id}',
    );
    expect(secondPendingViews, hasLength(2));
    expect(secondSavedView.filter, warningFilter);

    repository.completeSavedViewWrite(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.pendingSavedViewWrites[1].completer.isCompleted, isTrue);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    final afterSecondSave = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(afterSecondSave, hasLength(2));
    expect(
      afterSecondSave.map((view) => view.id).toList(growable: false),
      containsAll([firstSavedView.id, secondSavedView.id]),
    );
    expect(find.byKey(firstSavedViewKey), findsOneWidget);
    expect(find.byKey(secondSavedViewKey), findsOneWidget);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(5));
    expect(repository.pendingReviewQueries[4].query.filter, highFilter);
    expect(find.byKey(firstSavedViewKey), findsNothing);
    expect(find.byKey(secondSavedViewKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(1);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(6));
    expect(repository.pendingReviewQueries[5].query.filter, highFilter);
    await _scrollToReviewControl(tester, secondSavedViewKey, settle: false);
    expect(find.byKey(firstSavedViewKey), findsOneWidget);
    expect(find.byKey(secondSavedViewKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(firstSavedViewKey)).selected,
      isFalse,
    );
    expect(
      tester.widget<InputChip>(find.byKey(secondSavedViewKey)).selected,
      isFalse,
    );
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(2);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
    expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(4);
    await tester.pump();
    await tester.pump();
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(5);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(highSavedViewKey), findsNothing);
    expect(find.byKey(firstSavedViewKey), findsOneWidget);
    expect(find.byKey(secondSavedViewKey), findsOneWidget);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'saved-view deletion survives third filter recovery after later failure',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final firstWarningView = _savedReviewView(
        id: 'saved-warning-third-filter-recovery-first',
        name: 'Warning third filter recovery first',
        filter: warningFilter,
      );
      final secondWarningView = _savedReviewView(
        id: 'saved-warning-third-filter-recovery-second',
        name: 'Warning third filter recovery second',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([firstWarningView, secondWarningView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final firstWarningKey = const Key(
        'operations_review_saved_view_saved-warning-third-filter-recovery-first',
      );
      final secondWarningKey = const Key(
        'operations_review_saved_view_saved-warning-third-filter-recovery-second',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(2));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      await _expectReviewLoading(tester);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      final laterFilterError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(laterFilterError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isFalse);
      expect(repository.pendingReviewFilterWrites, hasLength(3));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      await _expectReviewLoading(tester);

      final deleteFinder = find.byTooltip(
        'Delete saved review view ${secondWarningView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites.last.key,
        MergeReviewSavedViewStore.metaKey,
      );
      final afterDelete = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(afterDelete, hasLength(1));
      expect(afterDelete.single.id, firstWarningView.id);
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(
        repository.pendingReviewFilterWrites[2].completer.isCompleted,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(
        repository.pendingReviewFilterWrites[2].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
          'merge_review_filter_v1',
        ],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(firstWarningKey), findsNothing);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, warningFilter);
      await _scrollToReviewControl(tester, firstWarningKey, settle: false);
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(firstWarningKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(0);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'saved-view deletion failure preserves identity across filter recovery',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSavedViewMutationFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final firstWarningView = _savedReviewView(
        id: 'saved-warning-delete-failure-filter-recovery-first',
        name: 'Warning delete failure filter recovery first',
        filter: warningFilter,
      );
      final secondWarningView = _savedReviewView(
        id: 'saved-warning-delete-failure-filter-recovery-second',
        name: 'Warning delete failure filter recovery second',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([firstWarningView, secondWarningView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final firstWarningKey = const Key(
        'operations_review_saved_view_saved-warning-delete-failure-filter-recovery-first',
      );
      final secondWarningKey = const Key(
        'operations_review_saved_view_saved-warning-delete-failure-filter-recovery-second',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[0].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(2));
      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      final laterFilterError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(laterFilterError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(3));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${secondWarningView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsOneWidget);
      final deletionError = find.textContaining(
        'Could not delete saved review view',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(deletionError, findsOneWidget);
      expect(
        repository.pendingReviewFilterWrites[2].completer.isCompleted,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(
        repository.pendingReviewFilterWrites[2].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        ['merge_review_filter_v1', 'merge_review_filter_v1'],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(tester, secondWarningKey, settle: false);
      final retryDeleteFinder = find.byTooltip(
        'Delete saved review view ${secondWarningView.name}',
      );
      await tester.scrollUntilVisible(
        retryDeleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(retryDeleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(retryDeleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
        ],
      );
      final afterRetryDelete = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(afterRetryDelete, hasLength(1));
      expect(afterRetryDelete.single.id, firstWarningView.id);
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(firstWarningKey), findsNothing);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, warningFilter);
      await _scrollToReviewControl(tester, firstWarningKey, settle: false);
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(firstWarningKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(0);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(1);
      await tester.pump();
      await tester.pump();
      repository.completeReviewQuery(2);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pump();
      await tester.pump();
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'failed deletion survives later saved-view mutation and filter recovery',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSavedViewMutationFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final firstWarningView = _savedReviewView(
        id: 'saved-warning-failed-delete-later-mutation-first',
        name: 'Warning failed delete later mutation first',
        filter: warningFilter,
      );
      final secondWarningView = _savedReviewView(
        id: 'saved-warning-failed-delete-later-mutation-second',
        name: 'Warning failed delete later mutation second',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([firstWarningView, secondWarningView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final firstWarningKey = const Key(
        'operations_review_saved_view_saved-warning-failed-delete-later-mutation-first',
      );
      final secondWarningKey = const Key(
        'operations_review_saved_view_saved-warning-failed-delete-later-mutation-second',
      );
      const retryKey = Key('operations_review_retry');
      const newSavedViewName = 'High failed delete later mutation replacement';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(2));
      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      final laterFilterError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(laterFilterError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(3));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = true;
      final deleteFinder = find.byTooltip(
        'Delete saved review view ${secondWarningView.name}',
      );
      await tester.scrollUntilVisible(
        deleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(deleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(deleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsOneWidget);
      final deletionError = find.textContaining(
        'Could not delete saved review view',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(deletionError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewFilterWrites[2].completer.isCompleted,
        isTrue,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(4));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        newSavedViewName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      final afterReplacementSave = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(afterReplacementSave, hasLength(3));
      final newSavedView = afterReplacementSave.singleWhere(
        (view) => view.name == newSavedViewName,
      );
      final newSavedViewKey = Key(
        'operations_review_saved_view_${newSavedView.id}',
      );
      expect(newSavedView.filter, highFilter);
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      expect(
        repository.pendingReviewFilterWrites[3].completer.isCompleted,
        isTrue,
      );
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(tester, secondWarningKey, settle: false);
      final retryDeleteFinder = find.byTooltip(
        'Delete saved review view ${secondWarningView.name}',
      );
      await tester.scrollUntilVisible(
        retryDeleteFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(retryDeleteFinder),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(retryDeleteFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
      final finalSavedViews = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(finalSavedViews, hasLength(2));
      expect(
        finalSavedViews.map((view) => view.id).toList(growable: false),
        containsAll([firstWarningView.id, newSavedView.id]),
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      expect(find.byKey(firstWarningKey), findsNothing);
      expect(find.byKey(newSavedViewKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 6);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(6));
      expect(repository.pendingReviewQueries[5].query.filter, highFilter);
      await _scrollToReviewControl(tester, newSavedViewKey, settle: false);
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(
        tester.widget<InputChip>(find.byKey(firstWarningKey)).selected,
        isFalse,
      );
      expect(
        tester.widget<InputChip>(find.byKey(newSavedViewKey)).selected,
        isFalse,
      );
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      for (var index = 0; index < 5; index++) {
        repository.completeReviewQuery(index);
        await tester.pump();
        await tester.pump();
      }
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(5);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(firstWarningKey), findsOneWidget);
      expect(find.byKey(newSavedViewKey), findsOneWidget);
      expect(find.byKey(secondWarningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 6);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('failed save recovers after deletion retry and filter recovery', (
    tester,
  ) async {
    final repository =
        _ControlledFilterFailureThenSavedViewMutationFailureRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final firstWarningView = _savedReviewView(
      id: 'saved-warning-failed-save-after-delete-retry-first',
      name: 'Warning failed save after delete retry first',
      filter: warningFilter,
    );
    final secondWarningView = _savedReviewView(
      id: 'saved-warning-failed-save-after-delete-retry-second',
      name: 'Warning failed save after delete retry second',
      filter: warningFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([firstWarningView, secondWarningView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final firstWarningKey = const Key(
      'operations_review_saved_view_saved-warning-failed-save-after-delete-retry-first',
    );
    final secondWarningKey = const Key(
      'operations_review_saved_view_saved-warning-failed-save-after-delete-retry-second',
    );
    const retryKey = Key('operations_review_retry');
    const newSavedViewName =
        'Warning failed save after delete retry replacement';

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.appMetaWrites.last, (
      key: 'merge_review_filter_v1',
      value: warningFilter.encode(),
    ));
    await _expectReviewLoading(tester);

    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'High',
    );
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.filter, highFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(2));
    repository.failNextReviewFilterWriteOnRelease = true;
    repository.completeReviewFilterWrite(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      warningFilter,
    );
    final laterFilterError = find.textContaining(
      'Could not save review filters',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(laterFilterError, findsOneWidget);
    await _expectReviewLoading(tester);

    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(3));
    await _expectReviewLoading(tester);

    repository.failSavedViewWrites = true;
    final deleteFinder = find.byTooltip(
      'Delete saved review view ${secondWarningView.name}',
    );
    await tester.scrollUntilVisible(
      deleteFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(deleteFinder),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(deleteFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewWriteAttempts, 1);
    expect(repository.savedViewReadCallCount, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsOneWidget);
    final deletionError = find.textContaining(
      'Could not delete saved review view',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(deletionError, findsOneWidget);

    repository.failSavedViewWrites = false;
    repository.completeReviewFilterWrite(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(
      repository.pendingReviewFilterWrites[2].completer.isCompleted,
      isTrue,
    );
    await _expectReviewLoading(tester);

    await _scrollToReviewControl(tester, secondWarningKey, settle: false);
    final retryDeleteFinder = find.byTooltip(
      'Delete saved review view ${secondWarningView.name}',
    );
    await tester.scrollUntilVisible(
      retryDeleteFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(retryDeleteFinder),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(retryDeleteFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    final afterRetryDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(afterRetryDelete, hasLength(1));
    expect(afterRetryDelete.single.id, firstWarningView.id);
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'High',
    );
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.filter, highFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(4));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    await _expectReviewLoading(tester);

    repository.failSavedViewWrites = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      newSavedViewName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewWriteAttempts, 2);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.text(newSavedViewName), findsNothing);
    final saveError = find.textContaining('Could not save review view');
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(saveError, findsOneWidget);
    expect(
      repository.pendingReviewFilterWrites[3].completer.isCompleted,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.failSavedViewWrites = false;
    repository.completeReviewFilterWrite(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    expect(
      repository.pendingReviewFilterWrites[3].completer.isCompleted,
      isTrue,
    );
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    await _expectReviewLoading(tester);

    final replacementSavedViewKey = Key(
      'operations_review_saved_view_${firstWarningView.id}',
    );
    await _scrollToReviewControl(
      tester,
      replacementSavedViewKey,
      settle: false,
    );
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(find.text(newSavedViewName), findsNothing);

    repository.failSavedViewWrites = false;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      newSavedViewName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
    final afterRetrySave = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(afterRetrySave, hasLength(2));
    final replacementView = afterRetrySave.singleWhere(
      (view) => view.name == newSavedViewName,
    );
    final replacementKey = Key(
      'operations_review_saved_view_${replacementView.id}',
    );
    expect(replacementView.filter, highFilter);
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(replacementKey), findsOneWidget);
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(5));
    expect(repository.pendingReviewQueries[4].query.filter, highFilter);
    expect(find.byKey(firstWarningKey), findsNothing);
    expect(find.byKey(replacementKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 7);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(6));
    expect(repository.pendingReviewQueries[5].query.filter, highFilter);
    await _scrollToReviewControl(tester, replacementKey, settle: false);
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(firstWarningKey)).selected,
      isFalse,
    );
    expect(
      tester.widget<InputChip>(find.byKey(replacementKey)).selected,
      isFalse,
    );
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    for (var index = 0; index < 5; index++) {
      repository.completeReviewQuery(index);
      await tester.pump();
      await tester.pump();
    }
    expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(5);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 7);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.savedViewWriteAttempts, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      [
        'merge_review_filter_v1',
        'merge_review_filter_v1',
        MergeReviewSavedViewStore.metaKey,
        'merge_review_filter_v1',
        MergeReviewSavedViewStore.metaKey,
      ],
    );
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('post-retry saved-view deletion survives a later filter write', (
    tester,
  ) async {
    final repository =
        _ControlledFilterFailureThenSavedViewMutationFailureRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final firstWarningView = _savedReviewView(
      id: 'saved-warning-post-retry-delete-first',
      name: 'Warning post retry delete first',
      filter: warningFilter,
    );
    final secondWarningView = _savedReviewView(
      id: 'saved-warning-post-retry-delete-second',
      name: 'Warning post retry delete second',
      filter: warningFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([firstWarningView, secondWarningView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final firstWarningKey = const Key(
      'operations_review_saved_view_saved-warning-post-retry-delete-first',
    );
    final secondWarningKey = const Key(
      'operations_review_saved_view_saved-warning-post-retry-delete-second',
    );
    const retryKey = Key('operations_review_retry');

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );

    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

    repository.failSavedViewWrites = true;
    await _scrollToReviewControl(tester, secondWarningKey, settle: false);
    await tester.tap(
      find.byTooltip('Delete saved review view ${secondWarningView.name}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewWriteAttempts, 1);
    expect(repository.savedViewReadCallCount, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsOneWidget);
    final deletionError = find.textContaining(
      'Could not delete saved review view',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(deletionError, findsOneWidget);

    repository.failSavedViewWrites = false;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(repository.appMetaWrites.last, (
      key: 'merge_review_filter_v1',
      value: warningFilter.encode(),
    ));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      warningFilter,
    );
    expect(
      repository.pendingReviewFilterWrites[0].completer.isCompleted,
      isTrue,
    );
    await _expectReviewLoading(tester);

    await _scrollToReviewControl(tester, secondWarningKey, settle: false);
    await tester.tap(
      find.byTooltip('Delete saved review view ${secondWarningView.name}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    final afterRetryDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(afterRetryDelete, hasLength(1));
    expect(afterRetryDelete.single.id, firstWarningView.id);
    expect(find.byKey(firstWarningKey), findsOneWidget);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'High',
    );
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.filter, highFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(2));
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    await _expectReviewLoading(tester);

    await _scrollToReviewControl(tester, firstWarningKey, settle: false);
    await tester.tap(
      find.byTooltip('Delete saved review view ${firstWarningView.name}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    final afterPostRetryDelete = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    );
    expect(afterPostRetryDelete, isEmpty);
    expect(find.byKey(firstWarningKey), findsNothing);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(
      repository.pendingReviewFilterWrites[1].completer.isCompleted,
      isFalse,
    );
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      warningFilter,
    );
    await _expectReviewLoading(tester);

    repository.completeReviewFilterWrite(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    expect(repository.appMetaWrites.last, (
      key: 'merge_review_filter_v1',
      value: highFilter.encode(),
    ));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    expect(
      repository.pendingReviewFilterWrites[1].completer.isCompleted,
      isTrue,
    );
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.filter, highFilter);
    expect(find.byKey(firstWarningKey), findsNothing);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.filter, highFilter);
    expect(find.byKey(firstWarningKey), findsNothing);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    for (var index = 0; index < 3; index++) {
      repository.completeReviewQuery(index);
      await tester.pump();
      await tester.pump();
    }
    expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(3);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(firstWarningKey), findsNothing);
    expect(find.byKey(secondWarningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 0);
    expect(repository.savedViewWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      [
        'merge_review_filter_v1',
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewStore.metaKey,
        'merge_review_filter_v1',
      ],
    );
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'empty saved-view list accepts a later save during filter recovery',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSavedViewMutationFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final warningView = _savedReviewView(
        id: 'saved-warning-empty-before-later-save',
        name: 'Warning empty before later save',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([warningView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final warningKey = const Key(
        'operations_review_saved_view_saved-warning-empty-before-later-save',
      );
      const retryKey = Key('operations_review_retry');
      const replacementName = 'High saved after empty list';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(
        find.byTooltip('Delete saved review view ${warningView.name}'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(warningKey), findsOneWidget);
      final deletionError = find.textContaining(
        'Could not delete saved review view',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(deletionError, findsOneWidget);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(
        find.byTooltip('Delete saved review view ${warningView.name}'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(2));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        replacementName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      final savedAfterEmpty = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      );
      expect(savedAfterEmpty, hasLength(1));
      final replacementView = savedAfterEmpty.single;
      expect(replacementView.name, replacementName);
      expect(replacementView.filter, highFilter);
      final replacementKey = Key(
        'operations_review_saved_view_${replacementView.id}',
      );
      expect(find.byKey(replacementKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);
      expect(
        repository.pendingReviewFilterWrites[1].completer.isCompleted,
        isFalse,
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      await _expectReviewLoading(tester);

      repository.completeReviewFilterWrite(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: highFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, highFilter);
      expect(find.byKey(replacementKey), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 6);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      await _scrollToReviewControl(tester, replacementKey, settle: false);
      expect(find.byKey(replacementKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      for (var index = 0; index < 3; index++) {
        repository.completeReviewQuery(index);
        await tester.pump();
        await tester.pump();
      }
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(replacementKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 6);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 0);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
          MergeReviewSavedViewStore.metaKey,
          'merge_review_filter_v1',
        ],
      );
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'post-empty saved-view save failure recovers before later deletion',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSavedViewMutationFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final warningView = _savedReviewView(
        id: 'saved-warning-post-empty-save-failure',
        name: 'Warning post empty save failure',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([warningView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final warningKey = const Key(
        'operations_review_saved_view_saved-warning-post-empty-save-failure',
      );
      const retryKey = Key('operations_review_retry');
      const replacementName = 'High post empty save failure replacement';

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(
        find.byTooltip('Delete saved review view ${warningView.name}'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 1);
      expect(repository.savedViewReadCallCount, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(warningKey), findsOneWidget);
      final deletionError = find.textContaining(
        'Could not delete saved review view',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(deletionError, findsOneWidget);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(
        find.byTooltip('Delete saved review view ${warningView.name}'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 3);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(warningKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'High',
      );
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(2));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));

      repository.failSavedViewWrites = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        replacementName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.savedViewWriteAttempts, 2);
      expect(repository.savedViewReadCallCount, 4);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
      expect(find.text(replacementName), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      final saveError = find.textContaining('Could not save review view');
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(saveError, findsOneWidget);
      expect(
        repository.pendingReviewFilterWrites[1].completer.isCompleted,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.failSavedViewWrites = false;
      repository.completeReviewFilterWrite(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      await _expectReviewLoading(tester);

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_saved_view_save'),
        settle: false,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_save')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('operations_review_saved_view_name')),
        replacementName,
      );
      await tester.tap(
        find.byKey(const Key('operations_review_saved_view_confirm')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 5);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
      final replacementView = MergeReviewSavedViewCodec.decode(
        repository.appMetaWrites.last.value,
      ).single;
      expect(replacementView.name, replacementName);
      expect(replacementView.filter, highFilter);
      final replacementKey = Key(
        'operations_review_saved_view_${replacementView.id}',
      );
      expect(find.byKey(replacementKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);

      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(3));
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));

      await _scrollToReviewControl(tester, replacementKey, settle: false);
      await tester.tap(
        find.byTooltip('Delete saved review view $replacementName'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 6);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        isEmpty,
      );
      expect(find.byKey(replacementKey), findsNothing);
      expect(
        repository.pendingReviewFilterWrites[2].completer.isCompleted,
        isFalse,
      );

      repository.completeReviewFilterWrite(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 6));
      expect(repository.appMetaWrites.last, (
        key: 'merge_review_filter_v1',
        value: warningFilter.encode(),
      ));
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        warningFilter,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 7);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, warningFilter);
      expect(find.byKey(replacementKey), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, 8);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, warningFilter);
      expect(find.byKey(replacementKey), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      for (var index = 0; index < 4; index++) {
        repository.completeReviewQuery(index);
        await tester.pump();
        await tester.pump();
      }
      expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
      expect(repository.pendingReviewQueries[4].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(4);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(
        repository.queries
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: warningFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (102 total)',
      );
      expect(find.byKey(replacementKey), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, 8);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 0);
      expect(repository.savedViewWriteAttempts, 2);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 6));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
          MergeReviewSavedViewStore.metaKey,
          'merge_review_filter_v1',
        ],
      );
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('post-empty retry-save survives a queued saved-view apply', (
    tester,
  ) async {
    final repository =
        _ControlledFilterFailureThenSavedViewMutationFailureRepository(
          _backlogReviewIssues(),
        );
    const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
    const warningFilter = MergeReviewFilter(
      severity: MergeReviewSeverity.warning,
    );
    final warningView = _savedReviewView(
      id: 'saved-warning-post-empty-queued-apply',
      name: 'Warning post empty queued apply',
      filter: warningFilter,
    );
    await repository.setAppMeta('merge_review_filter_v1', highFilter.encode());
    await repository.setAppMeta(
      MergeReviewSavedViewStore.metaKey,
      MergeReviewSavedViewCodec.encode([warningView]),
    );
    final baselineMetaWrites = repository.appMetaWrites.length;

    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    final warningKey = const Key(
      'operations_review_saved_view_saved-warning-post-empty-queued-apply',
    );
    const retryKey = Key('operations_review_retry');
    const replacementName = 'High post empty queued apply replacement';

    repository.holdReviewQueries = true;
    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(1));
    expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(1));

    repository.failSavedViewWrites = true;
    await _scrollToReviewControl(tester, warningKey, settle: false);
    await tester.tap(
      find.byTooltip('Delete saved review view ${warningView.name}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.savedViewWriteAttempts, 1);
    expect(repository.savedViewReadCallCount, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
    expect(find.byKey(warningKey), findsOneWidget);
    final deletionError = find.textContaining(
      'Could not delete saved review view',
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(deletionError, findsOneWidget);

    repository.failSavedViewWrites = false;
    repository.completeReviewFilterWrite(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 1));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      warningFilter,
    );
    await _expectReviewLoading(tester);

    await _scrollToReviewControl(tester, warningKey, settle: false);
    await tester.tap(
      find.byTooltip('Delete saved review view ${warningView.name}'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 3);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(
      MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
      isEmpty,
    );
    expect(find.byKey(warningKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'High',
    );
    expect(repository.pendingReviewQueries, hasLength(2));
    expect(repository.pendingReviewQueries[1].query.filter, highFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(2));

    repository.failSavedViewWrites = true;
    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      replacementName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.savedViewWriteAttempts, 2);
    expect(repository.savedViewReadCallCount, 4);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 2));
    expect(find.text(replacementName), findsNothing);
    expect(find.byKey(warningKey), findsNothing);
    final saveError = find.textContaining('Could not save review view');
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    expect(saveError, findsOneWidget);
    expect(
      repository.pendingReviewFilterWrites[1].completer.isCompleted,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.failSavedViewWrites = false;
    repository.completeReviewFilterWrite(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    await _expectReviewLoading(tester);

    await _scrollToReviewControl(
      tester,
      const Key('operations_review_saved_view_save'),
      settle: false,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_save')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('operations_review_saved_view_name')),
      replacementName,
    );
    await tester.tap(
      find.byKey(const Key('operations_review_saved_view_confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 5);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
    final replacementView = MergeReviewSavedViewCodec.decode(
      repository.appMetaWrites.last.value,
    ).single;
    expect(replacementView.name, replacementName);
    expect(replacementView.filter, highFilter);
    final replacementKey = Key(
      'operations_review_saved_view_${replacementView.id}',
    );
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(find.byKey(warningKey), findsNothing);

    repository.holdReviewFilterWrites = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    expect(repository.pendingReviewQueries, hasLength(3));
    expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(3));

    await _scrollToReviewControl(tester, replacementKey, settle: false);
    await tester.tap(find.byKey(replacementKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.pendingReviewQueries, hasLength(4));
    expect(repository.pendingReviewQueries[3].query.filter, highFilter);
    expect(repository.pendingReviewFilterWrites, hasLength(3));
    expect(
      tester.widget<InputChip>(find.byKey(replacementKey)).selected,
      isTrue,
    );
    expect(
      repository.pendingReviewFilterWrites[2].completer.isCompleted,
      isFalse,
    );
    await _expectReviewLoading(tester);

    repository.failNextReviewFilterWriteOnRelease = true;
    repository.completeReviewFilterWrite(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
    expect(repository.appMetaWrites.last, (
      key: 'merge_review_filter_v1',
      value: highFilter.encode(),
    ));
    expect(
      MergeReviewFilter.decode(
        await repository.getAppMeta('merge_review_filter_v1'),
      ),
      highFilter,
    );
    expect(
      repository.pendingReviewFilterWrites[2].completer.isCompleted,
      isTrue,
    );
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(
      tester.widget<InputChip>(find.byKey(replacementKey)).selected,
      isTrue,
    );
    await _expectReviewLoading(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    repository.failSavedViewReads = true;
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 6);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(5));
    expect(repository.pendingReviewQueries[4].query.filter, highFilter);
    expect(find.byKey(replacementKey), findsNothing);
    expect(find.byKey(warningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    await _expectReviewLoading(tester);

    repository.failSavedViewReads = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _mountOperationsPage(tester, repository);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(tester.takeException(), isNull);
    expect(repository.savedViewReadCallCount, 7);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.pendingReviewQueries, hasLength(6));
    expect(repository.pendingReviewQueries[5].query.filter, highFilter);
    await _scrollToReviewControl(tester, replacementKey, settle: false);
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(find.byKey(warningKey), findsNothing);
    expect(
      tester.widget<InputChip>(find.byKey(replacementKey)).selected,
      isFalse,
    );
    expect(find.byKey(retryKey), findsNothing);
    expect(
      find.textContaining('Could not load saved review views'),
      findsNothing,
    );
    await _expectReviewLoading(tester);

    for (var index = 0; index < 5; index++) {
      repository.completeReviewQuery(index);
      await tester.pump();
      await tester.pump();
    }
    expect(repository.pendingReviewQueries[0].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[1].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[2].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[3].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[4].completer.isCompleted, isTrue);
    expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
    await _expectReviewLoading(tester);

    repository.completeReviewQuery(5);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      repository.pendingReviewQueries
          .map((pending) => pending.completer.isCompleted)
          .toList(growable: false),
      [true, true, true, true, true, true],
    );
    expect(
      repository.queries
          .map((query) => (offset: query.offset, filter: query.filter))
          .toList(growable: false),
      [
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: warningFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
        (offset: 0, filter: highFilter),
      ],
    );
    await _expectReviewCount(
      tester,
      'Showing 1-100 of 101 matching review issues (102 total)',
    );
    expect(find.byKey(replacementKey), findsOneWidget);
    expect(find.byKey(warningKey), findsNothing);
    expect(find.byKey(retryKey), findsNothing);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    expect(repository.savedViewReadCallCount, 7);
    expect(repository.savedViewReadAttempts, 1);
    expect(repository.reviewFilterWriteAttempts, 1);
    expect(repository.savedViewWriteAttempts, 2);
    expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 5));
    expect(
      repository.appMetaWrites
          .skip(baselineMetaWrites)
          .map((write) => write.key)
          .toList(growable: false),
      [
        'merge_review_filter_v1',
        MergeReviewSavedViewStore.metaKey,
        'merge_review_filter_v1',
        MergeReviewSavedViewStore.metaKey,
        'merge_review_filter_v1',
      ],
    );
    expect(repository.operationsReadCounts, (
      jobs: baselineReads.jobs + 2,
      artifacts: baselineReads.artifacts + 4,
      logs: baselineReads.logs + 2,
      exports: baselineReads.exports + 2,
      governance: baselineReads.governance + 2,
    ));
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets(
    'recovered retry-save drains repeated queued saved-view applies',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSavedViewMutationFailureRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final initialWarningView = _savedReviewView(
        id: 'saved-warning-recovered-repeated-apply',
        name: 'Warning recovered repeated apply',
        filter: warningFilter,
      );
      const replacementHighName = 'High recovered repeated apply';
      const secondWarningName = 'Warning recovered repeated apply second';
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([initialWarningView]),
      );

      final store = MergeReviewSavedViewStore(repository);
      repository.failSavedViewWrites = true;
      await expectLater(store.remove(initialWarningView.id), throwsStateError);
      repository.failSavedViewWrites = false;
      expect(await store.remove(initialWarningView.id), isEmpty);

      repository.failSavedViewWrites = true;
      await expectLater(
        store.save(name: replacementHighName, filter: highFilter),
        throwsStateError,
      );
      repository.failSavedViewWrites = false;
      final recoveredViews = await store.save(
        name: replacementHighName,
        filter: highFilter,
      );
      final replacementHighView = recoveredViews.single;
      final finalViews = await store.save(
        name: secondWarningName,
        filter: warningFilter,
      );
      final secondWarningView = finalViews.singleWhere(
        (view) => view.name == secondWarningName,
      );
      expect(finalViews, hasLength(2));
      expect(finalViews.map((view) => view.id).toSet(), {
        replacementHighView.id,
        secondWarningView.id,
      });
      expect(repository.savedViewWriteAttempts, 2);

      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineSavedViewReadCalls = repository.savedViewReadCallCount;
      final baselineQueries = repository.queries.length;
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final highKey = Key(
        'operations_review_saved_view_${replacementHighView.id}',
      );
      final warningKey = Key(
        'operations_review_saved_view_${secondWarningView.id}',
      );
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));

      await _scrollToReviewControl(tester, highKey, settle: false);
      await tester.tap(find.byKey(highKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);

      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(find.byKey(warningKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isFalse);
      expect(tester.widget<InputChip>(find.byKey(warningKey)).selected, isTrue);

      await _scrollToReviewControl(tester, highKey, settle: false);
      await tester.tap(find.byKey(highKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);
      expect(
        tester.widget<InputChip>(find.byKey(warningKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          'merge_review_filter_v1',
        ],
      );
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.value)
            .toList(growable: false),
        [highFilter.encode(), warningFilter.encode(), highFilter.encode()],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);
      expect(
        tester.widget<InputChip>(find.byKey(warningKey)).selected,
        isFalse,
      );
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, baselineSavedViewReadCalls + 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      expect(find.byKey(highKey), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, baselineSavedViewReadCalls + 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(6));
      expect(repository.pendingReviewQueries[5].query.filter, highFilter);
      await _scrollToReviewControl(tester, highKey, settle: false);
      expect(find.byKey(highKey), findsOneWidget);
      expect(find.byKey(warningKey), findsOneWidget);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isFalse);
      expect(
        tester.widget<InputChip>(find.byKey(warningKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      for (var index = 0; index < 5; index++) {
        repository.completeReviewQuery(index);
        await tester.pump();
        await tester.pump();
      }
      expect(
        repository.pendingReviewQueries
            .take(5)
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(5);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true, true],
      );
      expect(
        repository.queries
            .skip(baselineQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(highKey), findsOneWidget);
      expect(find.byKey(warningKey), findsOneWidget);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isFalse);
      expect(
        tester.widget<InputChip>(find.byKey(warningKey)).selected,
        isFalse,
      );
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, baselineSavedViewReadCalls + 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.savedViewWriteAttempts, 2);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          'merge_review_filter_v1',
        ],
      );
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'repeated queued applies drain before a held saved-view deletion',
    (tester) async {
      final repository =
          _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
            _backlogReviewIssues(),
          );
      const highFilter = MergeReviewFilter(severity: MergeReviewSeverity.high);
      const warningFilter = MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
      );
      final highView = _savedReviewView(
        id: 'saved-high-repeated-apply-held-delete',
        name: 'High repeated apply held delete',
        filter: highFilter,
      );
      final warningView = _savedReviewView(
        id: 'saved-warning-repeated-apply-held-delete',
        name: 'Warning repeated apply held delete',
        filter: warningFilter,
      );
      await repository.setAppMeta(
        'merge_review_filter_v1',
        highFilter.encode(),
      );
      await repository.setAppMeta(
        MergeReviewSavedViewStore.metaKey,
        MergeReviewSavedViewCodec.encode([highView, warningView]),
      );
      final baselineMetaWrites = repository.appMetaWrites.length;

      final baselineQueries = repository.queries.length;
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineSavedViewReadCalls = repository.savedViewReadCallCount;
      final highKey = Key('operations_review_saved_view_${highView.id}');
      final warningKey = Key('operations_review_saved_view_${warningView.id}');
      const retryKey = Key('operations_review_retry');

      repository.holdReviewQueries = true;
      repository.holdReviewFilterWrites = true;
      repository.holdSavedViewWrites = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));

      await _scrollToReviewControl(tester, highKey, settle: false);
      await tester.tap(find.byKey(highKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);

      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(find.byKey(warningKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.filter, warningFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(tester.widget<InputChip>(find.byKey(warningKey)).selected, isTrue);

      await _scrollToReviewControl(tester, highKey, settle: false);
      await tester.tap(find.byKey(highKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.filter, highFilter);
      expect(repository.pendingReviewFilterWrites, hasLength(1));
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);
      expect(
        tester.widget<InputChip>(find.byKey(warningKey)).selected,
        isFalse,
      );

      await _scrollToReviewControl(tester, warningKey, settle: false);
      await tester.tap(
        find.byTooltip('Delete saved review view ${warningView.name}'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.pendingSavedViewWrites, hasLength(1));
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(find.byKey(warningKey), findsOneWidget);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);
      await _expectReviewLoading(tester);

      repository.failNextReviewFilterWriteOnRelease = true;
      repository.completeReviewFilterWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 3));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          'merge_review_filter_v1',
        ],
      );
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.value)
            .toList(growable: false),
        [highFilter.encode(), warningFilter.encode(), highFilter.encode()],
      );
      expect(
        MergeReviewFilter.decode(
          await repository.getAppMeta('merge_review_filter_v1'),
        ),
        highFilter,
      );
      expect(
        repository.pendingSavedViewWrites[0].completer.isCompleted,
        isFalse,
      );
      expect(find.byKey(warningKey), findsOneWidget);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);
      final filterWriteError = find.textContaining(
        'Could not save review filters',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(filterWriteError, findsOneWidget);
      await _expectReviewLoading(tester);

      repository.completeSavedViewWrite(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
      expect(
        repository.appMetaWrites
            .skip(baselineMetaWrites)
            .map((write) => write.key)
            .toList(growable: false),
        [
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          'merge_review_filter_v1',
          MergeReviewSavedViewStore.metaKey,
        ],
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.appMetaWrites.last.value),
        [highView],
      );
      await _scrollToReviewControl(tester, highKey, settle: false);
      expect(find.byKey(highKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isTrue);
      await _expectReviewLoading(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      repository.failSavedViewReads = true;
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, baselineSavedViewReadCalls + 2);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(5));
      expect(repository.pendingReviewQueries[4].query.filter, highFilter);
      expect(find.byKey(highKey), findsNothing);
      expect(find.byKey(warningKey), findsNothing);
      expect(find.byKey(retryKey), findsNothing);
      await _expectReviewLoading(tester);

      repository.failSavedViewReads = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _mountOperationsPage(tester, repository);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(tester.takeException(), isNull);
      expect(repository.savedViewReadCallCount, baselineSavedViewReadCalls + 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.pendingReviewQueries, hasLength(6));
      expect(repository.pendingReviewQueries[5].query.filter, highFilter);
      await _scrollToReviewControl(tester, highKey, settle: false);
      expect(find.byKey(highKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      expect(
        find.textContaining('Could not load saved review views'),
        findsNothing,
      );
      await _expectReviewLoading(tester);

      for (var index = 0; index < 5; index++) {
        repository.completeReviewQuery(index);
        await tester.pump();
        await tester.pump();
      }
      expect(
        repository.pendingReviewQueries
            .take(5)
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true],
      );
      expect(repository.pendingReviewQueries[5].completer.isCompleted, isFalse);
      await _expectReviewLoading(tester);

      repository.completeReviewQuery(5);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        repository.pendingReviewQueries
            .map((pending) => pending.completer.isCompleted)
            .toList(growable: false),
        [true, true, true, true, true, true],
      );
      expect(
        repository.queries
            .skip(baselineQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: warningFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
          (offset: 0, filter: highFilter),
        ],
      );
      await _expectReviewCount(
        tester,
        'Showing 1-100 of 101 matching review issues (102 total)',
      );
      expect(find.byKey(highKey), findsOneWidget);
      expect(find.byKey(warningKey), findsNothing);
      expect(tester.widget<InputChip>(find.byKey(highKey)).selected, isFalse);
      expect(find.byKey(retryKey), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(repository.savedViewReadCallCount, baselineSavedViewReadCalls + 3);
      expect(repository.savedViewReadAttempts, 1);
      expect(repository.reviewFilterWriteAttempts, 1);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites + 4));
      expect(repository.operationsReadCounts, (
        jobs: baselineReads.jobs + 2,
        artifacts: baselineReads.artifacts + 4,
        logs: baselineReads.logs + 2,
        exports: baselineReads.exports + 2,
        governance: baselineReads.governance + 2,
      ));
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'owned corrective failure stays unavailable until retry correction succeeds',
    (tester) async {
      final highIssues = [
        for (var index = 0; index < 101; index++)
          _structuredReviewIssue(
            logicalKey: 'corrective-failure-high-$index',
            severity: MergeReviewSeverity.high,
            createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
          ),
      ];
      final warningReuseIssue = _structuredReviewIssue(
        logicalKey: 'corrective-failure-warning-reuse',
        type: MergeReviewIssueType.lowConfidenceReuse,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final trackedHighIssue = highIssues.last;
      final repository = _ControlledReviewIssueRepository([
        ...highIssues,
        warningReuseIssue,
      ]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: trackedHighIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: warningReuseIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);

      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineMetaWrites = repository.appMetaWrites.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      const allPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_all',
      );
      const onPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      const outsidePresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      final highPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${trackedHighIssue.id}',
      );
      final warningPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
      );
      final highReviewSelectKey = Key(
        'operations_review_issue_select_${trackedHighIssue.id}',
      );
      final warningReviewSelectKey = Key(
        'operations_review_issue_select_${warningReuseIssue.id}',
      );

      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots on loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsNothing,
      );
      repository.holdReviewQueries = true;
      await _scrollToReviewControl(
        tester,
        const Key('operations_review_page_next'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_page_next')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(1));
      expect(repository.pendingReviewQueries[0].query.offset, 100);
      repository.completeReviewQueryWithPage(
        0,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(repository.pendingReviewQueries[1].query.offset, 0);
      expect(
        repository.pendingReviewQueries[1].query.filter,
        MergeReviewFilter.all,
      );
      repository.failReviewQuery(1, message: 'OWNED_CORRECTIVE_FAILURE');
      await tester.pumpAndSettle();

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_error'),
      );
      expect(find.textContaining('OWNED_CORRECTIVE_FAILURE'), findsOneWidget);
      expect(find.byKey(const Key('operations_review_retry')), findsOneWidget);
      await _expectReviewCount(
        tester,
        'Review results unavailable for the selected filters',
      );
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
      );
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
      }
      await _scrollToReviewControl(tester, highPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(highPresenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, warningPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(warningPresenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      final readsAfterCorrectiveFailure = repository.operationsReadCounts;
      final metaWritesAfterCorrectiveFailure = repository.appMetaWrites.length;

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_retry'),
        settle: false,
      );
      await tester.tap(find.byKey(const Key('operations_review_retry')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(repository.pendingReviewQueries[2].query.offset, 100);
      expect(
        repository.pendingReviewQueries[2].query.filter,
        MergeReviewFilter.all,
      );
      expect(find.textContaining('OWNED_CORRECTIVE_FAILURE'), findsNothing);
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      repository.completeReviewQueryWithPage(
        2,
        const MergeReviewIssuePage(
          items: [],
          totalCount: 1,
          matchingCount: 1,
          offset: 100,
          limit: 100,
        ),
      );
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(4));
      expect(repository.pendingReviewQueries[3].query.offset, 0);
      expect(
        repository.pendingReviewQueries[3].query.filter,
        MergeReviewFilter.all,
      );
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      repository.completeReviewQueryWithPage(
        3,
        MergeReviewIssuePage(
          items: [warningReuseIssue],
          totalCount: 1,
          matchingCount: 1,
          offset: 0,
          limit: 100,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (1 total)',
      );
      await _scrollToReviewControl(tester, warningReviewSelectKey);
      expect(find.byKey(warningReviewSelectKey), findsOneWidget);
      expect(find.byKey(highReviewSelectKey), findsNothing);
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(
          tester.widget<ChoiceChip>(find.byKey(key)).onSelected,
          isNotNull,
        );
      }
      await _scrollToReviewControl(tester, highPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(highPresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, warningPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(warningPresenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots on loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(trackedHighIssue.id)),
        findsNothing,
      );
      expect(
        repository.queries
            .skip(baselineReviewQueries)
            .map((query) => (offset: query.offset, filter: query.filter))
            .toList(growable: false),
        [
          (offset: 100, filter: MergeReviewFilter.all),
          (offset: 0, filter: MergeReviewFilter.all),
          (offset: 100, filter: MergeReviewFilter.all),
          (offset: 0, filter: MergeReviewFilter.all),
        ],
      );
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.operationsReadCounts, readsAfterCorrectiveFailure);
      expect(repository.appMetaWrites, hasLength(baselineMetaWrites));
      expect(
        repository.appMetaWrites,
        hasLength(metaWritesAfterCorrectiveFailure),
      );
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'latest review response owns inventory presence after out-of-order completion',
    (tester) async {
      final warningCategoryIssue = _structuredReviewIssue(
        logicalKey: 'presence-race-warning-category',
        type: MergeReviewIssueType.categoryConflictCandidate,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final warningReuseIssue = _structuredReviewIssue(
        logicalKey: 'presence-race-warning-reuse',
        type: MergeReviewIssueType.lowConfidenceReuse,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final repository = _ControlledReviewIssueRepository([
        warningCategoryIssue,
        warningReuseIssue,
      ]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: warningCategoryIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: warningReuseIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      const allPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_all',
      );
      const onPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      final categoryPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningCategoryIssue.id}',
      );
      final reusePresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
      );

      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 2 on this loaded review page, '
        '0 outside it.',
      );

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_type_filter'),
        option: 'Low-confidence reuse',
        scrollDelta: -250,
      );

      expect(repository.pendingReviewQueries, hasLength(2));
      expect(
        repository.pendingReviewQueries[0].query.filter,
        const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );
      expect(
        repository.pendingReviewQueries[1].query.filter,
        const MergeReviewFilter(
          severity: MergeReviewSeverity.warning,
          type: MergeReviewIssueType.lowConfidenceReuse,
        ),
      );
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
        settle: false,
      );
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );

      repository.completeReviewQuery(1);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (2 total)',
      );
      await _expectReviewTextVisible(
        tester,
        'STRUCTURED_presence-race-warning-reuse',
      );
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _scrollToReviewControl(tester, categoryPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(categoryPresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, reusePresenceKey);
      expect(
        find.descendant(
          of: find.byKey(reusePresenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots on loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningCategoryIssue.id)),
        findsNothing,
      );
      final metaWritesAfterLatestSuccess = repository.appMetaWrites.length;

      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      const reviewCountKey = Key('operations_review_filter_count');
      await _scrollToReviewControl(tester, reviewCountKey);
      expect(
        tester.widget<Text>(find.byKey(reviewCountKey)).data,
        'Showing 1 of 1 matching review issues (2 total)',
      );
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots on loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningCategoryIssue.id)),
        findsNothing,
      );
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestSuccess));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'latest review failure keeps presence unavailable after stale success',
    (tester) async {
      final warningCategoryIssue = _structuredReviewIssue(
        logicalKey: 'presence-failure-race-warning-category',
        type: MergeReviewIssueType.categoryConflictCandidate,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final warningReuseIssue = _structuredReviewIssue(
        logicalKey: 'presence-failure-race-warning-reuse',
        type: MergeReviewIssueType.lowConfidenceReuse,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final repository = _ControlledReviewIssueRepository([
        warningCategoryIssue,
        warningReuseIssue,
      ]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: warningCategoryIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: warningReuseIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      await _openReviewWorklistInventory(tester);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      const allPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_all',
      );
      const onPresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_on_page',
      );
      const outsidePresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      final categoryPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningCategoryIssue.id}',
      );
      final reusePresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
      );

      await _tapReviewControl(tester, onPresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        onPresenceKey,
        true,
      );

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_type_filter'),
        option: 'Low-confidence reuse',
        scrollDelta: -250,
      );

      expect(repository.pendingReviewQueries, hasLength(2));
      await _openReviewWorklistInventory(tester);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
        settle: false,
      );
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );

      repository.failReviewQuery(1);
      await tester.pumpAndSettle();

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_error'),
      );
      expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
      }
      await _scrollToReviewControl(tester, categoryPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(categoryPresenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

      repository.completeReviewQuery(0);
      await tester.pumpAndSettle();

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_error'),
      );
      expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
      }
      await _scrollToReviewControl(tester, categoryPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(categoryPresenceKey),
          matching: find.text('Loaded review page comparison unavailable'),
        ),
        findsOneWidget,
      );
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));

      await _scrollToReviewControl(
        tester,
        const Key('operations_review_retry'),
      );
      await tester.tap(find.byKey(const Key('operations_review_retry')));
      await tester.pump();

      expect(repository.pendingReviewQueries, hasLength(3));
      expect(
        repository.pendingReviewQueries[2].query.filter,
        const MergeReviewFilter(
          severity: MergeReviewSeverity.warning,
          type: MergeReviewIssueType.lowConfidenceReuse,
        ),
      );
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey, settle: false);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Loaded review page comparison unavailable until the latest selected '
        'filter/page request succeeds.',
      );

      repository.completeReviewQuery(2);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        allPresenceKey,
        true,
      );
      for (final key in const [onPresenceKey, outsidePresenceKey]) {
        await _scrollToReviewControl(tester, key);
        expect(
          tester.widget<ChoiceChip>(find.byKey(key)).onSelected,
          isNotNull,
        );
      }
      await _scrollToReviewControl(tester, categoryPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(categoryPresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, reusePresenceKey);
      expect(
        find.descendant(
          of: find.byKey(reusePresenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries + 3));
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets(
    'latest review success keeps presence available after stale failure',
    (tester) async {
      final warningCategoryIssue = _structuredReviewIssue(
        logicalKey: 'presence-stale-failure-warning-category',
        type: MergeReviewIssueType.categoryConflictCandidate,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final warningReuseIssue = _structuredReviewIssue(
        logicalKey: 'presence-stale-failure-warning-reuse',
        type: MergeReviewIssueType.lowConfidenceReuse,
        severity: MergeReviewSeverity.warning,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final repository = _ControlledReviewIssueRepository([
        warningCategoryIssue,
        warningReuseIssue,
      ]);
      await MergeReviewWorklistStore(repository).upsertAll([
        MergeReviewWorklistUpsert(
          issue: warningCategoryIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
        MergeReviewWorklistUpsert(
          issue: warningReuseIssue,
          status: MergeReviewWorkItemStatus.queued,
        ),
      ]);
      await _pumpOperationsPage(tester, repository);
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      final baselineWorklistWrites = repository.appMetaWrites
          .where((write) => write.key == MergeReviewWorklistStore.metaKey)
          .length;
      const summaryKey = Key(
        'operations_review_worklist_inventory_presence_summary',
      );
      const outsidePresenceKey = Key(
        'operations_review_worklist_inventory_presence_filter_outside_page',
      );
      final categoryPresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningCategoryIssue.id}',
      );
      final reusePresenceKey = Key(
        'operations_review_worklist_inventory_presence_${warningReuseIssue.id}',
      );

      repository.holdReviewQueries = true;
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_severity_filter'),
        option: 'Warning',
      );
      await _selectReviewFilterWithoutSettling(
        tester,
        key: const Key('operations_review_type_filter'),
        option: 'Low-confidence reuse',
        scrollDelta: -250,
      );

      expect(repository.pendingReviewQueries, hasLength(2));
      repository.completeReviewQuery(1);
      await tester.pumpAndSettle();

      await _expectReviewCount(
        tester,
        'Showing 1 of 1 matching review issues (2 total)',
      );
      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _scrollToReviewControl(tester, categoryPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(categoryPresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      await _scrollToReviewControl(tester, reusePresenceKey);
      expect(
        find.descendant(
          of: find.byKey(reusePresenceKey),
          matching: find.text('On loaded review page'),
        ),
        findsOneWidget,
      );
      await _tapReviewControl(tester, outsidePresenceKey);
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        outsidePresenceKey,
        true,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots outside loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningCategoryIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsNothing,
      );
      final metaWritesAfterLatestSuccess = repository.appMetaWrites.length;

      repository.failReviewQuery(0);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('operations_review_error')), findsNothing);
      expect(find.byKey(const Key('operations_review_retry')), findsNothing);
      const reviewCountKey = Key('operations_review_filter_count');
      await _scrollToReviewControl(tester, reviewCountKey);
      expect(
        tester.widget<Text>(find.byKey(reviewCountKey)).data,
        'Showing 1 of 1 matching review issues (2 total)',
      );
      await _openReviewWorklistInventory(tester);
      await _scrollToReviewControl(tester, summaryKey);
      expect(
        tester.widget<Text>(find.byKey(summaryKey)).data,
        'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
        '1 outside it.',
      );
      await _expectReviewWorklistInventoryFilterSelected(
        tester,
        outsidePresenceKey,
        true,
      );
      await _scrollToReviewControl(tester, outsidePresenceKey);
      expect(
        tester.widget<ChoiceChip>(find.byKey(outsidePresenceKey)).onSelected,
        isNotNull,
      );
      await _expectReviewWorklistInventoryCount(
        tester,
        'Showing 1-1 of 1 snapshots outside loaded review page '
        '(2 total loaded) / Page 1 of 1',
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningCategoryIssue.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(_reviewWorklistInventoryItemKey(warningReuseIssue.id)),
        findsNothing,
      );
      await _scrollToReviewControl(tester, categoryPresenceKey);
      expect(
        find.descendant(
          of: find.byKey(categoryPresenceKey),
          matching: find.text('Outside loaded review page'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('operations_review_loading')), findsNothing);
      expect(repository.operationsReadCounts, baselineReads);
      expect(repository.queries, hasLength(baselineReviewQueries + 2));
      expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestSuccess));
      expect(
        repository.appMetaWrites.where(
          (write) => write.key == MergeReviewWorklistStore.metaKey,
        ),
        hasLength(baselineWorklistWrites),
      );
      expect(repository.governanceMutationCount, 0);
    },
  );

  testWidgets('latest review failure message survives an older stale failure', (
    tester,
  ) async {
    final warningCategoryIssue = _structuredReviewIssue(
      logicalKey: 'presence-double-failure-warning-category',
      type: MergeReviewIssueType.categoryConflictCandidate,
      severity: MergeReviewSeverity.warning,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    final warningReuseIssue = _structuredReviewIssue(
      logicalKey: 'presence-double-failure-warning-reuse',
      type: MergeReviewIssueType.lowConfidenceReuse,
      severity: MergeReviewSeverity.warning,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final repository = _ControlledReviewIssueRepository([
      warningCategoryIssue,
      warningReuseIssue,
    ]);
    await MergeReviewWorklistStore(repository).upsertAll([
      MergeReviewWorklistUpsert(
        issue: warningCategoryIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
      MergeReviewWorklistUpsert(
        issue: warningReuseIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
    ]);
    await _pumpOperationsPage(tester, repository);
    await _openReviewWorklistInventory(tester);
    final baselineReads = repository.operationsReadCounts;
    final baselineReviewQueries = repository.queries.length;
    final baselineWorklistWrites = repository.appMetaWrites
        .where((write) => write.key == MergeReviewWorklistStore.metaKey)
        .length;
    const summaryKey = Key(
      'operations_review_worklist_inventory_presence_summary',
    );
    const allPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_all',
    );
    const onPresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_on_page',
    );
    const outsidePresenceKey = Key(
      'operations_review_worklist_inventory_presence_filter_outside_page',
    );
    final categoryPresenceKey = Key(
      'operations_review_worklist_inventory_presence_${warningCategoryIssue.id}',
    );

    await _tapReviewControl(tester, onPresenceKey);
    repository.holdReviewQueries = true;
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_severity_filter'),
      option: 'Warning',
    );
    await _selectReviewFilterWithoutSettling(
      tester,
      key: const Key('operations_review_type_filter'),
      option: 'Low-confidence reuse',
      scrollDelta: -250,
    );

    expect(repository.pendingReviewQueries, hasLength(2));
    repository.failReviewQuery(1, message: 'LATEST_REVIEW_FAILURE');
    await tester.pumpAndSettle();

    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.textContaining('LATEST_REVIEW_FAILURE'), findsOneWidget);
    expect(find.textContaining('STALE_REVIEW_FAILURE'), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      allPresenceKey,
      true,
    );
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Loaded review page comparison unavailable until the latest selected '
      'filter/page request succeeds.',
    );
    final metaWritesAfterLatestFailure = repository.appMetaWrites.length;

    repository.failReviewQuery(0, message: 'STALE_REVIEW_FAILURE');
    await tester.pumpAndSettle();

    await _scrollToReviewControl(tester, const Key('operations_review_error'));
    expect(find.textContaining('LATEST_REVIEW_FAILURE'), findsOneWidget);
    expect(find.textContaining('STALE_REVIEW_FAILURE'), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      allPresenceKey,
      true,
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-2 of 2 loaded snapshots / Page 1 of 1',
    );
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Loaded review page comparison unavailable until the latest selected '
      'filter/page request succeeds.',
    );
    for (final key in const [onPresenceKey, outsidePresenceKey]) {
      await _scrollToReviewControl(tester, key);
      expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
    }
    await _scrollToReviewControl(tester, categoryPresenceKey);
    expect(
      find.descendant(
        of: find.byKey(categoryPresenceKey),
        matching: find.text('Loaded review page comparison unavailable'),
      ),
      findsOneWidget,
    );
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));

    await _scrollToReviewControl(tester, const Key('operations_review_retry'));
    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pump();

    expect(repository.pendingReviewQueries, hasLength(3));
    expect(
      repository.pendingReviewQueries[2].query.filter,
      const MergeReviewFilter(
        severity: MergeReviewSeverity.warning,
        type: MergeReviewIssueType.lowConfidenceReuse,
      ),
    );
    expect(find.textContaining('LATEST_REVIEW_FAILURE'), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _scrollToReviewControl(tester, summaryKey, settle: false);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Loaded review page comparison unavailable until the latest selected '
      'filter/page request succeeds.',
    );

    repository.completeReviewQuery(2);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('operations_review_error')), findsNothing);
    await _openReviewWorklistInventory(tester);
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Across all 2 loaded stored snapshots: 1 on this loaded review page, '
      '1 outside it.',
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      allPresenceKey,
      true,
    );
    for (final key in const [onPresenceKey, outsidePresenceKey]) {
      await _scrollToReviewControl(tester, key);
      expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNotNull);
    }
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.queries, hasLength(baselineReviewQueries + 3));
    expect(repository.appMetaWrites, hasLength(metaWritesAfterLatestFailure));
    expect(
      repository.appMetaWrites.where(
        (write) => write.key == MergeReviewWorklistStore.metaKey,
      ),
      hasLength(baselineWorklistWrites),
    );
    expect(repository.governanceMutationCount, 0);
  });

  testWidgets('failed review page retries inline without full reload', (
    tester,
  ) async {
    final repository = _FailOnceReviewIssueRepository(_backlogReviewIssues());
    await _pumpOperationsPage(tester, repository);
    final baselineReads = repository.operationsReadCounts;
    repository.failNextReviewQuery = true;

    await _tapReviewPager(tester, const Key('operations_review_page_next'));

    expect(
      find.textContaining('Could not refresh review issues'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('operations_review_error')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(repository.operationsReadCounts, baselineReads);
    expect(repository.queries.last.offset, 100);

    await tester.tap(find.byKey(const Key('operations_review_retry')));
    await tester.pumpAndSettle();

    await _expectReviewCount(
      tester,
      'Showing 101-102 of 102 matching review issues (102 total)',
    );
    expect(repository.queries.last.offset, 100);
    expect(repository.operationsReadCounts, baselineReads);
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
  });

  testWidgets('initial review failure still commits operations data', (
    tester,
  ) async {
    final worklistIssue = _structuredReviewIssue(
      logicalKey: 'initial-review-failure-worklist',
    );
    final repository = _FailOnceReviewIssueRepository([
      ..._reviewIssues(),
      worklistIssue,
    ])..failNextReviewQuery = true;
    await MergeReviewWorklistStore(repository).upsertAll([
      MergeReviewWorklistUpsert(
        issue: worklistIssue,
        status: MergeReviewWorkItemStatus.queued,
      ),
    ]);
    await repository.upsertFetchJob(
      _fetchJob(
        id: 'initial-review-failure-job',
        message: 'INITIAL_OPERATIONS_STILL_LOADED',
      ),
    );

    await _pumpOperationsPage(tester, repository);

    expect(repository.queries, hasLength(1));
    expect(repository.operationsReadCounts, (
      jobs: 1,
      artifacts: 2,
      logs: 1,
      exports: 1,
      governance: 1,
    ));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('operations_refresh_error')), findsNothing);
    await _expectReviewError(tester);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('operations_review_retry')))
          .onPressed,
      isNotNull,
    );
    await _openReviewWorklistInventory(tester);
    const summaryKey = Key(
      'operations_review_worklist_inventory_presence_summary',
    );
    await _scrollToReviewControl(tester, summaryKey);
    expect(
      tester.widget<Text>(find.byKey(summaryKey)).data,
      'Loaded review page comparison unavailable until the latest selected '
      'filter/page request succeeds.',
    );
    await _expectReviewWorklistInventoryCount(
      tester,
      'Showing 1-1 of 1 loaded snapshots / Page 1 of 1',
    );
    await _expectReviewWorklistInventoryFilterSelected(
      tester,
      const Key('operations_review_worklist_inventory_presence_filter_all'),
      true,
    );
    for (final key in const [
      Key('operations_review_worklist_inventory_presence_filter_on_page'),
      Key('operations_review_worklist_inventory_presence_filter_outside_page'),
    ]) {
      await _scrollToReviewControl(tester, key);
      expect(tester.widget<ChoiceChip>(find.byKey(key)).onSelected, isNull);
    }
    final markerKey = Key(
      'operations_review_worklist_inventory_presence_${worklistIssue.id}',
    );
    await _scrollToReviewControl(tester, markerKey);
    expect(
      find.descendant(
        of: find.byKey(markerKey),
        matching: find.text('Loaded review page comparison unavailable'),
      ),
      findsOneWidget,
    );
    await _dragUntilText(tester, 'INITIAL_OPERATIONS_STILL_LOADED');
    expect(
      find.textContaining('INITIAL_OPERATIONS_STILL_LOADED'),
      findsOneWidget,
    );
  });

  testWidgets(
    'toolbar review failure preserves review snapshot and refreshes operations',
    (tester) async {
      final repository = _FailOnceReviewIssueRepository(_reviewIssues());
      await _pumpOperationsPage(tester, repository);
      await _expectReviewCount(
        tester,
        'Showing 1-3 of 3 matching review issues (3 total)',
      );
      final baselineReads = repository.operationsReadCounts;
      final baselineReviewQueries = repository.queries.length;
      await repository.upsertFetchJob(
        _fetchJob(
          id: 'full-review-failure-job',
          message: 'FULL_REFRESH_OPERATIONS_APPLIED',
        ),
      );
      repository.failNextReviewQuery = true;

      await tester.tap(find.byTooltip('Refresh operations data'));
      await tester.pumpAndSettle();

      expect(repository.recentFetchJobsReadCount, baselineReads.jobs + 1);
      expect(repository.datasetArtifactsReadCount, baselineReads.artifacts + 2);
      expect(repository.importLogsReadCount, baselineReads.logs + 1);
      expect(repository.exportHistoryReadCount, baselineReads.exports + 1);
      expect(repository.governanceLogsReadCount, baselineReads.governance + 1);
      expect(repository.queries, hasLength(baselineReviewQueries + 1));
      expect(find.byKey(const Key('operations_refresh_error')), findsNothing);
      await _expectReviewError(tester);
      await _expectReviewCount(
        tester,
        'Showing 1-3 of 3 matching review issues (3 total)',
      );
      await _dragUntilText(tester, 'FULL_REFRESH_OPERATIONS_APPLIED');
      expect(
        find.textContaining('FULL_REFRESH_OPERATIONS_APPLIED'),
        findsOneWidget,
      );
    },
  );

  testWidgets('initial operations failure does not block review results', (
    tester,
  ) async {
    final repository = _FailOnceOperationsRepository(_reviewIssues())
      ..failNextOperationsRead = true;

    await _pumpOperationsPage(tester, repository);

    expect(repository.recentFetchJobsReadCount, 1);
    expect(repository.queries, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('operations_refresh_error')), findsOneWidget);
    expect(
      find.textContaining('Could not refresh operations data'),
      findsOneWidget,
    );
    await _expectReviewCount(
      tester,
      'Showing 1-3 of 3 matching review issues (3 total)',
    );
    expect(find.byKey(const Key('operations_review_error')), findsNothing);
  });
}

Future<void> _pumpOperationsPage(
  WidgetTester tester,
  MemoryFoodRepository repository,
) async {
  await _mountOperationsPage(tester, repository);
  await tester.pumpAndSettle();
}

Future<void> _mountOperationsPage(
  WidgetTester tester,
  MemoryFoodRepository repository,
) async {
  final sourceCapabilities = SourceCapabilityRegistry(
    importerDescriptors: importerDescriptors,
    entities: nationalFoodEntities,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: OperationsPage(
        repository: repository,
        syncUseCase: SyncFoodCatalogUseCase(
          repository: repository,
          importers: [_NoopImporter()],
          normalizer: const FoodRecordNormalizer(),
        ),
        importerDescriptors: importerDescriptors,
        sourceCapabilities: sourceCapabilities,
        storageBudgetManager: StorageBudgetManager(repository: repository),
        modelBudgetController: ModelBudgetController(),
        settingsService: SettingsService(
          repository: repository,
          sourceCapabilities: sourceCapabilities,
        ),
        exportShareService: const ExportShareService(),
        onOpenSettings: () {},
      ),
    ),
  );
}

Future<void> _selectReviewFilter(
  WidgetTester tester, {
  required Key key,
  required String option,
}) async {
  final finder = find.byKey(key);
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _selectReviewFilterWithoutSettling(
  WidgetTester tester, {
  required Key key,
  required String option,
  double scrollDelta = 250,
}) async {
  final finder = find.byKey(key);
  final scrollable = find.byType(Scrollable).first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    for (var attempt = 0; attempt < 16; attempt++) {
      if (finder.evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(scrollable, const Offset(0, -350));
      await tester.pump();
    }
  }
  expect(finder, findsOneWidget);
  await tester.scrollUntilVisible(finder, scrollDelta, scrollable: scrollable);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(option).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _saveReviewView(WidgetTester tester, String name) async {
  await _tapReviewControl(
    tester,
    const Key('operations_review_saved_view_save'),
  );
  await tester.enterText(
    find.byKey(const Key('operations_review_saved_view_name')),
    name,
  );
  await tester.tap(
    find.byKey(const Key('operations_review_saved_view_confirm')),
  );
  await tester.pumpAndSettle();
}

Future<void> _deleteReviewView(WidgetTester tester, String name) async {
  final finder = find.byTooltip('Delete saved review view $name');
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapReviewControl(WidgetTester tester, Key key) async {
  await _scrollToReviewControl(tester, key);
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _scrollToReviewControl(
  WidgetTester tester,
  Key key, {
  bool settle = true,
}) async {
  final finder = find.byKey(key);
  final scrollable = find.byType(Scrollable).first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
  }
  await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _expectReviewCount(WidgetTester tester, String expected) async {
  const key = Key('operations_review_filter_count');
  await _scrollToReviewControl(tester, key);
  final finder = find.byKey(key);
  expect(tester.widget<Text>(finder).data, expected);
}

Future<void> _expectReviewLoading(WidgetTester tester) async {
  const key = Key('operations_review_filter_count');
  await _scrollToReviewControl(tester, key, settle: false);
  expect(tester.widget<Text>(find.byKey(key)).data, 'Loading review issues...');
}

Future<void> _expectReviewTextVisible(WidgetTester tester, String text) async {
  final finder = find.textContaining(text);
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(finder, findsOneWidget);
}

Future<void> _expectReviewSelectionCount(
  WidgetTester tester, {
  required int selected,
  required int visible,
}) async {
  const key = Key('operations_review_selection_count');
  await _scrollToReviewControl(tester, key);
  expect(
    tester.widget<Text>(find.byKey(key)).data,
    'Selected $selected of $visible visible review issues',
  );
}

Future<void> _expectReviewIssueSelected(
  WidgetTester tester,
  String issueId,
  Matcher expected,
) async {
  final key = Key('operations_review_issue_select_$issueId');
  await _scrollToReviewControl(tester, key);
  expect(tester.widget<Checkbox>(find.byKey(key)).value, expected);
}

Future<void> _selectReviewIssue(
  WidgetTester tester,
  MergeReviewIssue issue,
) async {
  await _tapReviewControl(
    tester,
    Key('operations_review_issue_select_${issue.id}'),
  );
}

Key _reviewWorklistStatusKey(String issueId) =>
    Key('operations_review_issue_worklist_status_$issueId');

Key _reviewWorklistInventoryItemKey(String issueId) =>
    Key('operations_review_worklist_inventory_item_$issueId');

Future<void> _openReviewWorklistInventory(WidgetTester tester) async {
  const toggleKey = Key('operations_review_worklist_inventory_toggle');
  const countKey = Key('operations_review_worklist_inventory_count');
  await _scrollToReviewControl(tester, toggleKey);
  if (find.byKey(countKey).evaluate().isEmpty) {
    await tester.tap(find.byKey(toggleKey));
    await tester.pumpAndSettle();
  }
}

Future<void> _expectReviewWorklistInventoryCount(
  WidgetTester tester,
  String expected, {
  bool settle = true,
}) async {
  const countKey = Key('operations_review_worklist_inventory_count');
  if (find.byKey(countKey).evaluate().isEmpty) {
    await _openReviewWorklistInventory(tester);
  }
  await _scrollToReviewControl(tester, countKey, settle: settle);
  expect(tester.widget<Text>(find.byKey(countKey)).data, expected);
}

Future<void> _expectReviewWorklistInventoryFilterSelected(
  WidgetTester tester,
  Key key,
  bool selected, {
  bool settle = true,
}) async {
  await _scrollToReviewControl(tester, key, settle: settle);
  expect(tester.widget<ChoiceChip>(find.byKey(key)).selected, selected);
}

Future<void> _enterReviewWorklistInventorySearch(
  WidgetTester tester,
  String query,
) async {
  const searchKey = Key('operations_review_worklist_inventory_search');
  await _scrollToReviewControl(tester, searchKey);
  await tester.enterText(find.byKey(searchKey), query);
  await tester.pumpAndSettle();
}

Future<void> _expectReviewWorklistStatus(
  WidgetTester tester,
  MergeReviewIssue issue,
  String status,
) async {
  final key = _reviewWorklistStatusKey(issue.id);
  await _scrollToReviewControl(tester, key);
  expect(
    find.descendant(of: find.byKey(key), matching: find.text(status)),
    findsOneWidget,
  );
}

void _expectReviewWorklistActionEnabled(
  WidgetTester tester,
  Key key,
  bool enabled,
) {
  final button = tester.widget<ButtonStyleButton>(find.byKey(key));
  expect(button.onPressed, enabled ? isNotNull : isNull);
}

void _expectReviewContextControlsEnabled(
  WidgetTester tester, {
  required bool enabled,
}) {
  final callbackMatcher = enabled ? isNotNull : isNull;
  for (final key in const [
    Key('operations_review_severity_filter'),
    Key('operations_review_type_filter'),
  ]) {
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
    );
    expect(dropdown.onChanged, callbackMatcher);
  }
  for (final key in const [
    Key('operations_review_saved_view_save'),
    Key('operations_review_page_next'),
    Key('operations_review_filter_clear'),
  ]) {
    _expectReviewWorklistActionEnabled(tester, key, enabled);
  }
  final savedViewChip = tester.widget<InputChip>(
    find.byKey(const Key('operations_review_saved_view_held-write-view')),
  );
  expect(savedViewChip.onSelected, callbackMatcher);
  expect(savedViewChip.onDeleted, callbackMatcher);
  final refreshButton = tester.widget<IconButton>(
    find.widgetWithIcon(IconButton, Icons.refresh),
  );
  expect(refreshButton.onPressed, callbackMatcher);
}

Future<void> _expectReviewError(WidgetTester tester) async {
  final finder = find.byKey(const Key('operations_review_error'));
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  expect(finder, findsOneWidget);
  expect(
    find.textContaining('Could not refresh review issues'),
    findsOneWidget,
  );
}

Future<void> _tapReviewPager(WidgetTester tester, Key key) async {
  await _tapReviewControl(tester, key);
}

MergeReviewSavedView _savedReviewView({
  required String id,
  required String name,
  required MergeReviewFilter filter,
}) {
  return MergeReviewSavedView(
    id: id,
    name: name,
    filter: filter,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

List<MergeReviewIssue> _reviewIssues() {
  return [
    _reviewIssue(
      id: 'high-category',
      severity: MergeReviewSeverity.high,
      type: MergeReviewIssueType.categoryConflictCandidate,
      reason: 'HIGH_CATEGORY',
    ),
    _reviewIssue(
      id: 'warning-category',
      severity: MergeReviewSeverity.warning,
      type: MergeReviewIssueType.categoryConflictCandidate,
      reason: 'WARNING_CATEGORY',
    ),
    _reviewIssue(
      id: 'warning-reuse',
      severity: MergeReviewSeverity.warning,
      type: MergeReviewIssueType.lowConfidenceReuse,
      reason: 'WARNING_REUSE',
    ),
  ];
}

List<MergeReviewIssue> _backlogReviewIssues() {
  return [
    for (var index = 0; index < 101; index++)
      _reviewIssue(
        id: 'recent-high-$index',
        severity: MergeReviewSeverity.high,
        type: MergeReviewIssueType.categoryConflictCandidate,
        reason: 'RECENT_HIGH_$index',
        createdAt: DateTime.utc(2026, 1, 2).add(Duration(minutes: index)),
      ),
    _reviewIssue(
      id: 'backlog-target',
      severity: MergeReviewSeverity.warning,
      type: MergeReviewIssueType.lowConfidenceReuse,
      reason: 'BACKLOG_TARGET',
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  ];
}

MergeReviewIssue _reviewIssue({
  required String id,
  required MergeReviewSeverity severity,
  required MergeReviewIssueType type,
  required String reason,
  DateTime? createdAt,
}) {
  return MergeReviewIssue(
    id: id,
    canonicalFoodId: 'food-$id',
    sourceRecordId: 'source-$id',
    type: type,
    severity: severity,
    reason: reason,
    candidateSummary: 'candidate-$id',
    createdAt: createdAt ?? DateTime(2026),
  );
}

MergeReviewIssue _structuredReviewIssue({
  required String logicalKey,
  String? canonicalFoodId,
  String? sourceRecordId,
  String? subjectKey,
  String? reason,
  String? candidateSummary,
  String? suggestedCanonicalFoodId,
  MergeReviewIssueType type = MergeReviewIssueType.categoryConflictCandidate,
  MergeReviewSeverity severity = MergeReviewSeverity.warning,
  DateTime? createdAt,
}) {
  final canonical = canonicalFoodId ?? 'food-$logicalKey';
  final source = sourceRecordId ?? 'source-$logicalKey';
  final subject = subjectKey ?? 'subject-$logicalKey';
  final identity = MergeReviewIssueIdentity(
    canonicalFoodId: canonical,
    sourceRecordId: source,
    type: type,
    subjectKey: subject,
  );
  return MergeReviewIssue(
    id: identity.encode(),
    canonicalFoodId: canonical,
    sourceRecordId: source,
    type: type,
    severity: severity,
    reason: reason ?? 'STRUCTURED_$logicalKey',
    candidateSummary: candidateSummary ?? 'candidate-$logicalKey',
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    suggestedCanonicalFoodId: suggestedCanonicalFoodId,
  );
}

FetchJobEntry _fetchJob({
  required String id,
  required String message,
  String status = 'success',
}) {
  return FetchJobEntry(
    id: id,
    query: 'isolation',
    phase: 'foreground',
    status: status,
    importerId: 'usda',
    startedAt: DateTime.utc(2026, 1, 1),
    finishedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
    message: message,
  );
}

Future<void> _dragUntilText(WidgetTester tester, String text) async {
  for (var i = 0; i < 8; i++) {
    if (find.textContaining(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
  }
}

class _NoopImporter extends FoodImporter {
  @override
  String get id => 'usda';

  @override
  String get displayName => 'USDA FoodData Central';

  @override
  String get country => 'United States';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    return const [];
  }
}

class _ReviewIssueRepository extends MemoryFoodRepository {
  _ReviewIssueRepository(this._reviewIssues);

  final List<MergeReviewIssue> _reviewIssues;
  List<MergeReviewIssue> get reviewIssues => _reviewIssues;
  final List<MergeReviewIssueQuery> queries = [];
  final List<({String key, String value})> appMetaWrites = [];
  int recentFetchJobsReadCount = 0;
  int datasetArtifactsReadCount = 0;
  int importLogsReadCount = 0;
  int exportHistoryReadCount = 0;
  int governanceLogsReadCount = 0;
  int mergeSourceRecordCallCount = 0;
  int splitSourceRecordCallCount = 0;
  int overrideCanonicalFoodCallCount = 0;

  int get governanceMutationCount =>
      mergeSourceRecordCallCount +
      splitSourceRecordCallCount +
      overrideCanonicalFoodCallCount;

  ({int jobs, int artifacts, int logs, int exports, int governance})
  get operationsReadCounts => (
    jobs: recentFetchJobsReadCount,
    artifacts: datasetArtifactsReadCount,
    logs: importLogsReadCount,
    exports: exportHistoryReadCount,
    governance: governanceLogsReadCount,
  );

  @override
  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    String? importerId,
    String? status,
    int limit = 20,
  }) async {
    recentFetchJobsReadCount += 1;
    return super.getRecentFetchJobs(
      query: query,
      phase: phase,
      importerId: importerId,
      status: status,
      limit: limit,
    );
  }

  @override
  Future<List<DatasetArtifactEntry>> getDatasetArtifacts({
    int limit = 50,
  }) async {
    datasetArtifactsReadCount += 1;
    return super.getDatasetArtifacts(limit: limit);
  }

  @override
  Future<List<ImportLogEntry>> getImportLogs({int limit = 20}) async {
    importLogsReadCount += 1;
    return super.getImportLogs(limit: limit);
  }

  @override
  Future<List<ExportHistoryEntry>> getExportHistory({int limit = 20}) async {
    exportHistoryReadCount += 1;
    return super.getExportHistory(limit: limit);
  }

  @override
  Future<List<ManualGovernanceLogEntry>> getManualGovernanceLogs({
    int limit = 50,
  }) async {
    governanceLogsReadCount += 1;
    return super.getManualGovernanceLogs(limit: limit);
  }

  @override
  Future<List<MergeReviewIssue>> getMergeReviewIssues({int limit = 100}) async {
    return _reviewIssues.take(limit).toList(growable: false);
  }

  @override
  Future<MergeReviewIssuePage> queryMergeReviewIssues(
    MergeReviewIssueQuery query,
  ) async {
    queries.add(query);
    return MergeReviewIssuePage.fromIssues(issues: _reviewIssues, query: query);
  }

  @override
  Future<void> mergeSourceRecord({
    required String sourceRecordId,
    required String targetCanonicalFoodId,
    required String note,
  }) async {
    mergeSourceRecordCallCount += 1;
  }

  @override
  Future<void> splitSourceRecord({
    required String sourceRecordId,
    required String note,
  }) async {
    splitSourceRecordCallCount += 1;
  }

  @override
  Future<void> overrideCanonicalFood({
    required String canonicalFoodId,
    required CanonicalOverrideFields fields,
    required String note,
  }) async {
    overrideCanonicalFoodCallCount += 1;
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    appMetaWrites.add((key: key, value: value));
    await super.setAppMeta(key, value);
  }
}

class _PendingReviewQuery {
  _PendingReviewQuery(this.query, this.completer);

  final MergeReviewIssueQuery query;
  final Completer<MergeReviewIssuePage> completer;
}

class _PendingWorklistWrite {
  _PendingWorklistWrite(this.value, this.completer);

  final String value;
  final Completer<void> completer;
}

class _ControlledReviewIssueRepository extends _ReviewIssueRepository {
  _ControlledReviewIssueRepository(super.reviewIssues);

  bool holdReviewQueries = false;
  final List<_PendingReviewQuery> pendingReviewQueries = [];

  @override
  Future<MergeReviewIssuePage> queryMergeReviewIssues(
    MergeReviewIssueQuery query,
  ) {
    if (!holdReviewQueries) {
      return super.queryMergeReviewIssues(query);
    }
    queries.add(query);
    final pending = _PendingReviewQuery(
      query,
      Completer<MergeReviewIssuePage>(),
    );
    pendingReviewQueries.add(pending);
    return pending.completer.future;
  }

  void completeReviewQuery(int index) {
    final pending = pendingReviewQueries[index];
    pending.completer.complete(
      MergeReviewIssuePage.fromIssues(
        issues: reviewIssues,
        query: pending.query,
      ),
    );
  }

  void completeReviewQueryWithPage(int index, MergeReviewIssuePage page) {
    final pending = pendingReviewQueries[index];
    assert(page.offset == pending.query.offset);
    assert(page.limit == pending.query.limit);
    pending.completer.complete(page);
  }

  void failReviewQuery(
    int index, {
    String message = 'simulated controlled review failure',
  }) {
    pendingReviewQueries[index].completer.completeError(StateError(message));
  }
}

class _ControlledSavedViewMutationRepository
    extends _ControlledReviewIssueRepository {
  _ControlledSavedViewMutationRepository(super.reviewIssues);

  bool failSavedViewWrites = false;
  int savedViewWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failSavedViewWrites && key == MergeReviewSavedViewStore.metaKey) {
      savedViewWriteAttempts += 1;
      throw StateError('simulated saved-view deletion write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _ControlledSavedViewReadFailureRepository
    extends _ControlledReviewIssueRepository {
  _ControlledSavedViewReadFailureRepository(super.reviewIssues);

  bool failSavedViewReads = false;
  int savedViewReadAttempts = 0;
  int savedViewReadCallCount = 0;

  @override
  Future<String?> getAppMeta(String key) async {
    if (key == MergeReviewSavedViewStore.metaKey) {
      savedViewReadCallCount += 1;
      if (failSavedViewReads) {
        savedViewReadAttempts += 1;
        throw StateError('simulated saved-view metadata read failure');
      }
    }
    return super.getAppMeta(key);
  }
}

class _ControlledSavedViewMutationReadFailureRepository
    extends _ControlledSavedViewReadFailureRepository {
  _ControlledSavedViewMutationReadFailureRepository(super.reviewIssues);

  bool failSavedViewWrites = false;
  int savedViewWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failSavedViewWrites && key == MergeReviewSavedViewStore.metaKey) {
      savedViewWriteAttempts += 1;
      throw StateError('simulated saved-view deletion write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _ControlledSavedViewWriteSavedViewReadFailureRepository
    extends _ControlledSavedViewReadFailureRepository {
  _ControlledSavedViewWriteSavedViewReadFailureRepository(super.reviewIssues);

  bool holdSavedViewWrites = false;
  final List<_PendingSavedViewWrite> pendingSavedViewWrites = [];

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (holdSavedViewWrites && key == MergeReviewSavedViewStore.metaKey) {
      final pending = _PendingSavedViewWrite(value);
      pendingSavedViewWrites.add(pending);
      await pending.completer.future;
    }
    await super.setAppMeta(key, value);
  }

  void completeSavedViewWrite(int index) {
    holdSavedViewWrites = false;
    pendingSavedViewWrites[index].completer.complete();
  }
}

class _PendingSavedViewWrite {
  _PendingSavedViewWrite(this.value);

  final String value;
  final Completer<void> completer = Completer<void>();
}

class _ControlledFilterWriteFailureSavedViewReadFailureRepository
    extends _ControlledSavedViewReadFailureRepository {
  _ControlledFilterWriteFailureSavedViewReadFailureRepository(
    super.reviewIssues,
  );

  bool failReviewFilterWrites = false;
  int reviewFilterWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failReviewFilterWrites && key == 'merge_review_filter_v1') {
      reviewFilterWriteAttempts += 1;
      throw StateError('simulated review filter write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _ControlledFilterWriteSavedViewReadFailureRepository
    extends _ControlledSavedViewReadFailureRepository {
  _ControlledFilterWriteSavedViewReadFailureRepository(super.reviewIssues);

  bool holdReviewFilterWrites = false;
  final List<_PendingReviewFilterWrite> pendingReviewFilterWrites = [];

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (holdReviewFilterWrites && key == 'merge_review_filter_v1') {
      final pending = _PendingReviewFilterWrite(value);
      pendingReviewFilterWrites.add(pending);
      await pending.completer.future;
    }
    await super.setAppMeta(key, value);
  }

  void completeReviewFilterWrite(int index) {
    holdReviewFilterWrites = false;
    pendingReviewFilterWrites[index].completer.complete();
  }
}

class _ControlledFilterWriteSavedViewMutationReadFailureRepository
    extends _ControlledFilterWriteSavedViewReadFailureRepository {
  _ControlledFilterWriteSavedViewMutationReadFailureRepository(
    super.reviewIssues,
  );

  bool failSavedViewWrites = false;
  int savedViewWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failSavedViewWrites && key == MergeReviewSavedViewStore.metaKey) {
      savedViewWriteAttempts += 1;
      throw StateError('simulated saved-view save write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _ControlledFilterWriteFailureAfterSavedViewReadFailureRepository
    extends _ControlledFilterWriteSavedViewReadFailureRepository {
  _ControlledFilterWriteFailureAfterSavedViewReadFailureRepository(
    super.reviewIssues,
  );

  bool failReviewFilterWritesAfterRelease = false;
  int reviewFilterWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'merge_review_filter_v1' && holdReviewFilterWrites) {
      final pending = _PendingReviewFilterWrite(value);
      pendingReviewFilterWrites.add(pending);
      await pending.completer.future;
      if (failReviewFilterWritesAfterRelease) {
        reviewFilterWriteAttempts += 1;
        throw StateError('simulated review filter write failure');
      }
      await super.setAppMeta(key, value);
      return;
    }
    if (key == 'merge_review_filter_v1' && failReviewFilterWritesAfterRelease) {
      reviewFilterWriteAttempts += 1;
      throw StateError('simulated review filter write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _ControlledFilterFailureThenSuccessSavedViewWriteRepository
    extends _ControlledSavedViewWriteSavedViewReadFailureRepository {
  _ControlledFilterFailureThenSuccessSavedViewWriteRepository(
    super.reviewIssues,
  );

  bool holdReviewFilterWrites = false;
  bool failNextReviewFilterWriteOnRelease = false;
  int reviewFilterWriteAttempts = 0;
  final List<_PendingReviewFilterWrite> pendingReviewFilterWrites = [];

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'merge_review_filter_v1' && holdReviewFilterWrites) {
      final pending = _PendingReviewFilterWrite(value);
      pendingReviewFilterWrites.add(pending);
      await pending.completer.future;
      if (failNextReviewFilterWriteOnRelease) {
        failNextReviewFilterWriteOnRelease = false;
        reviewFilterWriteAttempts += 1;
        throw StateError('simulated review filter write failure');
      }
      await super.setAppMeta(key, value);
      return;
    }
    if (key == 'merge_review_filter_v1' && failNextReviewFilterWriteOnRelease) {
      failNextReviewFilterWriteOnRelease = false;
      reviewFilterWriteAttempts += 1;
      throw StateError('simulated review filter write failure');
    }
    await super.setAppMeta(key, value);
  }

  void completeReviewFilterWrite(int index) {
    holdReviewFilterWrites = false;
    pendingReviewFilterWrites[index].completer.complete();
  }
}

class _ControlledFilterFailureThenSavedViewMutationFailureRepository
    extends _ControlledFilterFailureThenSuccessSavedViewWriteRepository {
  _ControlledFilterFailureThenSavedViewMutationFailureRepository(
    super.reviewIssues,
  );

  bool failSavedViewWrites = false;
  int savedViewWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failSavedViewWrites && key == MergeReviewSavedViewStore.metaKey) {
      savedViewWriteAttempts += 1;
      throw StateError('simulated saved-view deletion write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _PendingReviewFilterWrite {
  _PendingReviewFilterWrite(this.value);

  final String value;
  final Completer<void> completer = Completer<void>();
}

class _ControlledWorklistWriteRepository extends _ReviewIssueRepository {
  _ControlledWorklistWriteRepository(super.reviewIssues);

  bool holdWorklistWrites = false;
  int worklistReadCount = 0;
  final List<_PendingWorklistWrite> pendingWorklistWrites = [];

  @override
  Future<String?> getAppMeta(String key) {
    if (key == MergeReviewWorklistStore.metaKey) {
      worklistReadCount += 1;
    }
    return super.getAppMeta(key);
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (holdWorklistWrites && key == MergeReviewWorklistStore.metaKey) {
      final pending = _PendingWorklistWrite(value, Completer<void>());
      pendingWorklistWrites.add(pending);
      await pending.completer.future;
    }
    await super.setAppMeta(key, value);
  }

  void completeWorklistWrite(int index) {
    holdWorklistWrites = false;
    pendingWorklistWrites[index].completer.complete();
  }
}

class _ControlledWorklistReadRepository extends _ReviewIssueRepository {
  _ControlledWorklistReadRepository(super.reviewIssues);

  bool holdWorklistReads = false;
  bool failNextWorklistRead = false;
  int worklistReadCount = 0;
  int worklistReadFailures = 0;
  final List<Completer<String?>> pendingWorklistReads = [];

  @override
  Future<String?> getAppMeta(String key) {
    if (key != MergeReviewWorklistStore.metaKey) {
      return super.getAppMeta(key);
    }
    worklistReadCount += 1;
    if (failNextWorklistRead) {
      failNextWorklistRead = false;
      worklistReadFailures += 1;
      return Future<String?>.error(
        StateError('simulated controlled worklist read failure'),
      );
    }
    if (!holdWorklistReads) {
      return super.getAppMeta(key);
    }
    final pending = Completer<String?>();
    pendingWorklistReads.add(pending);
    return pending.future;
  }

  Future<void> completeWorklistRead(int index) async {
    holdWorklistReads = false;
    final value = await super.getAppMeta(MergeReviewWorklistStore.metaKey);
    pendingWorklistReads[index].complete(value);
  }
}

class _ControlledSavedViewReadRepository extends _ReviewIssueRepository {
  _ControlledSavedViewReadRepository(super.reviewIssues);

  bool holdSavedViewReads = false;
  final List<Completer<String?>> pendingSavedViewReads = [];

  @override
  Future<String?> getAppMeta(String key) {
    if (!holdSavedViewReads || key != MergeReviewSavedViewStore.metaKey) {
      return super.getAppMeta(key);
    }
    final pending = Completer<String?>();
    pendingSavedViewReads.add(pending);
    return pending.future;
  }

  void completeSavedViewRead(int index) {
    holdSavedViewReads = false;
    pendingSavedViewReads[index].complete(null);
  }
}

class _ControlledGovernanceRepository extends _ReviewIssueRepository {
  _ControlledGovernanceRepository(super.reviewIssues);

  bool holdSplitActions = false;
  final List<Completer<void>> pendingSplitActions = [];

  @override
  Future<void> splitSourceRecord({
    required String sourceRecordId,
    required String note,
  }) async {
    splitSourceRecordCallCount += 1;
    if (!holdSplitActions) {
      return;
    }
    final pending = Completer<void>();
    pendingSplitActions.add(pending);
    await pending.future;
  }

  void completeSplitAction(int index) {
    holdSplitActions = false;
    pendingSplitActions[index].complete();
  }
}

class _FailOnceReviewIssueRepository extends _ReviewIssueRepository {
  _FailOnceReviewIssueRepository(super.reviewIssues);

  bool failNextReviewQuery = false;

  @override
  Future<MergeReviewIssuePage> queryMergeReviewIssues(
    MergeReviewIssueQuery query,
  ) async {
    if (failNextReviewQuery) {
      failNextReviewQuery = false;
      queries.add(query);
      throw StateError('simulated review read failure');
    }
    return super.queryMergeReviewIssues(query);
  }
}

class _FailOnceWorklistWriteRepository extends _ReviewIssueRepository {
  _FailOnceWorklistWriteRepository(super.reviewIssues);

  bool failNextWorklistWrite = false;
  int worklistWriteFailures = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (failNextWorklistWrite && key == MergeReviewWorklistStore.metaKey) {
      failNextWorklistWrite = false;
      worklistWriteFailures += 1;
      throw StateError('simulated worklist write failure');
    }
    await super.setAppMeta(key, value);
  }
}

class _FailOnceWorklistReadRepository extends _ReviewIssueRepository {
  _FailOnceWorklistReadRepository(super.reviewIssues);

  bool failNextWorklistRead = false;
  int worklistReadFailures = 0;

  @override
  Future<String?> getAppMeta(String key) async {
    if (failNextWorklistRead && key == MergeReviewWorklistStore.metaKey) {
      failNextWorklistRead = false;
      worklistReadFailures += 1;
      throw StateError('simulated worklist read failure');
    }
    return super.getAppMeta(key);
  }
}

class _FailOnceOperationsRepository extends _ReviewIssueRepository {
  _FailOnceOperationsRepository(super.reviewIssues);

  bool failNextOperationsRead = false;

  @override
  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    String? importerId,
    String? status,
    int limit = 20,
  }) async {
    if (failNextOperationsRead) {
      failNextOperationsRead = false;
      recentFetchJobsReadCount += 1;
      throw StateError('simulated operations read failure');
    }
    return super.getRecentFetchJobs(
      query: query,
      phase: phase,
      importerId: importerId,
      status: status,
      limit: limit,
    );
  }
}

class _FailingFetchJobRepository extends _ReviewIssueRepository {
  _FailingFetchJobRepository(super.reviewIssues);

  bool failFetchJobWrites = false;
  int fetchJobWriteAttempts = 0;
  final List<String> attemptedFetchJobStatuses = [];

  @override
  Future<void> upsertFetchJob(FetchJobEntry entry) async {
    fetchJobWriteAttempts += 1;
    attemptedFetchJobStatuses.add(entry.status);
    if (failFetchJobWrites) {
      throw StateError('simulated fetch-job write failure');
    }
    await super.upsertFetchJob(entry);
  }
}
