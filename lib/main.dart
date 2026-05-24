import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/api/food_catalog_export_service.dart';
import 'src/data/importer_registry.dart';
import 'src/data/sqlite_food_repository.dart';
import 'src/domain/background_enrichment_queue.dart';
import 'src/domain/fetch_budget_planner.dart';
import 'src/domain/foreground_fetch_runner.dart';
import 'src/data/official_dataset_grabber.dart';
import 'src/domain/normalization/food_record_normalizer.dart';
import 'src/domain/query_expansion_service.dart';
import 'src/domain/search_orchestrator.dart';
import 'src/domain/sync_food_catalog_use_case.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = SqliteFoodRepository();
  await repository.initialize();

  final syncUseCase = SyncFoodCatalogUseCase(
    repository: repository,
    normalizer: const FoodRecordNormalizer(),
    datasetGrabber: OfficialDatasetGrabber(),
    importers: buildIntegratedImporters(),
  );
  final searchOrchestrator = SearchOrchestrator(
    repository: repository,
    foregroundFetchRunner: ForegroundFetchRunner(syncUseCase: syncUseCase),
    budgetPlanner: const FetchBudgetPlanner(),
    queryExpansionService: QueryExpansionService(
      persistSuggestion: repository.addAiSuggestionLog,
    ),
    enrichmentQueue: BackgroundEnrichmentQueue(syncUseCase: syncUseCase),
  );
  final exportService = FoodCatalogExportService(repository: repository);

  runApp(
    DataHookClawsApp(
      repository: repository,
      syncUseCase: syncUseCase,
      searchOrchestrator: searchOrchestrator,
      exportService: exportService,
      importerDescriptors: importerDescriptors,
    ),
  );
}
