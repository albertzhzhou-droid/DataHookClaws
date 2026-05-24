import 'package:excel/excel.dart';

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class DenmarkFridaExcelImporter implements FoodImporter {
  static const _trackedNutrients = <String, String>{
    'energy': 'Energy',
    'energy kcal': 'Energy',
    'energy labelling kcal': 'Energy',
    'protein': 'Protein',
    'carbohydrate by difference': 'Carbohydrate',
    'available carbohydrates': 'Carbohydrate',
    'dietary fibre': 'Fiber',
    'fat': 'Fat',
    'water': 'Water',
    'sum sugars': 'Sugars',
    'salt labelling': 'Salt equivalent',
    'sodium': 'Sodium',
    'potassium': 'Potassium',
    'calcium': 'Calcium',
    'magnesium': 'Magnesium',
    'phosphorus': 'Phosphorus',
    'iron': 'Iron',
    'copper': 'Copper',
    'zinc': 'Zinc',
    'manganese': 'Manganese',
    'selenium': 'Selenium',
    'iodine': 'Iodine',
    'vitamin a re': 'Vitamin A',
    'vitamin d': 'Vitamin D',
    'vitamin e': 'Vitamin E',
    'thiamin vitamin b1': 'Vitamin B1',
    'riboflavin vitamin b2': 'Vitamin B2',
    'niacin equivalent ne': 'Niacin',
    'vitamin b6': 'Vitamin B6',
    'pantothenic acid': 'Pantothenate',
    'folate': 'Folate',
    'vitamin b12': 'Vitamin B12',
    'vitamin c': 'Vitamin C',
    'cholesterol': 'Cholesterol',
  };

  @override
  String get id => 'dk-frida';

  @override
  String get displayName => 'Frida';

  @override
  String get country => 'Denmark';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final workbookPath = request.datasetPath?.trim();
    if (workbookPath == null || workbookPath.isEmpty) {
      throw ArgumentError(
        'Denmark Frida importer requires the official Frida spreadsheet path. Download links are sent through the official Frida form.',
      );
    }

    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final normalized = _parseNormalizedWorkbook(workbook, request);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return _parseWideWorkbook(workbook, request);
  }

  List<RawFoodRecord> _parseNormalizedWorkbook(
    Excel workbook,
    ImportRequest request,
  ) {
    final foodSheet = _findSheet(workbook, const ['food', 'foods']);
    final parameterSheet = _findSheet(workbook, const [
      'parameter',
      'parameters',
    ]);
    final contentSheet = _findSheet(workbook, const [
      'content',
      'contents',
      'nutrient content',
      'values',
    ]);
    if (foodSheet == null || parameterSheet == null || contentSheet == null) {
      return const [];
    }

    final foods = _parseFoodRows(foodSheet);
    final parameters = _parseParameterRows(parameterSheet);
    final nutrientsByFood = _parseContentRows(
      contentSheet: contentSheet,
      parameters: parameters,
    );

    final results = <RawFoodRecord>[];
    final normalizedQuery = request.query.trim().toLowerCase();
    for (final food in foods.values) {
      if (!_matchesQuery(food, normalizedQuery)) {
        continue;
      }

      results.add(_toRawRecord(food, nutrientsByFood[food.id] ?? const []));
      if (results.length >= request.limit) {
        return results;
      }
    }
    return results;
  }

  List<RawFoodRecord> _parseWideWorkbook(
    Excel workbook,
    ImportRequest request,
  ) {
    final sheet =
        _findSheet(workbook, const ['food composition', 'food', 'foods']) ??
        (workbook.tables.isEmpty ? null : workbook.tables.values.first);
    if (sheet == null) {
      return const [];
    }

    final headerRowIndex = _findHeaderRow(sheet, const ['id', 'name']);
    if (headerRowIndex == null) {
      throw StateError(
        'Frida workbook is missing a recognizable food table header.',
      );
    }

    final headers = sheet.rows[headerRowIndex]
        .map(XlsxImportUtils.cellAsString)
        .toList(growable: false);
    final headerIndexes = _headerIndexes(headers);
    final idIndex = _indexOfAny(headerIndexes, const [
      'food id',
      'foodid',
      'id',
    ]);
    final nameIndex = _indexOfAny(headerIndexes, const [
      'name',
      'food name',
      'foodname',
      'english name',
    ]);
    if (idIndex == null || nameIndex == null) {
      throw StateError('Frida workbook is missing food id or name columns.');
    }

    final nutrientColumns = <int, _Parameter>{};
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      final label = _trackedLabel(header);
      if (label == null) {
        continue;
      }
      nutrientColumns[index] = _Parameter(
        id: header,
        label: label,
        unit: _unitFromHeader(header),
      );
    }

    final results = <RawFoodRecord>[];
    final normalizedQuery = request.query.trim().toLowerCase();
    for (final row in sheet.rows.skip(headerRowIndex + 1)) {
      final food = _FoodRow(
        id: _cell(row, idIndex),
        name: _cell(row, nameIndex),
        danishName: _cell(
          row,
          _indexOfAny(headerIndexes, const ['danish name', 'danish']) ?? -1,
        ),
        category: _cell(
          row,
          _indexOfAny(headerIndexes, const [
                'group',
                'food group',
                'category',
              ]) ??
              -1,
        ),
        taxonomicName: _cell(
          row,
          _indexOfAny(headerIndexes, const ['taxonomic name', 'taxonomy']) ??
              -1,
        ),
      );
      if (food.id.isEmpty || food.name.isEmpty) {
        continue;
      }
      if (!_matchesQuery(food, normalizedQuery)) {
        continue;
      }

      final nutrients = <RawNutrientRecord>[];
      for (final entry in nutrientColumns.entries) {
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

      results.add(_toRawRecord(food, nutrients));
      if (results.length >= request.limit) {
        return results;
      }
    }
    return results;
  }

  Map<String, _FoodRow> _parseFoodRows(Sheet sheet) {
    final headerRowIndex = _findHeaderRow(sheet, const ['id', 'name']);
    if (headerRowIndex == null) {
      return const {};
    }

    final headers = sheet.rows[headerRowIndex]
        .map(XlsxImportUtils.cellAsString)
        .toList(growable: false);
    final indexes = _headerIndexes(headers);
    final idIndex = _indexOfAny(indexes, const ['food id', 'foodid', 'id']);
    final nameIndex = _indexOfAny(indexes, const [
      'name',
      'food name',
      'foodname',
      'english name',
    ]);
    if (idIndex == null || nameIndex == null) {
      return const {};
    }

    final rows = <String, _FoodRow>{};
    for (final row in sheet.rows.skip(headerRowIndex + 1)) {
      final id = _cell(row, idIndex);
      final name = _cell(row, nameIndex);
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
      rows[id] = _FoodRow(
        id: id,
        name: name,
        danishName: _cell(
          row,
          _indexOfAny(indexes, const ['danish name', 'danish']) ?? -1,
        ),
        category: _cell(
          row,
          _indexOfAny(indexes, const ['group', 'food group', 'category']) ?? -1,
        ),
        taxonomicName: _cell(
          row,
          _indexOfAny(indexes, const ['taxonomic name', 'taxonomy']) ?? -1,
        ),
      );
    }
    return rows;
  }

  Map<String, _Parameter> _parseParameterRows(Sheet sheet) {
    final headerRowIndex = _findHeaderRow(sheet, const ['id', 'name', 'unit']);
    if (headerRowIndex == null) {
      return const {};
    }

    final headers = sheet.rows[headerRowIndex]
        .map(XlsxImportUtils.cellAsString)
        .toList(growable: false);
    final indexes = _headerIndexes(headers);
    final idIndex = _indexOfAny(indexes, const [
      'parameter id',
      'parameterid',
      'id',
    ]);
    final nameIndex = _indexOfAny(indexes, const [
      'name',
      'parameter',
      'parameter name',
    ]);
    final unitIndex = _indexOfAny(indexes, const ['unit', 'units']);
    if (idIndex == null || nameIndex == null) {
      return const {};
    }

    final rows = <String, _Parameter>{};
    for (final row in sheet.rows.skip(headerRowIndex + 1)) {
      final id = _cell(row, idIndex);
      final name = _cell(row, nameIndex);
      if (id.isEmpty || name.isEmpty) {
        continue;
      }
      final label = _trackedLabel(name);
      if (label == null) {
        continue;
      }
      rows[id] = _Parameter(
        id: id,
        label: label,
        unit: unitIndex == null ? '' : _cell(row, unitIndex),
      );
    }
    return rows;
  }

  Map<String, List<RawNutrientRecord>> _parseContentRows({
    required Sheet contentSheet,
    required Map<String, _Parameter> parameters,
  }) {
    final headerRowIndex = _findHeaderRow(contentSheet, const [
      'food',
      'parameter',
      'content',
    ]);
    if (headerRowIndex == null || parameters.isEmpty) {
      return const {};
    }

    final headers = contentSheet.rows[headerRowIndex]
        .map(XlsxImportUtils.cellAsString)
        .toList(growable: false);
    final indexes = _headerIndexes(headers);
    final foodIdIndex = _indexOfAny(indexes, const [
      'food id',
      'foodid',
      'food',
    ]);
    final parameterIdIndex = _indexOfAny(indexes, const [
      'parameter id',
      'parameterid',
      'parameter',
    ]);
    final amountIndex = _indexOfAny(indexes, const [
      'content',
      'amount',
      'value',
      'cont 100g',
      'cont /100g',
    ]);
    final unitIndex = _indexOfAny(indexes, const ['unit', 'units']);
    if (foodIdIndex == null ||
        parameterIdIndex == null ||
        amountIndex == null) {
      return const {};
    }

    final byFood = <String, List<RawNutrientRecord>>{};
    for (final row in contentSheet.rows.skip(headerRowIndex + 1)) {
      final foodId = _cell(row, foodIdIndex);
      final parameter = parameters[_cell(row, parameterIdIndex)];
      if (foodId.isEmpty || parameter == null) {
        continue;
      }
      final amount = XlsxImportUtils.parseNumeric(_cell(row, amountIndex));
      if (amount == null) {
        continue;
      }
      byFood
          .putIfAbsent(foodId, () => [])
          .add(
            RawNutrientRecord(
              label: parameter.label,
              amount: amount,
              unit: unitIndex == null || _cell(row, unitIndex).isEmpty
                  ? parameter.unit
                  : _cell(row, unitIndex),
            ),
          );
    }
    return byFood;
  }

  RawFoodRecord _toRawRecord(_FoodRow food, List<RawNutrientRecord> nutrients) {
    final descriptionParts = [
      'Imported from the official Frida spreadsheet.',
      if (food.danishName.isNotEmpty) 'Danish name: ${food.danishName}.',
      if (food.taxonomicName.isNotEmpty)
        'Taxonomic name: ${food.taxonomicName}.',
    ];
    return RawFoodRecord(
      sourceRecordId: food.id,
      name: food.name,
      category: food.category.isEmpty
          ? 'Frida food composition'
          : food.category,
      country: country,
      sourceName: displayName,
      description: descriptionParts.join(' '),
      servingBasis: 'Per 100 g edible portion',
      tags: const ['official', 'denmark', 'frida', 'excel import'],
      nutrients: nutrients,
      lastUpdated: DateTime(2025, 12, 19),
    );
  }

  Sheet? _findSheet(Excel workbook, List<String> names) {
    for (final entry in workbook.tables.entries) {
      final normalized = _normalizeKey(entry.key);
      if (names.any((name) => normalized == _normalizeKey(name))) {
        return entry.value;
      }
    }
    return null;
  }

  int? _findHeaderRow(Sheet sheet, List<String> requiredFragments) {
    final maxRows = sheet.rows.length < 12 ? sheet.rows.length : 12;
    for (var index = 0; index < maxRows; index++) {
      final headers = sheet.rows[index]
          .map((cell) => _normalizeKey(XlsxImportUtils.cellAsString(cell)))
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final hasAll = requiredFragments.every(
        (fragment) =>
            headers.any((header) => header.contains(_normalizeKey(fragment))),
      );
      if (hasAll) {
        return index;
      }
    }
    return null;
  }

  Map<String, int> _headerIndexes(List<String> headers) {
    final indexes = <String, int>{};
    for (var index = 0; index < headers.length; index++) {
      indexes[_normalizeKey(headers[index])] = index;
    }
    return indexes;
  }

  int? _indexOfAny(Map<String, int> indexes, List<String> candidates) {
    for (final candidate in candidates) {
      final normalized = _normalizeKey(candidate);
      final exact = indexes[normalized];
      if (exact != null) {
        return exact;
      }
      for (final entry in indexes.entries) {
        if (entry.key.contains(normalized)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  bool _matchesQuery(_FoodRow food, String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final haystack =
        '${food.id} ${food.name} ${food.danishName} ${food.category} ${food.taxonomicName}'
            .toLowerCase();
    return haystack.contains(normalizedQuery);
  }

  String? _trackedLabel(String raw) {
    final normalized = _normalizeNutrient(raw);
    return _trackedNutrients[normalized];
  }

  String _normalizeNutrient(String raw) {
    return raw
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeKey(String raw) {
    return raw
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _unitFromHeader(String header) {
    final start = header.lastIndexOf('(');
    final end = header.lastIndexOf(')');
    if (start >= 0 && end > start) {
      return header.substring(start + 1, end).trim();
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

class _FoodRow {
  const _FoodRow({
    required this.id,
    required this.name,
    required this.danishName,
    required this.category,
    required this.taxonomicName,
  });

  final String id;
  final String name;
  final String danishName;
  final String category;
  final String taxonomicName;
}

class _Parameter {
  const _Parameter({required this.id, required this.label, required this.unit});

  final String id;
  final String label;
  final String unit;
}
