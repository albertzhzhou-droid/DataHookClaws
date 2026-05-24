import 'package:excel/excel.dart';

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class JapanStandardFoodExcelImporter implements FoodImporter {
  static const _sheetNames = <String>[
    '1穀類',
    '2いも及びでん粉類',
    '3砂糖及び甘味類',
    '4豆類',
    '5種実類',
    '6野菜類',
    '7果実類',
    '8きのこ類',
    '9藻類',
    '10魚介類',
    '11肉類',
    '12卵類',
    '13乳類',
    '14油脂類',
    '15菓子類',
    '16し好飲料類',
    '17調味料及び香辛料類',
    '18調理済み流通食品類',
  ];

  static const _trackedCodes = <String, String>{
    'ENERC_KCAL': 'Energy',
    'PROT-': 'Protein',
    'FAT-': 'Fat',
    'CHOCDF-': 'Carbohydrate',
    'FIB-': 'Fiber',
    'NA': 'Sodium',
    'K': 'Potassium',
    'CA': 'Calcium',
    'FE': 'Iron',
    'VITA_RAE': 'Vitamin A',
    'VITD': 'Vitamin D',
    'TOCPHA': 'Vitamin E',
    'THIA': 'Vitamin B1',
    'RIBF': 'Vitamin B2',
    'VITC': 'Vitamin C',
    'NACL_EQ': 'Salt equivalent',
  };

  @override
  String get id => 'jp-standard';

  @override
  String get displayName => 'Japan Standard Tables of Food Composition';

  @override
  String get country => 'Japan';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final workbookPath = request.datasetPath?.trim();
    if (workbookPath == null || workbookPath.isEmpty) {
      throw ArgumentError(
        'Japan importer requires the official Excel file path.',
      );
    }

    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final normalizedQuery = request.query.trim().toLowerCase();
    final foods = <RawFoodRecord>[];

    for (final sheetName in _sheetNames) {
      final sheet = workbook.tables[sheetName];
      if (sheet == null || sheet.rows.length < 13) {
        continue;
      }

      final unitsRow = sheet.rows[10];
      final codesRow = sheet.rows[11];
      final trackedColumns = <int, NutrientMeta>{};

      for (var index = 0; index < codesRow.length; index++) {
        final code = XlsxImportUtils.cellAsString(codesRow[index]);
        final label = _trackedCodes[code];
        if (label == null) {
          continue;
        }

        trackedColumns[index] = NutrientMeta(
          label: label,
          unit: XlsxImportUtils.cellAsString(
            index < unitsRow.length ? unitsRow[index] : null,
          ),
        );
      }

      for (final row in sheet.rows.skip(12)) {
        final foodCode = _cell(row, 1);
        final foodName = _cell(row, 3);
        if (foodCode.isEmpty || foodName.isEmpty) {
          continue;
        }

        if (normalizedQuery.isNotEmpty &&
            !foodName.toLowerCase().contains(normalizedQuery)) {
          continue;
        }

        final nutrients = <RawNutrientRecord>[];
        for (final entry in trackedColumns.entries) {
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
              unit: _normalizeUnit(entry.value.unit),
            ),
          );
        }

        foods.add(
          RawFoodRecord(
            sourceRecordId: foodCode,
            name: foodName,
            category: sheetName,
            country: country,
            sourceName: displayName,
            description: _cell(row, 61).isEmpty
                ? 'Imported from the official Japan food composition workbook.'
                : _cell(row, 61),
            servingBasis: 'Per 100 g edible portion',
            tags: const ['official', 'japan', 'mext', 'excel import'],
            nutrients: nutrients,
            lastUpdated: DateTime(2026, 3, 27),
          ),
        );

        if (foods.length >= request.limit) {
          return foods;
        }
      }
    }

    return foods;
  }

  String _cell(List<Data?> row, int index) {
    if (index >= row.length) {
      return '';
    }
    return XlsxImportUtils.cellAsString(row[index]);
  }

  String _normalizeUnit(String raw) {
    final unit = raw.replaceAll(RegExp(r'[\(\)・…\s]'), '');
    if (unit.isEmpty) {
      return '';
    }
    if (unit == 'kcal' ||
        unit == 'kJ' ||
        unit == '%' ||
        unit == 'mg' ||
        unit == 'μg') {
      return unit;
    }
    if (unit.contains('g')) {
      return 'g';
    }
    if (unit.contains('mg')) {
      return 'mg';
    }
    if (unit.contains('μg') || unit.contains('ug')) {
      return 'μg';
    }
    return unit;
  }
}

class NutrientMeta {
  const NutrientMeta({required this.label, required this.unit});

  final String label;
  final String unit;
}
