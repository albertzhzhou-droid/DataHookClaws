import 'package:excel/excel.dart';

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class FranceCiqualExcelImporter implements FoodImporter {
  static const _trackedHeaders = <String, String>{
    'Energy, Regulation EU No 1169 2011 (kcal 100g)': 'Energy',
    'Water (g 100g)': 'Water',
    'Protein (g 100g)': 'Protein',
    'Carbohydrate (g 100g)': 'Carbohydrate',
    'Fat (g 100g)': 'Fat',
    'Sugars (g 100g)': 'Sugars',
    'Fibres (g 100g)': 'Fiber',
    'FA saturated (g 100g)': 'Saturated fat',
    'Cholesterol (mg 100g)': 'Cholesterol',
    'Salt (g 100g)': 'Salt equivalent',
    'Calcium (mg 100g)': 'Calcium',
    'Copper (mg 100g)': 'Copper',
    'Iron (mg 100g)': 'Iron',
    'Iodine (µg 100g)': 'Iodine',
    'Magnesium (mg 100g)': 'Magnesium',
    'Phosphorus (mg 100g)': 'Phosphorus',
    'Potassium (mg 100g)': 'Potassium',
    'Selenium (µg 100g)': 'Selenium',
    'Sodium (mg 100g)': 'Sodium',
    'Zinc (mg 100g)': 'Zinc',
    'Vitamin A activity, retinol equivalent (µg 100mg)': 'Vitamin A',
    'Vitamin D (µg 100g)': 'Vitamin D',
    'Alpha-tocopherol (vitamine E)(mg 100g)': 'Vitamin E',
    'Vitamin E (mg 100g)': 'Vitamin E',
    'Vitamin C (mg 100g)': 'Vitamin C',
    'Vitamin B1 or Thiamin (mg 100g)': 'Vitamin B1',
    'Vitamin B2 or Riboflavin (mg 100g)': 'Vitamin B2',
    'Vitamin B3 or Niacin (mg 100g)': 'Niacin',
    'Vitamin B5 or Pantothenic acid (mg 100g)': 'Pantothenate',
    'Vitamin B6 (mg 100g)': 'Vitamin B6',
    'Vitamin B9 or total folates (µg 100g)': 'Folate',
    'Vitamin B12 (µg 100g)': 'Vitamin B12',
  };

  @override
  String get id => 'fr-ciqual';

  @override
  String get displayName => 'ANSES-CIQUAL';

  @override
  String get country => 'France';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final workbookPath = request.datasetPath?.trim();
    if (workbookPath == null || workbookPath.isEmpty) {
      throw ArgumentError(
        'France importer requires the official CIQUAL workbook path.',
      );
    }

    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final sheet = workbook.tables['food composition'];
    if (sheet == null || sheet.rows.length < 2) {
      throw StateError(
        'CIQUAL workbook is missing the food composition sheet.',
      );
    }

    final headers = sheet.rows.first
        .map(XlsxImportUtils.cellAsString)
        .toList(growable: false);
    final normalizedQuery = request.query.trim().toLowerCase();
    final foods = <RawFoodRecord>[];

    for (final row in sheet.rows.skip(1)) {
      final sourceRecordId = _cell(row, 6);
      final name = _cell(row, 7);
      if (sourceRecordId.isEmpty || name.isEmpty) {
        continue;
      }

      final category = _categoryForRow(row);
      final description = _descriptionForRow(row);
      final scientificName = _cell(row, 8);
      final haystack = '$name $category $description $scientificName'
          .toLowerCase();
      if (normalizedQuery.isNotEmpty && !haystack.contains(normalizedQuery)) {
        continue;
      }

      foods.add(
        RawFoodRecord(
          sourceRecordId: sourceRecordId,
          name: name,
          category: category,
          country: country,
          sourceName: displayName,
          description: description,
          servingBasis: 'Per 100 g edible portion',
          tags: const ['official', 'france', 'ciqual', 'excel import'],
          nutrients: _extractNutrients(headers: headers, row: row),
          lastUpdated: DateTime(2025, 11, 3),
        ),
      );

      if (foods.length >= request.limit) {
        return foods;
      }
    }

    return foods;
  }

  List<RawNutrientRecord> _extractNutrients({
    required List<String> headers,
    required List<Data?> row,
  }) {
    final nutrients = <RawNutrientRecord>[];
    for (var index = 9; index < headers.length && index < row.length; index++) {
      final header = headers[index];
      final label = _trackedHeaders[header];
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
          unit: _unitFromHeader(header),
        ),
      );
    }
    return nutrients;
  }

  String _categoryForRow(List<Data?> row) {
    final parts = [
      _cell(row, 3),
      _cell(row, 4),
      _cell(row, 5),
    ].where((part) => part.isNotEmpty && part != '-').toList(growable: false);
    if (parts.isEmpty) {
      return 'CIQUAL food composition';
    }
    return parts.join(' / ');
  }

  String _descriptionForRow(List<Data?> row) {
    final scientificName = _cell(row, 8);
    if (scientificName.isEmpty) {
      return 'Imported from the official ANSES-CIQUAL 2025 workbook.';
    }
    return 'Imported from the official ANSES-CIQUAL 2025 workbook. Scientific name: $scientificName';
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
    if (start < 0 || end <= start) {
      return '';
    }

    final content = header.substring(start + 1, end).trim();
    if (content.isEmpty) {
      return '';
    }
    return content.split(' ').first.trim();
  }
}
