import '../models/fetch_job_entry.dart';
import '../models/food_item.dart';
import '../models/import_models.dart';
import 'sync_food_catalog_use_case.dart';

class ForegroundFetchRunner {
  const ForegroundFetchRunner({required SyncFoodCatalogUseCase syncUseCase})
    : _syncUseCase = syncUseCase;

  final SyncFoodCatalogUseCase _syncUseCase;

  Future<ForegroundFetchResult> run({
    required String query,
    required List<String> importerIds,
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry job) persistJob,
  }) async {
    final imported = <FoodItem>[];
    final succeededSources = <String>[];

    for (final importerId in importerIds) {
      final jobId =
          'fetch-$importerId-${DateTime.now().microsecondsSinceEpoch}';
      final startedAt = DateTime.now();
      await persistJob(
        FetchJobEntry(
          id: jobId,
          query: query,
          phase: 'foreground',
          status: 'running',
          importerId: importerId,
          startedAt: startedAt,
          finishedAt: null,
          message: 'Foreground fetch started.',
        ),
      );

      try {
        final summary = await _syncUseCase.syncSource(
          importerId: importerId,
          request: ImportRequest(query: query, limit: limitPerImporter),
        );
        imported.addAll(summary.importedFoods);
        succeededSources.add(importerId);
        await persistJob(
          FetchJobEntry(
            id: jobId,
            query: query,
            phase: 'foreground',
            status: 'success',
            importerId: importerId,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            message: summary.message,
          ),
        );
      } catch (error) {
        await persistJob(
          FetchJobEntry(
            id: jobId,
            query: query,
            phase: 'foreground',
            status: 'failure',
            importerId: importerId,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            message: '$error',
          ),
        );
      }
    }

    return ForegroundFetchResult(
      importedFoods: imported,
      succeededSources: succeededSources,
    );
  }
}

class ForegroundFetchResult {
  const ForegroundFetchResult({
    required this.importedFoods,
    required this.succeededSources,
  });

  final List<FoodItem> importedFoods;
  final List<String> succeededSources;
}
