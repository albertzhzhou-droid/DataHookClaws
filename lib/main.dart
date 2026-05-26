import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/api/food_catalog_export_service.dart';
import 'src/data/importer_registry.dart';
import 'src/data/national_food_sources.dart';
import 'src/data/sqlite_food_repository.dart';
import 'src/domain/ai_assist_services.dart';
import 'src/domain/background_enrichment_queue.dart';
import 'src/domain/fetch_budget_planner.dart';
import 'src/domain/foreground_fetch_runner.dart';
import 'src/domain/model_budget_controller.dart';
import 'src/domain/ollama_client.dart';
import 'src/data/official_dataset_grabber.dart';
import 'src/domain/normalization/food_record_normalizer.dart';
import 'src/domain/query_expansion_service.dart';
import 'src/domain/search_orchestrator.dart';
import 'src/domain/export_share_service.dart';
import 'src/domain/settings_service.dart';
import 'src/domain/source_capability_registry.dart';
import 'src/domain/source_routing_service.dart';
import 'src/domain/storage_budget_manager.dart';
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
  final sourceCapabilities = SourceCapabilityRegistry(
    importerDescriptors: importerDescriptors,
    entities: nationalFoodEntities,
  );
  final settingsService = SettingsService(
    repository: repository,
    sourceCapabilities: sourceCapabilities,
  );
  final settings = await settingsService.load();
  final modelBudgetController = ModelBudgetController(
    maxCallsPerMinute: settings.modelMaxCallsPerMinute,
    timeout: Duration(seconds: settings.modelTimeoutSeconds),
    maxTokens: settings.modelMaxTokens,
  );
  final ollamaClient = OllamaClient(
    endpoint: settings.ollamaEndpoint,
    model: settings.ollamaModel,
    timeout: Duration(seconds: settings.modelTimeoutSeconds),
    numPredict: settings.modelMaxTokens,
  );
  final storageBudgetManager = StorageBudgetManager(
    repository: repository,
    limits: settings.storageLimits,
  );
  final sourceRoutingSuggestionService = SourceRoutingSuggestionService(
    persistSuggestion: repository.addAiSuggestionLog,
    ollamaClient: ollamaClient,
    modelBudgetController: modelBudgetController,
  );
  final exportSummaryService = ExportSummaryService(
    persistSuggestion: repository.addAiSuggestionLog,
    ollamaClient: ollamaClient,
    modelBudgetController: modelBudgetController,
  );
  final searchOrchestrator = SearchOrchestrator(
    repository: repository,
    foregroundFetchRunner: ForegroundFetchRunner(syncUseCase: syncUseCase),
    budgetPlanner: FetchBudgetPlanner(
      sourceRoutingService: SourceRoutingService(
        registry: sourceCapabilities,
        disabledSourceIds: settings.disabledSourceIds,
      ),
    ),
    queryExpansionService: QueryExpansionService(
      persistSuggestion: repository.addAiSuggestionLog,
      ollamaClient: ollamaClient,
      modelBudgetController: modelBudgetController,
    ),
    enrichmentQueue: BackgroundEnrichmentQueue(syncUseCase: syncUseCase),
    sourceRoutingSuggestionService: sourceRoutingSuggestionService,
  );
  final exportService = FoodCatalogExportService.withSettings(
    repository: repository,
    settingsService: settingsService,
    exportSummaryService: exportSummaryService,
  );

  runApp(
    DataHookClawsApp(
      repository: repository,
      syncUseCase: syncUseCase,
      searchOrchestrator: searchOrchestrator,
      exportService: exportService,
      importerDescriptors: importerDescriptors,
      sourceCapabilities: sourceCapabilities,
      storageBudgetManager: storageBudgetManager,
      modelBudgetController: modelBudgetController,
      settingsService: settingsService,
      exportShareService: const ExportShareService(),
    ),
  );
}
