import 'package:flutter/material.dart';

import 'api/food_catalog_export_service.dart';
import 'data/food_repository.dart';
import 'data/importer_registry.dart';
import 'data/national_food_sources.dart';
import 'domain/search_orchestrator.dart';
import 'domain/sync_food_catalog_use_case.dart';
import 'features/home/home_page.dart';

class DataHookClawsApp extends StatelessWidget {
  const DataHookClawsApp({
    super.key,
    required this.repository,
    required this.syncUseCase,
    required this.searchOrchestrator,
    required this.exportService,
    required this.importerDescriptors,
  });

  final FoodRepository repository;
  final SyncFoodCatalogUseCase syncUseCase;
  final SearchOrchestrator searchOrchestrator;
  final FoodCatalogExportService exportService;
  final List<ImporterDescriptor> importerDescriptors;

  @override
  Widget build(BuildContext context) {
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
      home: HomePage(
        repository: repository,
        syncUseCase: syncUseCase,
        searchOrchestrator: searchOrchestrator,
        exportService: exportService,
        entities: nationalFoodEntities,
        importerDescriptors: importerDescriptors,
      ),
    );
  }
}
