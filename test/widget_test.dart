import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:data_hook_claws/src/app.dart';
import 'package:data_hook_claws/src/api/export_models.dart';
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
import 'package:data_hook_claws/src/models/export_history_entry.dart';
import 'package:data_hook_claws/src/models/import_log_entry.dart';
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
    expect(find.text('Operations'), findsOneWidget);
    expect(
      find.textContaining('${nationalFoodSources.length} sources tracked'),
      findsOneWidget,
    );
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets(
    'restores valid favorites after skipping malformed persisted entries',
    (tester) async {
      final repository = MemoryFoodRepository();
      await repository.setAppMeta(
        'favorite_foods_v1',
        jsonEncode([
          {'foodId': 42, 'name': 'Malformed id'},
          {
            'foodId': 'food-1',
            'name': '  Saved salmon  ',
            'country': 'Canada',
            'category': 'Fish',
            'sourceName': 'CNF',
          },
          {
            'foodId': 'food-1',
            'name': 'Duplicate salmon',
            'country': 'Canada',
            'category': 'Fish',
            'sourceName': 'CNF',
          },
        ]),
      );
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: const [],
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

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Saved salmon • CNF'), findsOneWidget);
      expect(find.text('Duplicate salmon'), findsNothing);
    },
  );

  testWidgets(
    'restores valid favorite templates after skipping malformed entries',
    (tester) async {
      final repository = MemoryFoodRepository();
      await repository.setAppMeta(
        'favorite_foods_v1',
        jsonEncode([
          {
            'foodId': 'food-1',
            'name': 'Saved salmon',
            'country': 'Canada',
            'category': 'Fish',
            'sourceName': 'CNF',
          },
        ]),
      );
      await repository.setAppMeta(
        'favorite_templates_v1',
        jsonEncode([
          {'id': 'broken-template', 'name': 'Broken template', 'sortMode': 7},
          {
            'id': 'valid-template',
            'name': 'Valid template',
            'countryFilter': 'Canada',
            'sourceFilter': 'CNF',
            'categoryFilter': 'Fish',
            'sortMode': 'alpha',
            'createdAt': '2026-08-30T12:00:00.000Z',
            'updatedAt': '2026-08-30T13:00:00.000Z',
          },
        ]),
      );
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: const [],
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

      expect(find.text('Valid template'), findsOneWidget);
      expect(find.text('Broken template'), findsNothing);
    },
  );

  testWidgets(
    'keeps valid favorite filters when persisted sort mode has a wrong type',
    (tester) async {
      final repository = MemoryFoodRepository();
      await repository.setAppMeta(
        'favorite_foods_v1',
        jsonEncode([
          {
            'foodId': 'canada-food',
            'name': 'Canada Salmon',
            'country': 'Canada',
            'category': 'Fish',
            'sourceName': 'CNF',
          },
          {
            'foodId': 'japan-food',
            'name': 'Japan Rice',
            'country': 'Japan',
            'category': 'Grain',
            'sourceName': 'MEXT',
          },
        ]),
      );
      await repository.setAppMeta(
        'favorite_filters_v1',
        jsonEncode({'country': 'Canada', 'sortMode': 7}),
      );

      await _pumpHomeApp(tester, repository);

      expect(find.text('Canada Salmon • CNF'), findsOneWidget);
      expect(find.text('Japan Rice • MEXT'), findsNothing);
      expect(find.text('Recent'), findsOneWidget);
    },
  );

  testWidgets(
    'skips malformed recent export recall scopes before valid recalls',
    (tester) async {
      final repository = MemoryFoodRepository();
      await repository.setAppMeta(
        'recent_export_recalls_v1',
        jsonEncode([
          ' country: ',
          'compare:',
          'compare:|',
          'favorites:empty',
          'favorites:ALL-LOCAL-FOODS',
          'search:all-local-foods',
          'country:Canada',
          'compare:food-1|food-2',
        ]),
      );

      await _pumpHomeApp(tester, repository);

      expect(find.text('Country: Canada'), findsOneWidget);
      expect(find.text('Search: All local foods'), findsOneWidget);
      expect(find.text('Favorites: All local foods'), findsOneWidget);
      expect(find.text('Compare: 2 items'), findsOneWidget);
      expect(find.text('Country: '), findsNothing);
      expect(find.text('Compare: Unavailable'), findsNothing);
    },
  );

  testWidgets(
    'does not truncate fractional persisted compare draft timestamps',
    (tester) async {
      final repository = MemoryFoodRepository();
      const statusKey = 'compare:food-1|food-2';
      final futureFractionalTimestamp =
          DateTime.now().millisecondsSinceEpoch +
          const Duration(days: 1).inMilliseconds +
          0.5;
      await repository.setAppMeta(
        'recent_export_recalls_v1',
        jsonEncode([statusKey]),
      );
      await repository.setAppMeta(
        'recent_export_replay_statuses_v1',
        jsonEncode({statusKey: 'Draft (manual rebuild)'}),
      );
      await repository.setAppMeta(
        'recent_export_replay_drafts_v1',
        jsonEncode({statusKey: futureFractionalTimestamp}),
      );

      await _pumpHomeApp(tester, repository);

      expect(
        find.text('Compare: 2 items · Unavailable (manual rebuild required)'),
        findsOneWidget,
      );
      expect(find.textContaining('Draft (manual rebuild) ·'), findsNothing);
    },
  );

  testWidgets('isolates recent-search metadata read failures during startup', (
    tester,
  ) async {
    final repository = _FailingRecentSearchMetaRepository();

    await _pumpHomeApp(tester, repository);

    expect(find.text('DataHookClaws'), findsOneWidget);
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets(
    'continues export recall restoration when prompt config storage fails',
    (tester) async {
      final repository = _FailingComparePromptConfigMetaRepository();
      await repository.setAppMeta(
        'recent_export_recalls_v1',
        jsonEncode(['country:Canada']),
      );

      await _pumpHomeApp(tester, repository);

      expect(find.text('Country: Canada'), findsOneWidget);
    },
  );

  testWidgets(
    'falls back to export history when recent recall metadata is unavailable',
    (tester) async {
      final repository = _FailingRecentExportRecallMetaRepository();
      await repository.addExportHistory(
        ExportHistoryEntry(
          id: 'export-history-1',
          path: '/tmp/canada.json',
          format: ExportFormat.json,
          detailLevel: ExportDetailLevel.summary,
          recordCount: 1,
          scopeLabel: 'country:Canada',
          createdAt: DateTime(2026, 9, 2),
          status: 'success',
          summary: 'Canada export',
        ),
      );

      await _pumpHomeApp(tester, repository);

      expect(find.text('Country: Canada'), findsOneWidget);
    },
  );

  testWidgets('keeps compare recall chips when replay status storage fails', (
    tester,
  ) async {
    final repository = _FailingReplayStatusMetaRepository();
    await repository.setAppMeta(
      'recent_export_recalls_v1',
      jsonEncode(['compare:food-1|food-2']),
    );

    await _pumpHomeApp(tester, repository);

    expect(find.text('Compare: 2 items'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsNothing);
  });

  testWidgets(
    'keeps compare replay status visible when status persistence fails',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      final repository = _FailingReplayStatusWriteRepository(
        seedItems: const [],
      );
      const scopeKey = 'compare:food-1|food-2';
      await repository.setAppMeta(
        'recent_export_recalls_v1',
        jsonEncode([scopeKey]),
      );

      await _pumpHomeApp(tester, repository);
      repository.failReplayStatusWrites = true;

      await tester.tap(find.text('Compare: 2 items'));
      await tester.pumpAndSettle();

      expect(find.text('Compare: 2 items · Restored 2/2'), findsOneWidget);
      expect(repository.replayStatusWriteAttempts, greaterThan(0));
    },
  );

  testWidgets(
    'keeps compare replay status visible when draft timestamp persistence fails',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      final repository = _FailingReplayDraftTimestampWriteRepository();
      const scopeKey = 'compare:food-1|food-2';
      await repository.setAppMeta(
        'recent_export_recalls_v1',
        jsonEncode([scopeKey]),
      );

      await _pumpHomeApp(tester, repository);
      repository.failDraftTimestampWrites = true;

      await tester.tap(find.text('Compare: 2 items'));
      await tester.pumpAndSettle();

      expect(find.text('Compare: 2 items · Restored 2/2'), findsOneWidget);
      expect(repository.draftTimestampWriteAttempts, greaterThan(0));
    },
  );

  testWidgets('clears export recalls when recall persistence fails', (
    tester,
  ) async {
    final repository = _FailingRecentExportRecallWriteRepository();
    await repository.setAppMeta(
      'recent_export_recalls_v1',
      jsonEncode(['search:salmon']),
    );

    await _pumpHomeApp(tester, repository);
    expect(find.text('Search: salmon'), findsOneWidget);

    repository.failRecentExportRecallWrites = true;
    await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('Recent export recalls'), findsNothing);
    expect(repository.recentExportRecallWriteAttempts, greaterThan(0));
  });

  testWidgets(
    'continues compare status archival when replay draft timestamp storage fails',
    (tester) async {
      final repository = _FailingReplayDraftTimestampMetaRepository();
      const statusKey = 'compare:food-1|food-2';
      await repository.setAppMeta(
        'recent_export_recalls_v1',
        jsonEncode([statusKey]),
      );
      await repository.setAppMeta(
        'recent_export_replay_statuses_v1',
        jsonEncode({statusKey: 'Draft (manual rebuild)'}),
      );

      await _pumpHomeApp(tester, repository);

      expect(
        find.text('Compare: 2 items · Unavailable (manual rebuild required)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('isolates export-history read failures during startup', (
    tester,
  ) async {
    final repository = _FailingExportHistoryRepository();

    await _pumpHomeApp(tester, repository);

    expect(find.text('DataHookClaws'), findsOneWidget);
    expect(find.text('Recent export recalls'), findsNothing);
  });

  testWidgets('continues compare replay when one food detail read fails', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    final repository = _FailingCompareFoodDetailRepository();
    const statusKey = 'compare:food-1|food-2';
    await repository.setAppMeta(
      'recent_export_recalls_v1',
      jsonEncode([statusKey]),
    );

    await _pumpHomeApp(tester, repository);
    await tester.tap(find.text('Compare: 2 items'));
    await tester.pumpAndSettle();

    expect(
      find.text('Compare: 2 items · Partially restored 1/2'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Compare replay partially restored: 1 loaded'),
      findsOneWidget,
    );
  });

  testWidgets('keeps refresh results when import-log storage fails', (
    tester,
  ) async {
    final repository = _FailingImportLogRepository(seedItems: sampleFoodItems);

    await _pumpHomeApp(tester, repository);

    expect(find.text('Atlantic Salmon'), findsWidgets);
    expect(find.text('Persisted foods'), findsOneWidget);
  });

  testWidgets('keeps refresh results when food-count storage fails', (
    tester,
  ) async {
    final repository = _FailingFoodCountRepository(seedItems: sampleFoodItems);

    await _pumpHomeApp(tester, repository);

    expect(find.text('Atlantic Salmon'), findsWidgets);
    expect(find.text('Visible results'), findsOneWidget);
  });

  testWidgets('retries a failed initial results read without leaving loading', (
    tester,
  ) async {
    final repository = _TransientSearchFailureRepository(
      seedItems: sampleFoodItems,
    );

    await _pumpHomeApp(tester, repository);

    expect(find.text('Local results unavailable'), findsOneWidget);
    expect(find.text('Retry local results'), findsOneWidget);
    expect(find.text('Local database is empty'), findsNothing);

    repository.failSearch = false;
    await tester.ensureVisible(find.text('Retry local results'));
    await tester.tap(find.text('Retry local results'));
    await tester.pumpAndSettle();

    expect(find.text('Atlantic Salmon'), findsWidgets);
    expect(find.text('Local results unavailable'), findsNothing);
  });

  testWidgets(
    'recovers from a failed submitted search with an explicit retry',
    (tester) async {
      final repository = _TransientSearchFailureRepository(
        seedItems: sampleFoodItems,
      )..failSearch = false;

      await _pumpHomeApp(tester, repository);
      repository.failSearch = true;

      await tester.enterText(find.byType(TextField).first, 'salmon');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_search_error')), findsOneWidget);
      expect(find.text('Search unavailable'), findsOneWidget);
      expect(find.text('Retry search'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repository.failSearch = false;
      final retry = find.text('Retry search');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_search_error')), findsNothing);
      expect(find.text('Atlantic Salmon'), findsWidgets);
    },
  );

  testWidgets('continues search when recent-search persistence fails', (
    tester,
  ) async {
    final repository = _FailingRecentSearchWriteRepository(
      seedItems: sampleFoodItems,
    );

    await _pumpHomeApp(tester, repository);

    await tester.enterText(find.byType(TextField).first, 'salmon');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.recentSearchWriteAttempts, greaterThan(0));
    expect(find.text('Atlantic Salmon'), findsWidgets);
  });

  testWidgets('clears recent searches when persistence fails', (tester) async {
    final repository = _FailingRecentSearchWriteRepository(
      seedItems: sampleFoodItems,
    );

    await _pumpHomeApp(tester, repository);

    await tester.enterText(find.byType(TextField).first, 'salmon');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    await tester.tap(find.text('Clear all').first);
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsNothing);
    expect(repository.recentSearchWriteAttempts, greaterThan(1));
  });

  testWidgets('keeps favorite toggles responsive when persistence fails', (
    tester,
  ) async {
    final repository = _FailingFavoriteWriteRepository(
      seedItems: sampleFoodItems,
    );

    await _pumpHomeApp(tester, repository);

    final addToFavorites = find.byTooltip('Add to favorites').first;
    await tester.ensureVisible(addToFavorites);
    await tester.tap(addToFavorites);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove from favorites'), findsWidgets);
    expect(repository.favoriteWriteAttempts, greaterThan(0));
  });

  testWidgets('keeps favorite filters responsive when persistence fails', (
    tester,
  ) async {
    final repository = _FailingFavoriteFilterWriteRepository(
      seedItems: sampleFoodItems,
    );
    await repository.setAppMeta(
      'favorite_foods_v1',
      jsonEncode([
        {
          'foodId': 'cnf-salmon-002',
          'name': 'Atlantic Salmon',
          'country': 'Canada',
          'category': 'Seafood',
          'sourceName': 'Canadian Nutrient File',
        },
      ]),
    );

    await _pumpHomeApp(tester, repository);
    repository.failFavoriteFilterWrites = true;

    final countryChip = find.widgetWithText(ChoiceChip, 'Canada');
    await tester.ensureVisible(countryChip);
    await tester.tap(countryChip);
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(countryChip).selected, isTrue);
    expect(repository.favoriteFilterWriteAttempts, greaterThan(0));
  });

  testWidgets(
    'keeps favorite template saves responsive when persistence fails',
    (tester) async {
      final repository = _FailingFavoriteTemplateWriteRepository(
        seedItems: sampleFoodItems,
      );
      await repository.setAppMeta(
        'favorite_foods_v1',
        jsonEncode([
          {
            'foodId': 'cnf-salmon-002',
            'name': 'Atlantic Salmon',
            'country': 'Canada',
            'category': 'Seafood',
            'sourceName': 'Canadian Nutrient File',
          },
        ]),
      );

      await _pumpHomeApp(tester, repository);
      repository.failFavoriteTemplateWrites = true;

      final templateField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Template name',
      );
      await tester.scrollUntilVisible(
        templateField,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(templateField, 'Daily salmon');
      final saveTemplateButton = find.widgetWithText(FilledButton, 'Save');
      tester.widget<FilledButton>(saveTemplateButton).onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Daily salmon'), findsOneWidget);
      expect(repository.favoriteTemplateWriteAttempts, greaterThan(0));
    },
  );

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

  testWidgets(
    'does not let a stale enrichment refresh overwrite a newer search',
    (tester) async {
      final repository = _StaleRefreshSearchRepository();
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

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'salmon');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      for (
        var attempt = 0;
        attempt < 20 && !repository.salmonRefreshStarted.isCompleted;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repository.salmonRefreshStarted.isCompleted, isTrue);

      await tester.enterText(searchField, 'oats');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('oats foreground'), findsWidgets);

      ukBlocker.complete();
      repository.salmonRefreshRelease.complete();
      await tester.pumpAndSettle();

      expect(find.text('oats foreground'), findsWidgets);
    },
  );

  testWidgets(
    'advanced filters run local-only search without foreground fetch',
    (tester) async {
      final repository = MemoryFoodRepository(
        seedItems: [
          FoodItem(
            id: 'canada-cnf:salmon',
            name: 'Atlantic Salmon',
            category: 'Seafood',
            country: 'Canada',
            sourceName: 'CNF',
            description: 'Official salmon record',
            servingBasis: 'Per 100 g',
            tags: const ['official'],
            nutrients: const [
              Nutrient(label: 'Protein', amount: 21, unit: 'g'),
            ],
            lastUpdated: DateTime(2026, 5, 24),
          ),
        ],
      );
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: const [],
      );
      final searchOrchestrator = SearchOrchestrator(
        repository: repository,
        foregroundFetchRunner: _ThrowingForegroundRunner(repository),
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

      await tester.tap(find.text('Advanced filters'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'salmon');
      await tester.enterText(
        find.widgetWithText(TextField, 'Country filter'),
        'Canada',
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(find.text('Atlantic Salmon'), findsWidgets);
      expect(find.text('Advanced local filters applied.'), findsOneWidget);
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
    expect(find.text('Nutrient source comparison'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Official sources'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
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
                    latestArtifact: null,
                    isSharing: false,
                    onShareLatest: null,
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

Future<void> _pumpHomeApp(
  WidgetTester tester,
  MemoryFoodRepository repository,
) async {
  final useCase = SyncFoodCatalogUseCase(
    repository: repository,
    normalizer: const FoodRecordNormalizer(),
    importers: const [],
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

class _FailingRecentSearchMetaRepository extends MemoryFoodRepository {
  _FailingRecentSearchMetaRepository() : super();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key == 'recent_searches_v1') {
      throw StateError('recent-search metadata unavailable');
    }
    return super.getAppMeta(key);
  }
}

class _FailingComparePromptConfigMetaRepository extends MemoryFoodRepository {
  _FailingComparePromptConfigMetaRepository() : super();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key == 'compare_replay_draft_prompt_config_v1') {
      throw StateError('prompt configuration unavailable');
    }
    return super.getAppMeta(key);
  }
}

class _FailingRecentExportRecallMetaRepository extends MemoryFoodRepository {
  _FailingRecentExportRecallMetaRepository() : super();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key == 'recent_export_recalls_v1') {
      throw StateError('recent export recall metadata unavailable');
    }
    return super.getAppMeta(key);
  }
}

class _FailingReplayStatusMetaRepository extends MemoryFoodRepository {
  _FailingReplayStatusMetaRepository() : super();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key == 'recent_export_replay_statuses_v1') {
      throw StateError('replay status metadata unavailable');
    }
    return super.getAppMeta(key);
  }
}

class _FailingReplayStatusWriteRepository extends MemoryFoodRepository {
  _FailingReplayStatusWriteRepository({super.seedItems});

  bool failReplayStatusWrites = false;
  int replayStatusWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'recent_export_replay_statuses_v1' && failReplayStatusWrites) {
      replayStatusWriteAttempts += 1;
      throw StateError('replay status metadata write unavailable');
    }
    return super.setAppMeta(key, value);
  }

  @override
  Future<FoodDetails?> getFoodDetails(String canonicalFoodId) async {
    if (canonicalFoodId == 'food-1' || canonicalFoodId == 'food-2') {
      return FoodDetails(
        id: canonicalFoodId,
        displayName: canonicalFoodId == 'food-1' ? 'Food One' : 'Food Two',
        category: 'Test',
        countryHint: 'Test',
        description: 'Replay fixture',
        servingBasis: 'Per 100 g',
        lastAggregatedAt: DateTime(2026, 9, 2),
        aliases: const [],
        sourceRecords: const [],
        aggregatedNutrients: const [],
        nutrientObservations: const [],
      );
    }
    return super.getFoodDetails(canonicalFoodId);
  }
}

class _FailingReplayDraftTimestampWriteRepository
    extends _FailingReplayStatusWriteRepository {
  _FailingReplayDraftTimestampWriteRepository() : super();

  bool failDraftTimestampWrites = false;
  int draftTimestampWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'recent_export_replay_drafts_v1' && failDraftTimestampWrites) {
      draftTimestampWriteAttempts += 1;
      throw StateError('replay draft timestamp metadata write unavailable');
    }
    return super.setAppMeta(key, value);
  }
}

class _FailingRecentExportRecallWriteRepository extends MemoryFoodRepository {
  bool failRecentExportRecallWrites = false;
  int recentExportRecallWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'recent_export_recalls_v1' && failRecentExportRecallWrites) {
      recentExportRecallWriteAttempts += 1;
      throw StateError('recent export recall metadata write unavailable');
    }
    return super.setAppMeta(key, value);
  }
}

class _FailingReplayDraftTimestampMetaRepository extends MemoryFoodRepository {
  _FailingReplayDraftTimestampMetaRepository() : super();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key == 'recent_export_replay_drafts_v1') {
      throw StateError('replay draft timestamp metadata unavailable');
    }
    return super.getAppMeta(key);
  }
}

class _FailingExportHistoryRepository extends MemoryFoodRepository {
  _FailingExportHistoryRepository() : super();

  @override
  Future<List<ExportHistoryEntry>> getExportHistory({int limit = 20}) async {
    throw StateError('export history unavailable');
  }
}

class _FailingCompareFoodDetailRepository extends MemoryFoodRepository {
  _FailingCompareFoodDetailRepository() : super();

  @override
  Future<FoodDetails?> getFoodDetails(String canonicalFoodId) async {
    if (canonicalFoodId == 'food-1') {
      throw StateError('first compare detail unavailable');
    }
    if (canonicalFoodId == 'food-2') {
      return FoodDetails(
        id: 'food-2',
        displayName: 'Food Two',
        category: 'Test',
        countryHint: 'Test',
        description: 'Food two description',
        servingBasis: 'Per 100 g',
        lastAggregatedAt: DateTime(2026, 9, 2),
        aliases: const [],
        sourceRecords: const [],
        aggregatedNutrients: const [],
        nutrientObservations: const [],
      );
    }
    return super.getFoodDetails(canonicalFoodId);
  }
}

class _FailingImportLogRepository extends MemoryFoodRepository {
  _FailingImportLogRepository({super.seedItems});

  @override
  Future<List<ImportLogEntry>> getImportLogs({int limit = 20}) async {
    throw StateError('import-log history unavailable');
  }
}

class _FailingFoodCountRepository extends MemoryFoodRepository {
  _FailingFoodCountRepository({super.seedItems});

  @override
  Future<int> countFoods() async {
    throw StateError('food count unavailable');
  }
}

class _TransientSearchFailureRepository extends MemoryFoodRepository {
  _TransientSearchFailureRepository({super.seedItems});

  bool failSearch = true;

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    if (failSearch) {
      throw StateError('initial search unavailable');
    }
    return super.searchFoods(query);
  }
}

class _StaleRefreshSearchRepository extends MemoryFoodRepository {
  final Completer<void> salmonRefreshStarted = Completer<void>();
  final Completer<void> salmonRefreshRelease = Completer<void>();
  int _salmonSearchCount = 0;

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().toLowerCase() == 'salmon') {
      _salmonSearchCount += 1;
      if (_salmonSearchCount == 3) {
        salmonRefreshStarted.complete();
        await salmonRefreshRelease.future;
      }
    }
    return super.searchFoods(query);
  }
}

class _FailingRecentSearchWriteRepository extends MemoryFoodRepository {
  _FailingRecentSearchWriteRepository({super.seedItems});

  int recentSearchWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'recent_searches_v1') {
      recentSearchWriteAttempts += 1;
      throw StateError('recent-search metadata write unavailable');
    }
    return super.setAppMeta(key, value);
  }
}

class _FailingFavoriteWriteRepository extends MemoryFoodRepository {
  _FailingFavoriteWriteRepository({super.seedItems});

  int favoriteWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'favorite_foods_v1') {
      favoriteWriteAttempts += 1;
      throw StateError('favorite metadata write unavailable');
    }
    return super.setAppMeta(key, value);
  }
}

class _FailingFavoriteFilterWriteRepository extends MemoryFoodRepository {
  _FailingFavoriteFilterWriteRepository({super.seedItems});

  bool failFavoriteFilterWrites = false;
  int favoriteFilterWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'favorite_filters_v1' && failFavoriteFilterWrites) {
      favoriteFilterWriteAttempts += 1;
      throw StateError('favorite filter metadata write unavailable');
    }
    return super.setAppMeta(key, value);
  }
}

class _FailingFavoriteTemplateWriteRepository extends MemoryFoodRepository {
  _FailingFavoriteTemplateWriteRepository({super.seedItems});

  bool failFavoriteTemplateWrites = false;
  int favoriteTemplateWriteAttempts = 0;

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key == 'favorite_templates_v1' && failFavoriteTemplateWrites) {
      favoriteTemplateWriteAttempts += 1;
      throw StateError('favorite template metadata write unavailable');
    }
    return super.setAppMeta(key, value);
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

class _ThrowingForegroundRunner extends ForegroundFetchRunner {
  _ThrowingForegroundRunner(MemoryFoodRepository repository)
    : super(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: repository,
          importers: const [],
          normalizer: const FoodRecordNormalizer(),
        ),
      );

  @override
  Future<ForegroundFetchResult> run({
    required String query,
    required List<String> importerIds,
    required int limitPerImporter,
    required Future<void> Function(FetchJobEntry job) persistJob,
  }) {
    throw StateError('Foreground fetch should not run for advanced filters.');
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
