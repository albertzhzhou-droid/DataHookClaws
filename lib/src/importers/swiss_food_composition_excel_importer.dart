import 'package:excel/excel.dart';

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class SwissFoodCompositionExcelImporter implements FoodImporter {
  static const _sheetNames = <String>['Generic Foods', 'Branded foods'];
  static const _trackedHeaders = <String, String>{
    'Energy, kilocalories (kcal)': 'Energy',
    'Fat, total (g)': 'Fat',
    'Fatty acids, saturated (g)': 'Saturated fat',
    'Carbohydrates, available (g)': 'Carbohydrate',
    'Sugars (g)': 'Sugars',
    'Dietary fibres (g)': 'Fiber',
    'Protein (g)': 'Protein',
    'Salt (NaCl) (g)': 'Salt equivalent',
    'Water (g)': 'Water',
    'Vitamin A activity, RAE (µg)': 'Vitamin A',
    'Vitamin B1 (thiamine) (mg)': 'Vitamin B1',
    'Vitamin B2 (riboflavin) (mg)': 'Vitamin B2',
    'Vitamin B6 (pyridoxine) (mg)': 'Vitamin B6',
    'Vitamin B12 (cobalamin) (µg)': 'Vitamin B12',
    'Niacin (mg)': 'Niacin',
    'Folate (µg)': 'Folate',
    'Pantothenic acid (mg)': 'Pantothenate',
    'Vitamin C (ascorbic acid) (mg)': 'Vitamin C',
    'Vitamin D (calciferol) (µg)': 'Vitamin D',
    'Vitamin E (α-tocopherol) (mg)': 'Vitamin E',
    'Potassium (K) (mg)': 'Potassium',
    'Sodium (Na) (mg)': 'Sodium',
    'Calcium (Ca) (mg)': 'Calcium',
    'Magnesium (Mg) (mg)': 'Magnesium',
    'Phosphorus (P) (mg)': 'Phosphorus',
    'Iron (Fe) (mg)': 'Iron',
    'Iodide (I) (µg)': 'Iodine',
    'Zinc (Zn) (mg)': 'Zinc',
    'Selenium (Se) (µg)': 'Selenium',
    'Cholesterol (mg)': 'Cholesterol',
  };

  @override
  String get id => 'ch-swiss-food-db';

  @override
  String get displayName => 'Swiss Food Composition Database';

  @override
  String get country => 'Switzerland';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final workbookPath = request.datasetPath?.trim();
    if (workbookPath == null || workbookPath.isEmpty) {
      throw ArgumentError(
        'Swiss importer requires the official Excel file path.',
      );
    }

    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final normalizedQuery = request.query.trim().toLowerCase();
    final foods = <RawFoodRecord>[];

    for (final sheetName in _sheetNames) {
      final sheet = workbook.tables[sheetName];
      if (sheet == null || sheet.rows.length < 4) {
        continue;
      }

      final headers = sheet.rows[2]
          .map(XlsxImportUtils.cellAsString)
          .toList(growable: false);

      for (final row in sheet.rows.skip(3)) {
        final sourceRecordId = _cell(row, 0);
        final name = _cell(row, 3);
        if (sourceRecordId.isEmpty || name.isEmpty) {
          continue;
        }

        final category = _cell(row, 5);
        final synonyms = _cell(row, 4);
        if (normalizedQuery.isNotEmpty &&
            !_matchesQuery(
              normalizedQuery: normalizedQuery,
              name: name,
              category: category,
              synonyms: synonyms,
            )) {
          continue;
        }

        foods.add(
          RawFoodRecord(
            sourceRecordId: sourceRecordId,
            name: name,
            category: category.isEmpty ? 'Swiss food composition' : category,
            country: country,
            sourceName: displayName,
            description: synonyms.isEmpty
                ? 'Imported from the official Swiss food composition workbook.'
                : 'Imported from the official Swiss food composition workbook. Synonyms: $synonyms',
            servingBasis: _cell(row, 7).isEmpty
                ? 'Per 100 g edible portion'
                : _cell(row, 7),
            tags: [
              'official',
              'switzerland',
              'excel import',
              if (sheetName == 'Branded foods') 'branded',
            ],
            nutrients: _extractNutrients(headers: headers, row: row),
            lastUpdated: DateTime(2025, 7, 2),
          ),
        );

        if (foods.length >= request.limit) {
          return foods;
        }
      }
    }

    return foods;
  }

  List<RawNutrientRecord> _extractNutrients({
    required List<String> headers,
    required List<Data?> row,
  }) {
    final nutrients = <RawNutrientRecord>[];
    for (var index = 8; index < headers.length && index < row.length; index++) {
      final rawHeader = headers[index];
      final label = _trackedHeaders[rawHeader];
      if (label == null) {
        continue;
      }

      final amount = XlsxImportUtils.parseNumeric(_cell(row, index));
      if (amount == null) {
        continue;
      }

      nutrients.add(
        RawNutrientRecord(
          label: label,
          amount: amount,
          unit: _unitFromHeader(rawHeader),
        ),
      );
    }
    return nutrients;
  }

  bool _matchesQuery({
    required String normalizedQuery,
    required String name,
    required String category,
    required String synonyms,
  }) {
    return name.toLowerCase().contains(normalizedQuery) ||
        category.toLowerCase().contains(normalizedQuery) ||
        synonyms.toLowerCase().contains(normalizedQuery);
  }

  String _cell(List<Data?> row, int index) {
    if (index >= row.length) {
      return '';
    }
    return XlsxImportUtils.cellAsString(row[index]);
  }

  String _unitFromHeader(String header) {
    final start = header.lastIndexOf('(');
    final end = header.lastIndexOf(')');
    if (start >= 0 && end > start) {
      return header.substring(start + 1, end).trim();
    }
    return '';
  }
}
