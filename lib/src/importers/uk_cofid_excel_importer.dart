import 'package:excel/excel.dart';

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class UkCofidExcelImporter implements FoodImporter {
  static const _primarySheets = <String>[
    '1.3 Proximates',
    '1.4 Inorganics',
    '1.5 Vitamins',
  ];

  @override
  String get id => 'uk-mccance';

  @override
  String get displayName => 'McCance and Widdowson CoFID';

  @override
  String get country => 'United Kingdom';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final workbookPath = request.datasetPath?.trim();
    if (workbookPath == null || workbookPath.isEmpty) {
      throw ArgumentError(
        'UK importer requires the official CoFID Excel file path.',
      );
    }

    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final entries = <String, _UkFoodBuilder>{};

    for (final sheetName in _primarySheets) {
      final sheet = workbook.tables[sheetName];
      if (sheet == null) {
        throw StateError('Expected CoFID sheet not found: $sheetName');
      }

      final headerRow = sheet.rows.isNotEmpty ? sheet.rows.first : const [];
      final headers = headerRow
          .map((cell) => XlsxImportUtils.cellAsString(cell))
          .toList(growable: false);

      for (final row in sheet.rows.skip(3)) {
        final foodCode = _cell(row, 0);
        final foodName = _cell(row, 1);
        if (foodCode.isEmpty || foodName.isEmpty) {
          continue;
        }

        final builder = entries.putIfAbsent(
          foodCode,
          () => _UkFoodBuilder(
            id: 'uk:$foodCode',
            name: foodName,
            category: _cell(row, 3),
            description: _cell(row, 2),
          ),
        );

        for (
          var index = 7;
          index < row.length && index < headers.length;
          index++
        ) {
          final header = headers[index];
          final label = _labelFromHeader(header);
          if (label == null) {
            continue;
          }

          final amount = XlsxImportUtils.parseNumeric(_cell(row, index));
          if (amount == null) {
            continue;
          }

          builder.nutrients[label] = RawNutrientRecord(
            label: label,
            amount: amount,
            unit: _unitFromHeader(header),
          );
        }
      }
    }

    final normalizedQuery = request.query.trim().toLowerCase();
    return entries.values
        .where((entry) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return entry.name.toLowerCase().contains(normalizedQuery) ||
              entry.description.toLowerCase().contains(normalizedQuery) ||
              entry.category.toLowerCase().contains(normalizedQuery);
        })
        .take(request.limit)
        .map((entry) => entry.build(displayName: displayName, country: country))
        .toList(growable: false);
  }

  String _cell(List<Data?> row, int index) {
    if (index >= row.length) {
      return '';
    }
    return XlsxImportUtils.cellAsString(row[index]);
  }

  String? _labelFromHeader(String header) {
    if (header.isEmpty || !header.contains('(')) {
      return null;
    }

    final label = header.split('(').first.trim();
    if (label.isEmpty || label.startsWith('Sat') || label.startsWith('cis-')) {
      return null;
    }
    return label;
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

class _UkFoodBuilder {
  _UkFoodBuilder({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final Map<String, RawNutrientRecord> nutrients = {};

  RawFoodRecord build({required String displayName, required String country}) {
    return RawFoodRecord(
      sourceRecordId: id.replaceFirst('uk:', ''),
      name: name,
      category: category.isEmpty ? 'CoFID' : category,
      country: country,
      sourceName: displayName,
      description: description.isEmpty
          ? 'Imported from the official UK CoFID workbook.'
          : description,
      servingBasis: 'Per 100 g',
      tags: const ['official', 'uk', 'cofid', 'excel import'],
      nutrients: nutrients.values.take(16).toList(growable: false),
      lastUpdated: DateTime(2021, 3, 19),
    );
  }
}
