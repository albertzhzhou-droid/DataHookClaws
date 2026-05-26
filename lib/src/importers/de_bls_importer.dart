import 'package:excel/excel.dart';

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class DeBlsImporter implements FoodImporter {
  static const _trackedCodes = <String, String>{
    'ENERCJ': 'Energy',
    'ENERCC': 'Energy',
    'WATER': 'Water',
    'PROT625': 'Protein',
    'FAT': 'Fat',
    'CHO': 'Carbohydrate',
    'FIBT': 'Fiber',
    'SUGAR': 'Sugars',
    'FASAT': 'Saturated fat',
    'CHOL': 'Cholesterol',
    'NA': 'Sodium',
    'K': 'Potassium',
    'CA': 'Calcium',
    'MG': 'Magnesium',
    'P': 'Phosphorus',
    'FE': 'Iron',
    'ZN': 'Zinc',
    'CU': 'Copper',
    'MN': 'Manganese',
    'SE': 'Selenium',
    'I': 'Iodine',
    'VITD': 'Vitamin D',
    'VITC': 'Vitamin C',
    'THIA': 'Vitamin B1',
    'RIBF': 'Vitamin B2',
    'NIA': 'Niacin',
    'PANTAC': 'Pantothenate',
    'VITB6A': 'Vitamin B6',
    'FOL': 'Folate',
    'VITB12': 'Vitamin B12',
  };

  @override
  String get id => 'de-bls';

  @override
  String get displayName => 'Bundeslebensmittelschlüssel (BLS)';

  @override
  String get country => 'Germany';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final workbookPath = request.datasetPath?.trim();
    if (workbookPath == null || workbookPath.isEmpty) {
      throw ArgumentError(
        'Germany BLS importer requires the official BLS workbook path.',
      );
    }

    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final sheet = _findMainSheet(workbook);
    final headerRowIndex = _findHeaderRow(sheet);
    if (headerRowIndex == null) {
      throw StateError(
        'BLS workbook is missing the expected BLS Code / Lebensmittelbezeichnung header row.',
      );
    }

    final headers = sheet.rows[headerRowIndex]
        .map(XlsxImportUtils.cellAsString)
        .toList(growable: false);
    final nutrientColumns = _trackedNutrientColumns(headers);
    final normalizedQuery = request.query.trim().toLowerCase();
    final foods = <RawFoodRecord>[];

    for (final row in sheet.rows.skip(headerRowIndex + 1)) {
      final sourceRecordId = _cell(row, 0);
      final name = _cell(row, 1);
      final englishName = _cell(row, 2);
      if (sourceRecordId.isEmpty || name.isEmpty) {
        continue;
      }

      final category = _categoryForCode(sourceRecordId);
      final description = englishName.isEmpty
          ? 'Imported from the official BLS 4.0 workbook.'
          : 'Imported from the official BLS 4.0 workbook. English name: $englishName';
      final haystack = '$sourceRecordId $name $englishName $category'
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
          tags: const ['official', 'germany', 'bls', 'excel import'],
          nutrients: _extractNutrients(
            row: row,
            nutrientColumns: nutrientColumns,
          ),
          lastUpdated: DateTime(2025, 12, 17),
        ),
      );

      if (foods.length >= request.limit) {
        return foods;
      }
    }

    return foods;
  }

  Sheet _findMainSheet(Excel workbook) {
    for (final sheet in workbook.tables.values) {
      if (_findHeaderRow(sheet) != null) {
        return sheet;
      }
    }
    if (workbook.tables.isEmpty) {
      throw StateError('BLS workbook does not contain any worksheets.');
    }
    return workbook.tables.values.first;
  }

  int? _findHeaderRow(Sheet sheet) {
    for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex]
          .map(XlsxImportUtils.cellAsString)
          .toList(growable: false);
      if (row.length < 3) {
        continue;
      }
      final first = row[0].toLowerCase();
      final second = row[1].toLowerCase();
      final third = row[2].toLowerCase();
      final matchesCode =
          first == 'bls code' || first == 'sbbs' || first == 'sbis';
      if (!matchesCode && !first.contains('bls code')) {
        continue;
      }
      if (second.contains('lebensmittelbezeichnung') &&
          third.contains('food name')) {
        return rowIndex;
      }
    }
    return null;
  }

  Map<int, _TrackedNutrientColumn> _trackedNutrientColumns(
    List<String> headers,
  ) {
    final columns = <int, _TrackedNutrientColumn>{};
    for (var index = 3; index < headers.length; index += 3) {
      final header = headers[index].trim();
      if (header.isEmpty) {
        continue;
      }
      final label = _labelForHeader(header);
      if (label == null) {
        continue;
      }
      columns[index] = _TrackedNutrientColumn(
        label: label,
        unit: _unitFromHeader(header),
      );
    }
    return columns;
  }

  List<RawNutrientRecord> _extractNutrients({
    required List<Data?> row,
    required Map<int, _TrackedNutrientColumn> nutrientColumns,
  }) {
    final nutrients = <RawNutrientRecord>[];
    for (final entry in nutrientColumns.entries) {
      if (entry.key >= row.length) {
        continue;
      }
      final amount = XlsxImportUtils.parseNumeric(_cell(row, entry.key));
      if (amount == null) {
        continue;
      }
      nutrients.add(
        RawNutrientRecord(
          label: entry.value.label,
          amount: amount,
          unit: entry.value.unit,
        ),
      );
    }
    return nutrients;
  }

  String? _labelForHeader(String header) {
    final code = header.split(' ').first.trim().toUpperCase();
    final direct = _trackedCodes[code];
    if (direct != null) {
      return direct;
    }

    final normalized = header.toLowerCase();
    if (normalized.contains('vitamin a')) {
      return 'Vitamin A';
    }
    if (normalized.contains('vitamin d')) {
      return 'Vitamin D';
    }
    if (normalized.contains('vitamin e')) {
      return 'Vitamin E';
    }
    if (normalized.contains('vitamin c') || normalized.contains('ascorb')) {
      return 'Vitamin C';
    }
    if (normalized.contains('vitamin b1') || normalized.contains('thiamin')) {
      return 'Vitamin B1';
    }
    if (normalized.contains('vitamin b2') ||
        normalized.contains('riboflavin')) {
      return 'Vitamin B2';
    }
    if (normalized.contains('niacin')) {
      return 'Niacin';
    }
    if (normalized.contains('pantoth')) {
      return 'Pantothenate';
    }
    if (normalized.contains('vitamin b6') || normalized.contains('pyridox')) {
      return 'Vitamin B6';
    }
    if (normalized.contains('folat') ||
        normalized.contains('folsäure') ||
        normalized.contains('folic')) {
      return 'Folate';
    }
    if (normalized.contains('vitamin b12') ||
        normalized.contains('cobalamin')) {
      return 'Vitamin B12';
    }
    if (normalized.contains('protein')) {
      return 'Protein';
    }
    if (normalized.contains('fat') || normalized.contains('fett')) {
      return normalized.contains('saturated') ? 'Saturated fat' : 'Fat';
    }
    if (normalized.contains('carbohyd') ||
        normalized.contains('kohlenhydrat')) {
      return 'Carbohydrate';
    }
    if (normalized.contains('fiber') ||
        normalized.contains('fibre') ||
        normalized.contains('ballast')) {
      return 'Fiber';
    }
    if (normalized.contains('sugar') || normalized.contains('zucker')) {
      return 'Sugars';
    }
    if (normalized.contains('water') || normalized.contains('wasser')) {
      return 'Water';
    }
    if (normalized.contains('energy') || normalized.contains('energie')) {
      return 'Energy';
    }
    if (normalized.contains('cholesterol')) {
      return 'Cholesterol';
    }
    if (normalized.contains('natrium') || normalized.contains('sodium')) {
      return 'Sodium';
    }
    if (normalized.contains('kalium') || normalized.contains('potassium')) {
      return 'Potassium';
    }
    if (normalized.contains('calcium')) {
      return 'Calcium';
    }
    if (normalized.contains('magnesium')) {
      return 'Magnesium';
    }
    if (normalized.contains('phosphor') || normalized.contains('phosphorus')) {
      return 'Phosphorus';
    }
    if (normalized.contains('eisen') || normalized.contains('iron')) {
      return 'Iron';
    }
    if (normalized.contains('zink') || normalized.contains('zinc')) {
      return 'Zinc';
    }
    if (normalized.contains('kupfer') || normalized.contains('copper')) {
      return 'Copper';
    }
    if (normalized.contains('mangan')) {
      return 'Manganese';
    }
    if (normalized.contains('selen')) {
      return 'Selenium';
    }
    if (normalized.contains('iod') || normalized.contains('jod')) {
      return 'Iodine';
    }
    return null;
  }

  String _categoryForCode(String sourceRecordId) {
    final groupCode = sourceRecordId.trim().isEmpty
        ? '?'
        : sourceRecordId.trim()[0].toUpperCase();
    return 'BLS group $groupCode';
  }

  String _unitFromHeader(String header) {
    final start = header.lastIndexOf('[');
    final end = header.lastIndexOf(']');
    if (start >= 0 && end > start) {
      final unit = header.substring(start + 1, end).trim();
      return unit.split('/').first.trim();
    }

    final parenStart = header.lastIndexOf('(');
    final parenEnd = header.lastIndexOf(')');
    if (parenStart >= 0 && parenEnd > parenStart) {
      final unit = header.substring(parenStart + 1, parenEnd).trim();
      return unit.split('/').first.trim();
    }
    return '';
  }

  String _cell(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return XlsxImportUtils.cellAsString(row[index]);
  }
}

class _TrackedNutrientColumn {
  const _TrackedNutrientColumn({required this.label, required this.unit});

  final String label;
  final String unit;
}
