import 'dart:io';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/importers/australia_afcd_importer.dart';
import 'package:data_hook_claws/src/importers/denmark_frida_excel_importer.dart';
import 'package:data_hook_claws/src/importers/france_ciqual_excel_importer.dart';
import 'package:data_hook_claws/src/importers/swiss_food_composition_excel_importer.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SwissFoodCompositionExcelImporter', () {
    test('parses a minimal official workbook sample', () async {
      final tempDir = await Directory.systemTemp.createTemp('swiss-importer');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workbookPath = p.join(tempDir.path, 'swiss.xlsx');
      await _writeSwissWorkbook(workbookPath);

      final importer = SwissFoodCompositionExcelImporter();
      final foods = await importer.importFoods(
        ImportRequest(query: 'almond', limit: 10, datasetPath: workbookPath),
      );

      expect(foods, hasLength(1));
      expect(foods.single.sourceRecordId, '273');
      expect(foods.single.name, 'Almond');
      expect(foods.single.category, 'Nuts');
      expect(
        foods.single.nutrients.any((nutrient) => nutrient.label == 'Protein'),
        isTrue,
      );
    });

    test('runs through sync use case and persists normalized result', () async {
      final tempDir = await Directory.systemTemp.createTemp('swiss-sync');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workbookPath = p.join(tempDir.path, 'swiss.xlsx');
      await _writeSwissWorkbook(workbookPath);

      final repository = MemoryFoodRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [SwissFoodCompositionExcelImporter()],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'ch-swiss-food-db',
        request: ImportRequest(
          query: 'almond',
          limit: 10,
          datasetPath: workbookPath,
        ),
      );

      final results = await repository.searchFoods('almond');
      expect(summary.importedCount, 1);
      expect(results.single.country, 'Switzerland');
    });
  });

  group('AustraliaAfcdImporter', () {
    test('joins food details with nutrient profiles', () async {
      final tempDir = await Directory.systemTemp.createTemp('afcd-importer');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeAfcdFixture(tempDir.path);

      final importer = AustraliaAfcdImporter();
      final foods = await importer.importFoods(
        ImportRequest(query: 'cardamom', limit: 10, datasetPath: tempDir.path),
      );

      expect(foods, hasLength(1));
      expect(foods.single.sourceRecordId, 'F002258');
      expect(foods.single.name, 'Cardamom seed, dried, ground');
      expect(
        foods.single.nutrients.any((nutrient) => nutrient.label == 'Protein'),
        isTrue,
      );
      expect(foods.single.servingBasis, 'Per 100 g');
    });

    test(
      'fails with a controlled error when a required file is missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('afcd-missing');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        await _writeAfcdFoodDetails(
          p.join(tempDir.path, 'AFCD Release 3 - Food Details.xlsx'),
        );

        final importer = AustraliaAfcdImporter();
        expect(
          () => importer.importFoods(
            ImportRequest(query: '', limit: 10, datasetPath: tempDir.path),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Nutrient profiles'),
            ),
          ),
        );
      },
    );

    test('runs through sync use case and persists normalized result', () async {
      final tempDir = await Directory.systemTemp.createTemp('afcd-sync');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await _writeAfcdFixture(tempDir.path);

      final repository = MemoryFoodRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [AustraliaAfcdImporter()],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'au-afcd',
        request: ImportRequest(
          query: 'cardamom',
          limit: 10,
          datasetPath: tempDir.path,
        ),
      );

      final results = await repository.searchFoods('cardamom');
      expect(summary.importedCount, 1);
      expect(results.single.country, 'Australia');
    });
  });

  group('FranceCiqualExcelImporter', () {
    test(
      'parses a minimal official workbook sample with comma decimals',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ciqual-importer',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final workbookPath = p.join(tempDir.path, 'ciqual.xlsx');
        await _writeCiqualWorkbook(workbookPath);

        final importer = FranceCiqualExcelImporter();
        final foods = await importer.importFoods(
          ImportRequest(query: 'anchovy', limit: 10, datasetPath: workbookPath),
        );

        expect(foods, hasLength(1));
        expect(foods.single.sourceRecordId, '7123');
        expect(foods.single.name, 'Anchovy, canned in oil');
        expect(
          foods.single.category,
          'fish and seafood / canned fish / anchovies',
        );
        final protein = foods.single.nutrients.firstWhere(
          (nutrient) => nutrient.label == 'Protein',
        );
        final fiber = foods.single.nutrients.firstWhere(
          (nutrient) => nutrient.label == 'Fiber',
        );
        expect(protein.amount, 28.4);
        expect(fiber.amount, 0);
      },
    );

    test('runs through sync use case and persists normalized result', () async {
      final tempDir = await Directory.systemTemp.createTemp('ciqual-sync');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workbookPath = p.join(tempDir.path, 'ciqual.xlsx');
      await _writeCiqualWorkbook(workbookPath);

      final repository = MemoryFoodRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [FranceCiqualExcelImporter()],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'fr-ciqual',
        request: ImportRequest(
          query: 'anchovy',
          limit: 10,
          datasetPath: workbookPath,
        ),
      );

      final results = await repository.searchFoods('anchovy');
      expect(summary.importedCount, 1);
      expect(results.single.country, 'France');
    });
  });

  group('DenmarkFridaExcelImporter', () {
    test('joins food, parameter, and content sheets', () async {
      final tempDir = await Directory.systemTemp.createTemp('frida-importer');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workbookPath = p.join(tempDir.path, 'frida.xlsx');
      await _writeFridaNormalizedWorkbook(workbookPath);

      final importer = DenmarkFridaExcelImporter();
      final foods = await importer.importFoods(
        ImportRequest(query: 'almond', limit: 10, datasetPath: workbookPath),
      );

      expect(foods, hasLength(1));
      expect(foods.single.sourceRecordId, '35');
      expect(foods.single.name, 'Almond, raw');
      expect(foods.single.category, 'Nuts and high-fat seeds');
      expect(
        foods.single.nutrients.any((nutrient) => nutrient.label == 'Protein'),
        isTrue,
      );
    });

    test('parses a wide Frida-style workbook fallback', () async {
      final tempDir = await Directory.systemTemp.createTemp('frida-wide');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workbookPath = p.join(tempDir.path, 'frida-wide.xlsx');
      await _writeFridaWideWorkbook(workbookPath);

      final importer = DenmarkFridaExcelImporter();
      final foods = await importer.importFoods(
        ImportRequest(query: 'apple', limit: 10, datasetPath: workbookPath),
      );

      expect(foods, hasLength(1));
      expect(foods.single.sourceRecordId, '2');
      expect(foods.single.name, 'Apple, raw, all varieties');
      expect(
        foods.single.nutrients.any((nutrient) => nutrient.label == 'Fiber'),
        isTrue,
      );
    });

    test('runs through sync use case and persists normalized result', () async {
      final tempDir = await Directory.systemTemp.createTemp('frida-sync');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workbookPath = p.join(tempDir.path, 'frida.xlsx');
      await _writeFridaNormalizedWorkbook(workbookPath);

      final repository = MemoryFoodRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [DenmarkFridaExcelImporter()],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'dk-frida',
        request: ImportRequest(
          query: 'almond',
          limit: 10,
          datasetPath: workbookPath,
        ),
      );

      final results = await repository.searchFoods('almond');
      expect(summary.importedCount, 1);
      expect(results.single.country, 'Denmark');
    });
  });
}

Future<void> _writeSwissWorkbook(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Generic Foods');
  _writeRow(excel, 'Generic Foods', 0, [
    'Swiss food composition database – Generic foods V 7.0 (01.07.2025)',
  ]);
  _writeRow(excel, 'Generic Foods', 1, const ['']);
  _writeRow(excel, 'Generic Foods', 2, [
    'ID',
    'ID V 4.0',
    'ID SwissFIR',
    'Name',
    'Synonyms',
    'Category',
    'Density',
    'Matrix unit',
    'Energy, kilocalories (kcal)',
    'Derivation of value',
    'Source',
    'Fat, total (g)',
    'Derivation of value',
    'Source',
    'Carbohydrates, available (g)',
    'Derivation of value',
    'Source',
    'Dietary fibres (g)',
    'Derivation of value',
    'Source',
    'Protein (g)',
    'Derivation of value',
    'Source',
    'Calcium (Ca) (mg)',
    'Derivation of value',
    'Source',
    'Iron (Fe) (mg)',
    'Derivation of value',
    'Source',
  ]);
  _writeRow(excel, 'Generic Foods', 3, [
    '273',
    '4500',
    '841005',
    'Almond',
    'Amande',
    'Nuts',
    '',
    'per 100g edible portion',
    624,
    '-',
    '1542',
    52.1,
    '-',
    '1542',
    7.8,
    '-',
    '1542',
    10.6,
    '-',
    '1542',
    25.6,
    '-',
    '1542',
    270,
    '-',
    '1542',
    3.3,
    '-',
    '1542',
  ]);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> _writeAfcdFixture(String directoryPath) async {
  await _writeAfcdFoodDetails(
    p.join(directoryPath, 'AFCD Release 3 - Food Details.xlsx'),
  );
  await _writeAfcdNutrientProfiles(
    p.join(directoryPath, 'AFCD Release 3 - Nutrient profiles.xlsx'),
  );
  await _writeAfcdNutrientDetails(
    p.join(directoryPath, 'AFCD Release 3 - Nutrient details.xlsx'),
  );
}

Future<void> _writeAfcdFoodDetails(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Food details');
  _writeRow(excel, 'Food details', 0, const ['Release 3 - Food details']);
  _writeRow(excel, 'Food details', 1, const ['']);
  _writeRow(excel, 'Food details', 2, [
    'Public Food Key',
    'Classification',
    'Derivation',
    'Food Name',
    'Food Description',
    'Sampling Details',
    'Nitrogen Factor',
    'Fat Factor',
    'Specific Gravity',
    'Analysed Portion',
    'Unanalysed Portion',
  ]);
  _writeRow(excel, 'Food details', 3, [
    'F002258',
    '31302',
    'Borrowed',
    'Cardamom seed, dried, ground',
    'Ground spice commonly used in Indian cooking.',
    'Borrowed from official AFCD source notes.',
    6.25,
    0.956,
    0,
    '100%',
    '0%',
  ]);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> _writeAfcdNutrientProfiles(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'All solids & liquids per 100 g');
  excel.copy('All solids & liquids per 100 g', 'Liquids only per 100 mL');

  for (final sheetName in const [
    'All solids & liquids per 100 g',
    'Liquids only per 100 mL',
  ]) {
    _writeRow(excel, sheetName, 0, ['Release 3 - Nutrient profiles']);
    _writeRow(excel, sheetName, 1, const ['']);
  }

  _writeRow(excel, 'All solids & liquids per 100 g', 2, [
    'Public Food Key',
    'Classification',
    'Derivation',
    'Food Name',
    'Energy, without dietary fibre, equated (kJ)',
    'Protein (g)',
    'Fat, total (g)',
    'Available carbohydrate, without sugar alcohols (g)',
    'Total dietary fibre (g)',
    'Calcium (Ca) (mg)',
    'Iron (Fe) (mg)',
    'Sodium (Na) (mg)',
    'Vitamin C (mg)',
    'Vitamin D3 equivalents (ug)',
  ]);
  _writeRow(excel, 'All solids & liquids per 100 g', 3, [
    'F002258',
    '31302',
    'Borrowed',
    'Cardamom seed, dried, ground',
    1012,
    10.8,
    6.7,
    34.4,
    28,
    383,
    13.97,
    18,
    21.5,
    0,
  ]);

  _writeRow(excel, 'Liquids only per 100 mL', 2, [
    'Public Food Key',
    'Classification',
    'Derivation',
    'Food Name',
    'Energy, without dietary fibre, equated (kJ)',
  ]);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> _writeAfcdNutrientDetails(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Core nutrients');
  for (final sheetName in const ['Vitamins', 'Minerals', 'Other']) {
    excel.copy('Core nutrients', sheetName);
  }

  _writeDetailSheet(excel, 'Core nutrients', [
    ['Energy, without dietary fibre, equated', 'kJ'],
    ['Protein', 'g'],
    ['Fat, total', 'g'],
    ['Available carbohydrate, without sugar alcohols', 'g'],
    ['Total dietary fibre', 'g'],
  ]);
  _writeDetailSheet(excel, 'Vitamins', [
    ['Vitamin C', 'mg'],
    ['Vitamin D3 equivalents', 'ug'],
  ]);
  _writeDetailSheet(excel, 'Minerals', [
    ['Calcium (Ca)', 'mg'],
    ['Iron (Fe)', 'mg'],
    ['Sodium (Na)', 'mg'],
  ]);
  _writeDetailSheet(excel, 'Other', const []);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> _writeCiqualWorkbook(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'food composition');
  excel['INFOODS codes'];

  _writeRow(excel, 'food composition', 0, [
    'alim_grp_code',
    'alim_ssgrp_code',
    'alim_ssssgrp_code',
    'alim_grp_nom_eng',
    'alim_ssgrp_nom_eng',
    'alim_ssssgrp_nom_eng',
    'alim_code',
    'alim_nom_eng',
    'alim_nom_sci',
    'Energy, Regulation EU No 1169 2011 (kcal 100g)',
    'Water (g 100g)',
    'Protein (g 100g)',
    'Carbohydrate (g 100g)',
    'Fat (g 100g)',
    'Sugars (g 100g)',
    'Fibres (g 100g)',
    'FA saturated (g 100g)',
    'Cholesterol (mg 100g)',
    'Salt (g 100g)',
    'Calcium (mg 100g)',
    'Iron (mg 100g)',
    'Iodine (µg 100g)',
    'Magnesium (mg 100g)',
    'Phosphorus (mg 100g)',
    'Potassium (mg 100g)',
    'Selenium (µg 100g)',
    'Sodium (mg 100g)',
    'Zinc (mg 100g)',
    'Vitamin A activity, retinol equivalent (µg 100mg)',
    'Vitamin D (µg 100g)',
    'Alpha-tocopherol (vitamine E)(mg 100g)',
    'Vitamin C (mg 100g)',
    'Vitamin B1 or Thiamin (mg 100g)',
    'Vitamin B2 or Riboflavin (mg 100g)',
    'Vitamin B3 or Niacin (mg 100g)',
    'Vitamin B5 or Pantothenic acid (mg 100g)',
    'Vitamin B6 (mg 100g)',
    'Vitamin B9 or total folates (µg 100g)',
    'Vitamin B12 (µg 100g)',
  ]);
  _writeRow(excel, 'food composition', 1, [
    '04',
    '0401',
    '040101',
    'fish and seafood',
    'canned fish',
    'anchovies',
    '7123',
    'Anchovy, canned in oil',
    'Engraulis encrasicolus',
    '258',
    '52,1',
    '28,4',
    '0',
    '17,3',
    '0',
    'traces',
    '4,41',
    '85',
    '1,8',
    '232',
    '3,2',
    '25',
    '42',
    '305',
    '221',
    '< 0,2',
    '710',
    '1,6',
    '18',
    '7,5',
    '1,2',
    '0',
    '0,08',
    '0,15',
    '6,1',
    '0,72',
    '0,31',
    '14',
    '2,4',
  ]);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> _writeFridaNormalizedWorkbook(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Food');
  excel['Parameter'];
  excel['Content'];

  _writeRow(excel, 'Food', 0, [
    'Food ID',
    'Name',
    'Danish name',
    'Taxonomic name',
    'Food group',
  ]);
  _writeRow(excel, 'Food', 1, [
    '35',
    'Almond, raw',
    'Mandel, rå',
    'Prunus dulcis',
    'Nuts and high-fat seeds',
  ]);

  _writeRow(excel, 'Parameter', 0, ['Parameter ID', 'Name', 'Unit']);
  _writeRow(excel, 'Parameter', 1, ['3', 'Energy (kcal)', 'kcal']);
  _writeRow(excel, 'Parameter', 2, ['5', 'Protein', 'g']);
  _writeRow(excel, 'Parameter', 3, ['12', 'Dietary fibre', 'g']);
  _writeRow(excel, 'Parameter', 4, ['14', 'Fat', 'g']);
  _writeRow(excel, 'Parameter', 5, ['73', 'Vitamin C', 'mg']);

  _writeRow(excel, 'Content', 0, [
    'Food ID',
    'Parameter ID',
    'Content',
    'Unit',
  ]);
  _writeRow(excel, 'Content', 1, ['35', '3', '606', 'kcal']);
  _writeRow(excel, 'Content', 2, ['35', '5', '21.2', 'g']);
  _writeRow(excel, 'Content', 3, ['35', '12', '10.6', 'g']);
  _writeRow(excel, 'Content', 4, ['35', '14', '52.1', 'g']);
  _writeRow(excel, 'Content', 5, ['35', '73', '0', 'mg']);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<void> _writeFridaWideWorkbook(String path) async {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Food composition');

  _writeRow(excel, 'Food composition', 0, [
    'Food ID',
    'Name',
    'Danish name',
    'Food group',
    'Energy (kcal)',
    'Protein (g)',
    'Dietary fibre (g)',
    'Fat (g)',
    'Vitamin C (mg)',
  ]);
  _writeRow(excel, 'Food composition', 1, [
    '2',
    'Apple, raw, all varieties',
    'Æble, rå',
    'Fruit, berries and their products',
    '52',
    '0.3',
    '2.4',
    '0.2',
    '4.6',
  ]);

  final bytes = excel.encode()!;
  await File(path).writeAsBytes(bytes, flush: true);
}

void _writeDetailSheet(
  Excel excel,
  String sheetName,
  List<List<Object>> componentRows,
) {
  _writeRow(excel, sheetName, 0, ['Release 3 - Nutrient details']);
  _writeRow(excel, sheetName, 1, const ['']);
  _writeRow(excel, sheetName, 2, const ['']);
  _writeRow(excel, sheetName, 3, const ['Component', 'Units']);
  _writeRow(excel, sheetName, 4, const ['Section']);
  for (var i = 0; i < componentRows.length; i++) {
    _writeRow(excel, sheetName, 5 + i, componentRows[i]);
  }
}

void _writeRow(
  Excel excel,
  String sheetName,
  int rowIndex,
  List<Object> values,
) {
  for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
    final value = values[columnIndex];
    excel.updateCell(
      sheetName,
      CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex),
      switch (value) {
        int() => IntCellValue(value),
        double() => DoubleCellValue(value),
        _ => TextCellValue(value.toString()),
      },
    );
  }
}
