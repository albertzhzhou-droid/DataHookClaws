import 'dart:async';
import 'dart:io';

import 'package:data_hook_claws/src/app.dart';
import 'package:data_hook_claws/src/api/food_catalog_export_service.dart';
import 'package:data_hook_claws/src/data/importer_registry.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/official_dataset_grabber.dart';
import 'package:data_hook_claws/src/data/official_dataset_manifest.dart';
import 'package:data_hook_claws/src/data/sample_food_data.dart';
import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:data_hook_claws/src/domain/background_enrichment_queue.dart';
import 'package:data_hook_claws/src/domain/fetch_budget_planner.dart';
import 'package:data_hook_claws/src/domain/foreground_fetch_runner.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/ollama_client.dart';
import 'package:data_hook_claws/src/domain/query_expansion_service.dart';
import 'package:data_hook_claws/src/domain/search_orchestrator.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/importers/food_importer.dart';
import 'package:data_hook_claws/src/features/home/home_page.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:data_hook_claws/src/models/food_details.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:data_hook_claws/src/models/query_expansion_result.dart';
import 'package:data_hook_claws/src/models/raw_food_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders nutrition search app shell', (tester) async {
    final repository = MemoryFoodRepository(seedItems: sampleFoodItems);
    final useCase = SyncFoodCatalogUseCase(
      repository: repository,
      normalizer: const FoodRecordNormalizer(),
      datasetGrabber: OfficialDatasetGrabber(
        transport: _NoopDatasetTransport(),
        packagePreparer: _NoopPackagePreparer(),
      ),
      importers: buildIntegratedImporters(),
    );
    final searchOrchestrator = SearchOrchestrator(
      repository: repository,
      foregroundFetchRunner: ForegroundFetchRunner(syncUseCase: useCase),
      budgetPlanner: const FetchBudgetPlanner(),
      queryExpansionService: QueryExpansionService(
        ollamaClient: _FailingOllamaClient(),
        persistSuggestion: repository.addAiSuggestionLog,
      ),
      enrichmentQueue: BackgroundEnrichmentQueue(syncUseCase: useCase),
    );

    await tester.pumpWidget(
      DataHookClawsApp(
        repository: repository,
        syncUseCase: useCase,
        searchOrchestrator: searchOrchestrator,
        exportService: FoodCatalogExportService(
          repository: repository,
          documentsDirectoryResolver: () async => Directory.systemTemp,
        ),
        importerDescriptors: importerDescriptors,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DataHookClaws'), findsOneWidget);
    expect(
      find.text(
        'Persist official nutrition records locally, then search them without relying on demo data.',
      ),
      findsOneWidget,
    );
    expect(find.text('Source controls'), findsOneWidget);
    expect(find.text('UK CoFID'), findsOneWidget);
    expect(find.text('Japan MEXT 2023'), findsOneWidget);
    expect(find.text('Search status'), findsOneWidget);
    expect(find.text('Import history'), findsOneWidget);
    expect(find.text('No imports recorded yet'), findsOneWidget);
    expect(find.text('Local search results'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(
      find.textContaining('${nationalFoodSources.length} sources tracked'),
      findsOneWidget,
    );
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets(
    'triggers background enrichment after dwell and refreshes results',
    (tester) async {
      final repository = MemoryFoodRepository();
      final ukBlocker = Completer<void>();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: [
          _FakeWidgetImporter(
            id: 'uk-mccance',
            onImport: (request) async {
              await ukBlocker.future;
              return [_widgetRecord('uk-mccance', request.query)];
            },
          ),
          _FakeWidgetImporter(
            id: 'jp-standard',
            onImport: (request) async => [
              _widgetRecord('jp-standard', request.query),
            ],
          ),
        ],
      );
      final searchOrchestrator = SearchOrchestrator(
        repository: repository,
        foregroundFetchRunner: _WidgetForegroundRunner(repository),
        budgetPlanner: const FetchBudgetPlanner(),
        queryExpansionService: _WidgetQueryExpansionService(),
        enrichmentQueue: BackgroundEnrichmentQueue(syncUseCase: useCase),
      );

      await tester.pumpWidget(
        DataHookClawsApp(
          repository: repository,
          syncUseCase: useCase,
          searchOrchestrator: searchOrchestrator,
          exportService: FoodCatalogExportService(
            repository: repository,
            documentsDirectoryResolver: () async => Directory.systemTemp,
          ),
          importerDescriptors: importerDescriptors,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'salmon');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Archived into local database'), findsOneWidget);
      expect(find.text('salmon foreground'), findsWidgets);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('Background enrichment'), findsOneWidget);
      expect(
        find.textContaining('Enriching related official data'),
        findsOneWidget,
      );

      ukBlocker.complete();
      await tester.pumpAndSettle();

      expect(find.text('Completed background enrichment'), findsOneWidget);
      expect(find.text('salmon uk-mccance'), findsWidgets);
      expect(find.text('salmon jp-standard'), findsWidgets);
    },
  );

  testWidgets('renders provenance detail sheet sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodDetailSheet(
            details: FoodDetails(
              id: '1',
              displayName: 'Atlantic Salmon',
              category: 'Seafood',
              countryHint: 'Canada',
              description: 'Rich in omega-3',
              servingBasis: 'Per 100 g',
              lastAggregatedAt: DateTime(2026, 5, 23),
              aliases: const ['Atlantic Salmon', 'Salmon'],
              sourceRecords: [
                SourceRecordView(
                  id: 'record-1',
                  importerId: 'canada-cnf',
                  sourceName: 'CNF',
                  sourceRecordId: 'cnf-1',
                  country: 'Canada',
                  recordTitle: 'Atlantic Salmon',
                  recordDescription: 'Canadian source record',
                  fetchedAt: DateTime(2026, 5, 23),
                  sourceUpdatedAt: DateTime(2026, 5, 23),
                  mergeAudit: MergeAuditView(
                    sourceRecordId: 'record-1',
                    action: 'reuse',
                    confidence: 0.98,
                    matchedBy: 'name-category-serving-nutrient',
                    reason: 'Exact alias/category/serving match.',
                    itemAliasKey: 'atlantic salmon',
                    itemCategoryKey: 'seafood',
                    itemServingKey: 'per 100 g',
                    candidateEvaluations: const [
                      MergeCandidateEvaluationView(
                        candidateCanonicalFoodId:
                            'canonical:atlantic salmon:seafood:per 100 g',
                        aliasMatched: true,
                        categoryMatched: true,
                        servingMatched: true,
                        nutrientSimilarity: 0.98,
                        accepted: true,
                        reason: 'Exact alias/category/serving match.',
                      ),
                    ],
                    createdAt: DateTime(2026, 5, 23),
                  ),
                ),
              ],
              aggregatedNutrients: const [
                Nutrient(label: 'Protein', amount: 20.4, unit: 'g'),
              ],
              nutrientObservations: const [
                NutrientObservationView(
                  sourceRecordId: 'record-1',
                  label: 'Protein',
                  canonicalLabel: 'Protein',
                  amount: 20.4,
                  unit: 'g',
                  originalUnit: 'g',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Official sources'), findsOneWidget);
    expect(find.text('Merge audit'), findsOneWidget);
    expect(find.textContaining('Reused canonical'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Aliases'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aliases'), findsOneWidget);
    expect(find.text('CNF'), findsWidgets);
  });

  testWidgets('renders empty provenance error state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FoodDetailErrorState(
            message: 'No provenance records available yet',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food details unavailable'), findsOneWidget);
    expect(find.text('No provenance records available yet'), findsOneWidget);
  });

  testWidgets('export card button click can surface success status', (
    tester,
  ) async {
    var message = 'Idle';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  ExportCard(
                    onExportSummaryJson: () {
                      setState(() {
                        message = 'Exported 1 records to /tmp/export.json';
                      });
                    },
                    onExportDetailedCsv: () {},
                    onExportSnapshot: () {},
                    isExportingSummaryJson: false,
                    isExportingDetailedCsv: false,
                    isExportingSnapshot: false,
                  ),
                  ListTile(
                    title: const Text('Last export status'),
                    subtitle: Text(message),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export search summary JSON'));
    await tester.pump();

    expect(find.text('Last export status'), findsOneWidget);
    expect(find.textContaining('Exported 1 records to'), findsOneWidget);
  });
}

class _NoopDatasetTransport implements DatasetTransport {
  @override
  Future<Directory> datasetRoot(String importerId) async {
    return Directory('/tmp/$importerId');
  }

  @override
  Future<Uri> discoverUrl({
    required Uri sourcePageUrl,
    required PageLinkDiscovery discovery,
  }) async {
    return sourcePageUrl.resolve('/resolved-file');
  }

  @override
  Future<String> download({
    required Uri url,
    required String suggestedFileName,
    required String importerId,
  }) async {
    return '/tmp/$suggestedFileName';
  }
}

class _NoopPackagePreparer extends DatasetPackagePreparer {
  @override
  Future<String> prepare({
    required String importerId,
    required OfficialDatasetPackaging packaging,
    required List<String> downloadedFiles,
  }) async {
    return downloadedFiles.first;
  }
}

class _FailingOllamaClient extends OllamaClient {
  _FailingOllamaClient() : super(timeout: const Duration(milliseconds: 10));

  @override
  Future<String> generateJson({required String prompt}) {
    throw Exception('offline');
  }
}

class _WidgetForegroundRunner extends ForegroundFetchRunner {
  _WidgetForegroundRunner(this.repository)
    : super(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: repository,
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      );

  final MemoryFoodRepository repository;

  @override
  Future<ForegroundFetchResult> run({
    required String query,
    required List<String> importerIds,
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry job) persistJob,
  }) async {
    await repository.upsertFoods([
      FoodItem(
        id: 'foreground-$query',
        name: '$query foreground',
        category: 'Test',
        country: 'Test',
        sourceName: 'foreground',
        description: '$query description',
        servingBasis: 'Per 100 g',
        tags: const ['tag'],
        nutrients: const [Nutrient(label: 'Protein', amount: 12, unit: 'g')],
        lastUpdated: DateTime(2026, 5, 23),
      ),
    ]);
    return ForegroundFetchResult(
      importedFoods: [
        FoodItem(
          id: 'foreground-$query',
          name: '$query foreground',
          category: 'Test',
          country: 'Test',
          sourceName: 'foreground',
          description: '$query description',
          servingBasis: 'Per 100 g',
          tags: const ['tag'],
          nutrients: const [Nutrient(label: 'Protein', amount: 12, unit: 'g')],
          lastUpdated: DateTime(2026, 5, 23),
        ),
      ],
      succeededSources: const ['usda', 'canada-cnf'],
    );
  }
}

class _WidgetQueryExpansionService extends QueryExpansionService {
  _WidgetQueryExpansionService()
    : super(
        persistSuggestion: (_) async {},
        ollamaClient: _FailingOllamaClient(),
      );

  @override
  Future<QueryExpansionResult> expand(String rawQuery) async {
    return QueryExpansionResult(
      primaryQuery: rawQuery.trim(),
      aliases: const [],
      translations: const [],
      sourceHints: const [],
      usedModel: false,
    );
  }
}

class _FakeWidgetImporter implements FoodImporter {
  _FakeWidgetImporter({required this.id, required this.onImport});

  @override
  final String id;

  final Future<List<RawFoodRecord>> Function(ImportRequest request) onImport;

  @override
  String get displayName => id;

  @override
  String get country => 'Test';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) {
    return onImport(request);
  }
}

RawFoodRecord _widgetRecord(String importerId, String query) {
  return RawFoodRecord(
    sourceRecordId: '$importerId-$query',
    name: '$query $importerId',
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
