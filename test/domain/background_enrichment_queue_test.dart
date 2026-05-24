import 'dart:async';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/background_enrichment_queue.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/importers/food_importer.dart';
import 'package:data_hook_claws/src/models/enrichment_queue_state.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:data_hook_claws/src/models/raw_food_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'failure on one source does not stop later enrichment sources',
    () async {
      final repository = MemoryFoodRepository();
      final queue = BackgroundEnrichmentQueue(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: repository,
          normalizer: const FoodRecordNormalizer(),
          importers: [
            _FakeImporter(
              id: 'usda',
              displayName: 'USDA',
              onImport: (_) async => throw Exception('api unavailable'),
            ),
            _FakeImporter(
              id: 'canada-cnf',
              displayName: 'CNF',
              onImport: (request) async => [
                _record('canada-cnf', request.query),
              ],
            ),
          ],
        ),
      );

      final states = <EnrichmentQueueState>[];
      final subscription = queue.states.listen(states.add);
      addTearDown(subscription.cancel);

      await queue.schedule(
        query: 'salmon',
        normalizedQuery: 'salmon',
        importerIds: const ['usda', 'canada-cnf'],
        limitPerImporter: 20,
        persistJob: repository.upsertFetchJob,
      );

      final foods = await repository.searchFoods('salmon');
      final jobs = await repository.getRecentFetchJobs(
        query: 'salmon',
        phase: 'enrichment',
        limit: 10,
      );

      expect(foods, hasLength(1));
      expect(states.last.status, EnrichmentStatus.completed);
      expect(
        jobs.map((job) => job.status),
        containsAll(['failure', 'success']),
      );
    },
  );

  test('deduplicates the same queued query while a job is running', () async {
    final repository = MemoryFoodRepository();
    final blocker = Completer<void>();
    final queue = BackgroundEnrichmentQueue(
      syncUseCase: SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: [
          _FakeImporter(
            id: 'usda',
            displayName: 'USDA',
            onImport: (request) async {
              await blocker.future;
              return [_record('usda', request.query)];
            },
          ),
        ],
      ),
    );

    final firstRun = queue.schedule(
      query: 'salmon',
      normalizedQuery: 'salmon',
      importerIds: const ['usda'],
      limitPerImporter: 20,
      persistJob: repository.upsertFetchJob,
    );
    await Future<void>.delayed(Duration.zero);
    await queue.schedule(
      query: 'salmon',
      normalizedQuery: 'salmon',
      importerIds: const ['usda'],
      limitPerImporter: 20,
      persistJob: repository.upsertFetchJob,
    );
    blocker.complete();
    await firstRun;

    final jobs = await repository.getRecentFetchJobs(
      query: 'salmon',
      phase: 'enrichment',
      limit: 10,
    );
    expect(jobs, hasLength(1));
    expect(jobs.single.status, 'success');
  });

  test('new query cancels older queued enrichment before it starts', () async {
    final repository = MemoryFoodRepository();
    final blocker = Completer<void>();
    final queue = BackgroundEnrichmentQueue(
      syncUseCase: SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: [
          _FakeImporter(
            id: 'usda',
            displayName: 'USDA',
            onImport: (request) async {
              await blocker.future;
              return [_record('usda', request.query)];
            },
          ),
          _FakeImporter(
            id: 'canada-cnf',
            displayName: 'CNF',
            onImport: (request) async => [_record('canada-cnf', request.query)],
          ),
        ],
      ),
    );

    final salmonRun = queue.schedule(
      query: 'salmon',
      normalizedQuery: 'salmon',
      importerIds: const ['usda', 'canada-cnf'],
      limitPerImporter: 20,
      persistJob: repository.upsertFetchJob,
    );
    await Future<void>.delayed(Duration.zero);

    await queue.schedule(
      query: 'tofu',
      normalizedQuery: 'tofu',
      importerIds: const ['usda'],
      limitPerImporter: 20,
      persistJob: repository.upsertFetchJob,
    );
    await queue.schedule(
      query: 'oats',
      normalizedQuery: 'oats',
      importerIds: const ['canada-cnf'],
      limitPerImporter: 20,
      persistJob: repository.upsertFetchJob,
    );

    blocker.complete();
    await salmonRun;
    await Future<void>.delayed(Duration.zero);

    final tofuJobs = await repository.getRecentFetchJobs(
      query: 'tofu',
      phase: 'enrichment',
      limit: 10,
    );
    final oatsJobs = await repository.getRecentFetchJobs(
      query: 'oats',
      phase: 'enrichment',
      limit: 10,
    );

    expect(tofuJobs.single.status, 'cancelled');
    expect(oatsJobs.single.status, 'success');
  });
}

class _FakeImporter implements FoodImporter {
  _FakeImporter({
    required this.id,
    required this.displayName,
    required this.onImport,
  });

  @override
  final String id;

  @override
  final String displayName;

  final Future<List<RawFoodRecord>> Function(ImportRequest request) onImport;

  @override
  String get country => 'Test';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) {
    return onImport(request);
  }
}

RawFoodRecord _record(String importerId, String query) {
  return RawFoodRecord(
    sourceRecordId: '$importerId-$query',
    name: '$query ${importerId.split('-').first}',
    category: 'Test',
    country: 'Test',
    sourceName: importerId,
    description: '$query description',
    servingBasis: 'Per 100 g',
    tags: const ['tag'],
    nutrients: const [
      RawNutrientRecord(label: 'Protein', amount: 10, unit: 'g'),
    ],
    lastUpdated: DateTime(2026, 5, 23),
  );
}
