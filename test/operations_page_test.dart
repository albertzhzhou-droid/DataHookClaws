import 'dart:io';

import 'package:data_hook_claws/src/data/importer_registry.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:data_hook_claws/src/domain/export_share_service.dart';
import 'package:data_hook_claws/src/domain/model_budget_controller.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/settings_service.dart';
import 'package:data_hook_claws/src/domain/source_capability_registry.dart';
import 'package:data_hook_claws/src/domain/storage_budget_manager.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/features/operations/operations_page.dart';
import 'package:data_hook_claws/src/importers/food_importer.dart';
import 'package:data_hook_claws/src/models/dataset_artifact_entry.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
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
          sourceCapabilities: SourceCapabilityRegistry(
            importerDescriptors: importerDescriptors,
            entities: nationalFoodEntities,
          ),
          storageBudgetManager: StorageBudgetManager(repository: repository),
          modelBudgetController: ModelBudgetController(),
          settingsService: SettingsService(
            repository: repository,
            sourceCapabilities: SourceCapabilityRegistry(
              importerDescriptors: importerDescriptors,
              entities: nationalFoodEntities,
            ),
          ),
          exportShareService: const ExportShareService(),
          onOpenSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

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
