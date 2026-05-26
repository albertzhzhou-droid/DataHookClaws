import 'package:flutter/material.dart';

import 'api/food_catalog_export_service.dart';
import 'data/food_repository.dart';
import 'data/importer_registry.dart';
import 'data/national_food_sources.dart';
import 'domain/search_orchestrator.dart';
import 'domain/export_share_service.dart';
import 'domain/settings_service.dart';
import 'domain/model_budget_controller.dart';
import 'domain/source_capability_registry.dart';
import 'domain/storage_budget_manager.dart';
import 'domain/sync_food_catalog_use_case.dart';
import 'features/home/home_page.dart';
import 'features/operations/operations_page.dart';
import 'features/settings/settings_page.dart';

class DataHookClawsApp extends StatelessWidget {
  const DataHookClawsApp({
    super.key,
    required this.repository,
    required this.syncUseCase,
    required this.searchOrchestrator,
    required this.exportService,
    required this.importerDescriptors,
    this.sourceCapabilities,
    this.storageBudgetManager,
    this.modelBudgetController,
    this.settingsService,
    this.exportShareService,
  });

  final FoodRepository repository;
  final SyncFoodCatalogUseCase syncUseCase;
  final SearchOrchestrator searchOrchestrator;
  final FoodCatalogExportService exportService;
  final List<ImporterDescriptor> importerDescriptors;
  final SourceCapabilityRegistry? sourceCapabilities;
  final StorageBudgetManager? storageBudgetManager;
  final ModelBudgetController? modelBudgetController;
  final SettingsService? settingsService;
  final ExportShareService? exportShareService;

  @override
  Widget build(BuildContext context) {
    final effectiveSourceCapabilities =
        sourceCapabilities ??
        SourceCapabilityRegistry(
          importerDescriptors: importerDescriptors,
          entities: nationalFoodEntities,
        );
    final effectiveStorageBudgetManager =
        storageBudgetManager ?? StorageBudgetManager(repository: repository);
    final effectiveModelBudgetController =
        modelBudgetController ?? ModelBudgetController();
    final effectiveSettingsService =
        settingsService ??
        SettingsService(
          repository: repository,
          sourceCapabilities: effectiveSourceCapabilities,
        );
    final effectiveExportShareService =
        exportShareService ?? const ExportShareService();
    return MaterialApp(
      title: 'DataHookClaws',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7490),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FBFB),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          return HomePage(
            repository: repository,
            syncUseCase: syncUseCase,
            searchOrchestrator: searchOrchestrator,
            exportService: exportService,
            entities: nationalFoodEntities,
            importerDescriptors: importerDescriptors,
            exportShareService: effectiveExportShareService,
            onOpenOperations: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OperationsPage(
                    repository: repository,
                    syncUseCase: syncUseCase,
                    importerDescriptors: importerDescriptors,
                    sourceCapabilities: effectiveSourceCapabilities,
                    storageBudgetManager: effectiveStorageBudgetManager,
                    modelBudgetController: effectiveModelBudgetController,
                    settingsService: effectiveSettingsService,
                    exportShareService: effectiveExportShareService,
                    onOpenSettings: () => _openSettings(
                      context,
                      effectiveSettingsService,
                      effectiveSourceCapabilities,
                    ),
                  ),
                ),
              );
            },
            onOpenSettings: () => _openSettings(
              context,
              effectiveSettingsService,
              effectiveSourceCapabilities,
            ),
          );
        },
      ),
    );
  }

  void _openSettings(
    BuildContext context,
    SettingsService settingsService,
    SourceCapabilityRegistry sourceCapabilities,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          settingsService: settingsService,
          sourceCapabilities: sourceCapabilities,
          storagePathsLoader: repository.getStoragePaths,
        ),
      ),
    );
  }
}
