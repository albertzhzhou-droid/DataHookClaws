import '../data/official_dataset_grabber.dart';
import '../data/food_repository.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/food_item.dart';
import 'normalization/food_record_normalizer.dart';
import '../importers/food_importer.dart';
import '../models/import_log_entry.dart';
import '../models/import_models.dart';

class SyncSummary extends ImportResult {
  const SyncSummary({
    required super.importerId,
    required this.importedItems,
    required this.importedFoods,
    required super.message,
  }) : super(importedCount: importedItems);

  final int importedItems;
  final List<FoodItem> importedFoods;
}

class SyncFoodCatalogUseCase {
  const SyncFoodCatalogUseCase({
    required this.repository,
    required this.importers,
    required this.normalizer,
    this.datasetGrabber,
  });

  final FoodRepository repository;
  final List<FoodImporter> importers;
  final FoodRecordNormalizer normalizer;
  final OfficialDatasetGrabber? datasetGrabber;

  Future<SyncSummary> syncSource({
    required String importerId,
    required ImportRequest request,
  }) async {
    final importer = importers
        .where((candidate) => candidate.id == importerId)
        .first;
    try {
      final preparedRequest =
          await datasetGrabber?.prepareRequest(
            importerId: importerId,
            request: request,
          ) ??
          request;

      // Keep source ingestion and schema normalization separate so new
      // country importers can stay thin and focused on reading official data.
      final rawRecords = await importer.importFoods(preparedRequest);
      final foods = normalizer.normalizeBatch(
        importerId: importerId,
        records: rawRecords,
      );
      await repository.upsertFoods(foods);
      final datasetPath = preparedRequest.datasetPath?.trim();
      if (datasetPath != null && datasetPath.isNotEmpty) {
        await _upsertDatasetArtifactBestEffort(
          DatasetArtifactEntry(
            id: 'artifact-$importerId',
            importerId: importerId,
            artifactType: 'dataset-path',
            localPath: datasetPath,
            sourceUrl: '',
            sourceVersion: '',
            fetchedAt: DateTime.now(),
            status: 'ready',
          ),
        );
      }

      final summary = SyncSummary(
        importerId: importerId,
        importedItems: foods.length,
        importedFoods: foods,
        message:
            'Imported ${foods.length} records from ${importer.displayName}.',
      );

      await _addImportLogBestEffort(
        ImportLogEntry(
          id: 'log-${DateTime.now().microsecondsSinceEpoch}',
          importerId: importerId,
          sourceName: importer.displayName,
          status: 'success',
          importedCount: foods.length,
          query: preparedRequest.query.trim(),
          message: summary.message,
          createdAt: DateTime.now(),
        ),
      );

      return summary;
    } catch (error) {
      final message = 'Import failed for ${importer.displayName}: $error';
      await _addImportLogBestEffort(
        ImportLogEntry(
          id: 'log-${DateTime.now().microsecondsSinceEpoch}',
          importerId: importerId,
          sourceName: importer.displayName,
          status: 'failure',
          importedCount: 0,
          query: request.query.trim(),
          message: message,
          createdAt: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  Future<void> _addImportLogBestEffort(ImportLogEntry entry) async {
    try {
      await repository.addImportLog(entry);
    } catch (_) {
      // Import success or the original import failure must not be masked by
      // supplemental diagnostics persistence.
    }
  }

  Future<void> _upsertDatasetArtifactBestEffort(
    DatasetArtifactEntry entry,
  ) async {
    try {
      await repository.upsertDatasetArtifact(entry);
    } catch (_) {
      // Artifact inventory is supplemental metadata; it must not mask a
      // normalized import that has already been committed.
    }
  }
}
