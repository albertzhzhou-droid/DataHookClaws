import 'package:flutter/material.dart';

import '../../data/food_repository.dart';
import '../../data/importer_registry.dart';
import '../../domain/export_share_service.dart';
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
import '../../models/merge_review_issue.dart';
import '../home/home_page.dart';

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
  List<FetchJobEntry> _jobs = const [];
  List<DatasetArtifactEntry> _artifacts = const [];
  List<ImportLogEntry> _logs = const [];
  List<MergeReviewIssue> _reviewIssues = const [];
  List<ExportHistoryEntry> _exportHistory = const [];
  List<ManualGovernanceLogEntry> _governanceLogs = const [];
  StorageBudgetSnapshot? _storageBudget;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    final jobs = await widget.repository.getRecentFetchJobs(limit: 50);
    final artifacts = await widget.repository.getDatasetArtifacts(limit: 50);
    final logs = await widget.repository.getImportLogs(limit: 100);
    final reviewIssues = await widget.repository.getMergeReviewIssues(
      limit: 100,
    );
    final exportHistory = await widget.repository.getExportHistory(limit: 20);
    final governanceLogs = await widget.repository.getManualGovernanceLogs(
      limit: 20,
    );
    final budget = await widget.storageBudgetManager.snapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _jobs = jobs;
      _artifacts = artifacts;
      _logs = logs;
      _reviewIssues = reviewIssues;
      _exportHistory = exportHistory;
      _governanceLogs = governanceLogs;
      _storageBudget = budget;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations'),
        actions: [
          IconButton(
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Open settings',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh operations data',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
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
                  count: _reviewIssues.length,
                ),
                const SizedBox(height: 8),
                if (_reviewIssues.isEmpty)
                  const _EmptyCard(
                    message: 'No merge or observation review issues found.',
                  )
                else
                  ..._reviewIssues.map(_buildReviewIssueCard),
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

  Widget _buildReviewIssueCard(MergeReviewIssue issue) {
    final canActOnSource = issue.sourceRecordId.isNotEmpty;
    final suggestedCanonicalId = issue.suggestedCanonicalFoodId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ListTile(
          leading: Icon(_severityIcon(issue.severity)),
          title: Text('${issue.type.name} / ${issue.severity.name}'),
          subtitle: Text(
            'Canonical: ${issue.canonicalFoodId}\n'
            'Source record: ${issue.sourceRecordId.isEmpty ? '(canonical-level)' : issue.sourceRecordId}\n'
            'Reason: ${issue.reason}\n'
            'Candidates: ${issue.candidateSummary}',
          ),
          isThreeLine: true,
          trailing: Wrap(
            spacing: 8,
            children: [
              if (canActOnSource && suggestedCanonicalId != null)
                FilledButton(
                  onPressed: () => _mergeIssueToCandidate(issue),
                  child: const Text('Merge candidate'),
                ),
              if (canActOnSource)
                OutlinedButton(
                  onPressed: () => _splitIssueSource(issue),
                  child: const Text('Split source'),
                ),
              OutlinedButton(
                onPressed: () => _overrideIssueCanonical(issue),
                child: const Text('Override'),
              ),
              FilledButton(
                onPressed: () => _showFoodDetails(issue.canonicalFoodId),
                child: const Text('Open details'),
              ),
            ],
          ),
        ),
      ),
    );
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
    await widget.repository.upsertFetchJob(
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
    try {
      final summary = await widget.syncUseCase.syncSource(
        importerId: job.importerId,
        request: ImportRequest(
          query: job.query,
          limit: descriptor.defaultLimit,
        ),
      );
      await widget.repository.upsertFetchJob(
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
      _message = 'Retry succeeded for ${job.importerId}.';
    } catch (error) {
      await widget.repository.upsertFetchJob(
        FetchJobEntry(
          id: retryId,
          query: job.query,
          phase: job.phase,
          status: 'failure',
          importerId: job.importerId,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          message: '$error',
        ),
      );
      _message = 'Retry failed for ${job.importerId}: $error';
    }
    await _refresh();
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
      _message = summary.message;
    } catch (error) {
      _message = 'Re-prepare failed for $importerId: $error';
    }
    await _refresh();
  }

  Future<void> _markArtifactRemoved(String id) async {
    await widget.repository.markDatasetArtifactRemoved(id);
    _message = 'Artifact marked removed. Local files were not deleted.';
    await _refresh();
  }

  Future<void> _mergeIssueToCandidate(MergeReviewIssue issue) async {
    final target = issue.suggestedCanonicalFoodId;
    if (target == null) {
      return;
    }
    try {
      await widget.repository.mergeSourceRecord(
        sourceRecordId: issue.sourceRecordId,
        targetCanonicalFoodId: target,
        note:
            'Manual merge from Operations review issue ${issue.id}: ${issue.reason}',
      );
      _message = 'Merged ${issue.sourceRecordId} into $target.';
    } catch (error) {
      _message = 'Manual merge failed: $error';
    }
    await _refresh();
  }

  Future<void> _splitIssueSource(MergeReviewIssue issue) async {
    try {
      await widget.repository.splitSourceRecord(
        sourceRecordId: issue.sourceRecordId,
        note:
            'Manual split from Operations review issue ${issue.id}: ${issue.reason}',
      );
      _message = 'Split ${issue.sourceRecordId} into a new canonical entry.';
    } catch (error) {
      _message = 'Manual split failed: $error';
    }
    await _refresh();
  }

  Future<void> _overrideIssueCanonical(MergeReviewIssue issue) async {
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
      _message = 'Canonical override saved for ${issue.canonicalFoodId}.';
    } catch (error) {
      _message = 'Canonical override failed: $error';
    }
    await _refresh();
  }

  Future<void> _shareExport(ExportHistoryEntry entry) async {
    try {
      await widget.exportShareService.shareFile(entry.path);
      _message = 'Share sheet opened for ${entry.path}.';
    } catch (error) {
      _message = 'Share failed: $error';
    }
    await _refresh();
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
