import 'dart:convert';
import 'dart:io';

import 'package:data_hook_claws/src/api/export_models.dart';
import 'package:data_hook_claws/src/api/food_catalog_export_service.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/sqlite_food_repository.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('exports search summary json with parseable payload', () async {
    final exportRoot = await Directory.systemTemp.createTemp('export-summary');
    addTearDown(() async {
      if (exportRoot.existsSync()) {
        await exportRoot.delete(recursive: true);
      }
    });

    final repository = MemoryFoodRepository(seedItems: [_salmon()]);
    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => exportRoot,
      clock: () => DateTime(2026, 5, 24, 14, 20),
    );

    final artifact = await service.exportSearchResults(
      query: 'salmon',
      format: ExportFormat.json,
      detailLevel: ExportDetailLevel.summary,
    );

    final json =
        jsonDecode(await File(artifact.path).readAsString())
            as Map<String, Object?>;
    expect(artifact.recordCount, 1);
    expect(await repository.getExportHistory(), hasLength(1));
    expect(json['detailLevel'], 'summary');
    expect(
      (json['foods'] as List<Object?>).single,
      isA<Map<String, Object?>>(),
    );
  });

  test('custom export directory is honored', () async {
    final documentRoot = await Directory.systemTemp.createTemp('export-docs');
    final customRoot = await Directory.systemTemp.createTemp('export-custom');
    addTearDown(() async {
      if (documentRoot.existsSync()) {
        await documentRoot.delete(recursive: true);
      }
      if (customRoot.existsSync()) {
        await customRoot.delete(recursive: true);
      }
    });

    final repository = MemoryFoodRepository(seedItems: [_salmon()]);
    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => documentRoot,
      exportDirectoryPathResolver: () async => customRoot.path,
    );

    final artifact = await service.exportSearchResults(
      query: 'salmon',
      format: ExportFormat.json,
      detailLevel: ExportDetailLevel.summary,
    );

    expect(artifact.path, startsWith(customRoot.path));
  });

  test(
    'exports search detailed json with provenance and merge audit',
    () async {
      final exportRoot = await Directory.systemTemp.createTemp('export-detail');
      addTearDown(() async {
        if (exportRoot.existsSync()) {
          await exportRoot.delete(recursive: true);
        }
      });

      final repository = MemoryFoodRepository(seedItems: [_salmon()]);
      final service = FoodCatalogExportService(
        repository: repository,
        documentsDirectoryResolver: () async => exportRoot,
      );

      final artifact = await service.exportSearchResults(
        query: 'salmon',
        format: ExportFormat.json,
        detailLevel: ExportDetailLevel.detailed,
      );

      final json =
          jsonDecode(await File(artifact.path).readAsString())
              as Map<String, Object?>;
      final foods = json['foods'] as List<Object?>;
      final first = foods.single as Map<String, Object?>;
      final sources = first['sources'] as List<Object?>;

      expect(artifact.recordCount, 1);
      expect(first['aggregatedNutrients'], isA<List<Object?>>());
      expect(
        ((sources.single as Map<String, Object?>)['mergeAudit']),
        isA<Map<String, Object?>>(),
      );
    },
  );

  test('exports search summary csv with expected header', () async {
    final exportRoot = await Directory.systemTemp.createTemp('export-csv');
    addTearDown(() async {
      if (exportRoot.existsSync()) {
        await exportRoot.delete(recursive: true);
      }
    });

    final repository = MemoryFoodRepository(seedItems: [_salmon()]);
    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => exportRoot,
    );

    final artifact = await service.exportSearchResults(
      query: 'salmon',
      format: ExportFormat.csv,
      detailLevel: ExportDetailLevel.summary,
    );

    final contents = await File(artifact.path).readAsString();
    expect(contents, contains('id,name,category,country,sourceSummary'));
  });

  test('exports search detailed csv with json provenance fields', () async {
    final exportRoot = await Directory.systemTemp.createTemp(
      'export-detailed-csv',
    );
    addTearDown(() async {
      if (exportRoot.existsSync()) {
        await exportRoot.delete(recursive: true);
      }
    });

    final repository = MemoryFoodRepository(seedItems: [_salmon()]);
    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => exportRoot,
    );

    final artifact = await service.exportSearchResults(
      query: 'salmon',
      format: ExportFormat.csv,
      detailLevel: ExportDetailLevel.detailed,
    );

    final contents = await File(artifact.path).readAsString();
    expect(contents, contains('aggregatedNutrientsJson'));
    expect(contents, contains('mergeAuditJson'));
    expect(contents, contains('observationsJson'));
  });

  test('exports country slice with only matching country records', () async {
    final exportRoot = await Directory.systemTemp.createTemp(
      'export-country-slice',
    );
    addTearDown(() async {
      if (exportRoot.existsSync()) {
        await exportRoot.delete(recursive: true);
      }
    });

    final repository = MemoryFoodRepository(
      seedItems: [
        _salmon(country: 'Canada'),
        _food(
          id: 'jp-standard:rice-1',
          name: 'Plain Rice',
          category: 'Grains',
          country: 'Japan',
          sourceName: 'MEXT',
        ),
      ],
    );
    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => exportRoot,
    );

    final artifact = await service.exportCountrySlice(
      country: 'Canada',
      format: ExportFormat.json,
      detailLevel: ExportDetailLevel.summary,
    );

    final json =
        jsonDecode(await File(artifact.path).readAsString())
            as Map<String, Object?>;
    final foods = json['foods'] as List<Object?>;
    expect(foods, hasLength(1));
    expect((foods.single as Map<String, Object?>)['country'], 'Canada');
  });

  test('sqlite snapshot export copies a readable database file', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final tempDirectory = await Directory.systemTemp.createTemp(
      'export-sqlite-snapshot',
    );
    addTearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final repository = SqliteFoodRepository(
      documentsDirectoryResolver: () async => tempDirectory,
    );
    await repository.initialize();
    await repository.upsertFoods([_salmon()]);

    final service = FoodCatalogExportService(
      repository: repository,
      documentsDirectoryResolver: () async => tempDirectory,
    );
    final artifact = await service.exportDatabaseSnapshot();

    final file = File(artifact.path);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
  });

  test(
    'searchFoodSummariesByCountry works for memory and snapshot export fails',
    () async {
      final repository = MemoryFoodRepository(
        seedItems: [
          _salmon(country: 'Canada'),
          _food(
            id: 'jp-standard:rice-1',
            name: 'Plain Rice',
            category: 'Grains',
            country: 'Japan',
            sourceName: 'MEXT',
          ),
        ],
      );

      final summaries = await repository.searchFoodSummariesByCountry('Canada');
      expect(summaries, hasLength(1));
      expect(summaries.single.country, 'Canada');

      expect(
        () => repository.copyDatabaseSnapshot(
          destinationPath: p.join('/tmp', 'should-not-exist.db'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );
}

FoodItem _salmon({String country = 'Canada'}) {
  return _food(
    id: 'canada-cnf:salmon-1',
    name: 'Atlantic Salmon',
    category: 'Seafood',
    country: country,
    sourceName: 'CNF',
  );
}

FoodItem _food({
  required String id,
  required String name,
  required String category,
  required String country,
  required String sourceName,
}) {
  return FoodItem(
    id: id,
    name: name,
    category: category,
    country: country,
    sourceName: sourceName,
    description: '$sourceName record for $name',
    servingBasis: 'Per 100 g',
    tags: const ['official'],
    nutrients: const [Nutrient(label: 'Protein', amount: 20.4, unit: 'g')],
    lastUpdated: DateTime(2026, 5, 24, 12),
  );
}
