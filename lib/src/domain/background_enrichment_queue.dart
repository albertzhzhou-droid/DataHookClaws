import 'dart:async';

import '../models/enrichment_job.dart';
import '../models/enrichment_queue_state.dart';
import '../models/fetch_job_entry.dart';
import '../models/import_models.dart';
import 'sync_food_catalog_use_case.dart';

class BackgroundEnrichmentQueue {
  BackgroundEnrichmentQueue({required SyncFoodCatalogUseCase syncUseCase})
    : _syncUseCase = syncUseCase;

  final SyncFoodCatalogUseCase _syncUseCase;
  final StreamController<EnrichmentQueueState> _stateController =
      StreamController<EnrichmentQueueState>.broadcast();

  EnrichmentQueueState _currentState = EnrichmentQueueState.idle();
  EnrichmentJob? _runningJob;
  EnrichmentJob? _queuedJob;
  bool _cancelRunningAfterCurrentSource = false;
  Future<void> Function(FetchJobEntry entry)? _persistJob;

  Stream<EnrichmentQueueState> get states async* {
    yield _currentState;
    yield* _stateController.stream;
  }

  EnrichmentQueueState get currentState => _currentState;

  Future<void> schedule({
    required String query,
    required String normalizedQuery,
    required List<String> importerIds,
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry entry) persistJob,
  }) async {
    _persistJob = persistJob;
    final dedupedImporters = <String>[];
    for (final importerId in importerIds) {
      if (!dedupedImporters.contains(importerId)) {
        dedupedImporters.add(importerId);
      }
    }
    if (dedupedImporters.isEmpty) {
      _emit(
        EnrichmentQueueState(
          activeQuery: query,
          status: EnrichmentStatus.completed,
          activeSources: const [],
          lastMessage: 'No remaining sources to enrich.',
        ),
      );
      return;
    }

    if (_runningJob?.normalizedQuery == normalizedQuery ||
        _queuedJob?.normalizedQuery == normalizedQuery) {
      return;
    }

    final job = EnrichmentJob(
      id: 'enrichment-${DateTime.now().microsecondsSinceEpoch}',
      query: query,
      normalizedQuery: normalizedQuery,
      remainingImporterIds: dedupedImporters,
      status: 'queued',
      createdAt: DateTime.now(),
      startedAt: null,
      finishedAt: null,
      message: 'Background enrichment queued.',
    );

    await _persistQueuedJobs(
      job: job,
      persistJob: persistJob,
      importerIds: dedupedImporters,
    );

    if (_queuedJob != null) {
      await _cancelQueuedJob(_queuedJob!, persistJob);
      _queuedJob = null;
    }

    if (_runningJob != null) {
      _cancelRunningAfterCurrentSource = true;
      _queuedJob = job;
      return;
    }

    await _runJob(
      job,
      limitPerImporter: limitPerImporter,
      persistJob: persistJob,
    );
  }

  Future<void> cancel(String query) async {
    if (_queuedJob?.query == query) {
      if (_persistJob != null) {
        await _cancelQueuedJob(_queuedJob!, _persistJob!);
      }
      _queuedJob = null;
      if (_runningJob == null) {
        _emit(EnrichmentQueueState.idle());
      }
    }

    if (_runningJob?.query == query) {
      _cancelRunningAfterCurrentSource = true;
    }
  }

  Future<void> dispose() async {
    await _stateController.close();
  }

  Future<void> _runJob(
    EnrichmentJob job, {
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry entry) persistJob,
  }) async {
    _runningJob = job.copyWith(status: 'running', startedAt: DateTime.now());
    var successCount = 0;
    var failureCount = 0;
    var lastMessage = 'Background enrichment started.';
    final remaining = List<String>.from(job.remainingImporterIds);

    while (remaining.isNotEmpty) {
      final importerId = remaining.removeAt(0);
      final startedAt = DateTime.now();
      _emit(
        EnrichmentQueueState(
          activeQuery: job.query,
          status: EnrichmentStatus.enriching,
          activeSources: [importerId],
          lastMessage: 'Enriching related official data.',
        ),
      );

      await persistJob(
        FetchJobEntry(
          id: _fetchJobId(job.id, importerId),
          query: job.query,
          phase: 'enrichment',
          status: 'running',
          importerId: importerId,
          startedAt: startedAt,
          finishedAt: null,
          message: 'Background enrichment started.',
        ),
      );

      try {
        final summary = await _syncUseCase.syncSource(
          importerId: importerId,
          request: ImportRequest(
            query: job.normalizedQuery,
            limit: limitPerImporter,
          ),
        );
        successCount += 1;
        lastMessage = summary.message;
        await persistJob(
          FetchJobEntry(
            id: _fetchJobId(job.id, importerId),
            query: job.query,
            phase: 'enrichment',
            status: 'success',
            importerId: importerId,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            message: summary.message,
          ),
        );
        _emit(
          EnrichmentQueueState(
            activeQuery: job.query,
            status: EnrichmentStatus.enriching,
            activeSources: [importerId],
            lastMessage: summary.message,
          ),
        );
      } catch (error) {
        failureCount += 1;
        lastMessage = '$error';
        await persistJob(
          FetchJobEntry(
            id: _fetchJobId(job.id, importerId),
            query: job.query,
            phase: 'enrichment',
            status: 'failure',
            importerId: importerId,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            message: '$error',
          ),
        );
      }

      if (_cancelRunningAfterCurrentSource) {
        await _cancelRemainingJobs(job, remaining, persistJob);
        _cancelRunningAfterCurrentSource = false;
        _runningJob = null;
        final nextJob = _queuedJob;
        _queuedJob = null;
        if (nextJob == null) {
          _emit(EnrichmentQueueState.idle());
          return;
        }
        await _runJob(
          nextJob,
          limitPerImporter: limitPerImporter,
          persistJob: persistJob,
        );
        return;
      }
    }

    _runningJob = null;
    if (successCount > 0) {
      _emit(
        EnrichmentQueueState(
          activeQuery: job.query,
          status: EnrichmentStatus.completed,
          activeSources: const [],
          lastMessage: lastMessage,
        ),
      );
    } else if (failureCount > 0) {
      _emit(
        EnrichmentQueueState(
          activeQuery: job.query,
          status: EnrichmentStatus.failed,
          activeSources: const [],
          lastMessage: lastMessage,
        ),
      );
    } else {
      _emit(EnrichmentQueueState.idle());
    }

    final nextJob = _queuedJob;
    _queuedJob = null;
    if (nextJob != null) {
      await _runJob(
        nextJob,
        limitPerImporter: limitPerImporter,
        persistJob: persistJob,
      );
    }
  }

  Future<void> _persistQueuedJobs({
    required EnrichmentJob job,
    required Future<void> Function(FetchJobEntry entry) persistJob,
    required List<String> importerIds,
  }) async {
    for (final importerId in importerIds) {
      await persistJob(
        FetchJobEntry(
          id: _fetchJobId(job.id, importerId),
          query: job.query,
          phase: 'enrichment',
          status: 'queued',
          importerId: importerId,
          startedAt: job.createdAt,
          finishedAt: null,
          message: 'Background enrichment queued.',
        ),
      );
    }
  }

  Future<void> _cancelQueuedJob(
    EnrichmentJob job,
    Future<void> Function(FetchJobEntry entry) persistJob,
  ) async {
    for (final importerId in job.remainingImporterIds) {
      await persistJob(
        FetchJobEntry(
          id: _fetchJobId(job.id, importerId),
          query: job.query,
          phase: 'enrichment',
          status: 'cancelled',
          importerId: importerId,
          startedAt: job.createdAt,
          finishedAt: DateTime.now(),
          message: 'Background enrichment cancelled before execution.',
        ),
      );
    }
  }

  Future<void> _cancelRemainingJobs(
    EnrichmentJob job,
    List<String> remaining,
    Future<void> Function(FetchJobEntry entry) persistJob,
  ) async {
    for (final importerId in remaining) {
      await persistJob(
        FetchJobEntry(
          id: _fetchJobId(job.id, importerId),
          query: job.query,
          phase: 'enrichment',
          status: 'cancelled',
          importerId: importerId,
          startedAt: job.createdAt,
          finishedAt: DateTime.now(),
          message: 'Background enrichment cancelled after current source.',
        ),
      );
    }
  }

  String _fetchJobId(String jobId, String importerId) {
    return '$jobId:$importerId';
  }

  void _emit(EnrichmentQueueState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
