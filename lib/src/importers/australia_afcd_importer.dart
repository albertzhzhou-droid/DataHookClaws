import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'xlsx_import_utils.dart';

class AustraliaAfcdImporter implements FoodImporter {
  static const _requiredFiles = <String, String>{
    'food_details': 'AFCD Release 3 - Food Details.xlsx',
    'nutrient_profiles': 'AFCD Release 3 - Nutrient profiles.xlsx',
    'nutrient_details': 'AFCD Release 3 - Nutrient details.xlsx',
  };

  static const _optionalFiles = <String, String>{
    'food_group_information': 'AFCD Release 3 - Food group information.xlsx',
  };

  static const _trackedNutrients = <String, String>{
    'Energy, without dietary fibre, equated': 'Energy',
    'Protein': 'Protein',
    'Fat, total': 'Fat',
    'Available carbohydrate, without sugar alcohols': 'Carbohydrate',
    'Total dietary fibre': 'Fiber',
    'Total sugars': 'Sugars',
    'Moisture (water)': 'Water',
    'Calcium (Ca)': 'Calcium',
    'Iron (Fe)': 'Iron',
    'Magnesium (Mg)': 'Magnesium',
    'Phosphorus (P)': 'Phosphorus',
    'Potassium (K)': 'Potassium',
    'Sodium (Na)': 'Sodium',
    'Zinc (Zn)': 'Zinc',
    'Selenium (Se)': 'Selenium',
    'Iodine (I)': 'Iodine',
    'Vitamin A retinol equivalents': 'Vitamin A',
    'Thiamin (B1)': 'Vitamin B1',
    'Riboflavin (B2)': 'Vitamin B2',
    'Pyridoxine (B6)': 'Vitamin B6',
    'Cobalamin (B12)': 'Vitamin B12',
    'Niacin derived equivalents': 'Niacin',
    'Total folates': 'Folate',
    'Vitamin C': 'Vitamin C',
    'Vitamin D3 equivalents': 'Vitamin D',
    'Vitamin E': 'Vitamin E',
    'Cholesterol': 'Cholesterol',
  };

  @override
  String get id => 'au-afcd';

  @override
  String get displayName => 'Australian Food Composition Database';

  @override
  String get country => 'Australia';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final datasetPath = request.datasetPath?.trim();
    if (datasetPath == null || datasetPath.isEmpty) {
      throw ArgumentError(
        'Australia importer requires the prepared AFCD data files directory.',
      );
    }

    final datasetDirectory = Directory(datasetPath);
    if (!datasetDirectory.existsSync()) {
      throw StateError('AFCD directory not found: $datasetPath');
    }

    final resolvedFiles = _resolveFiles(datasetDirectory);
    final foodWorkbook = XlsxImportUtils.loadWorkbook(
      resolvedFiles['food_details']!,
    );
    final profileWorkbook = XlsxImportUtils.loadWorkbook(
      resolvedFiles['nutrient_profiles']!,
    );
    final detailsWorkbook = XlsxImportUtils.loadWorkbook(
      resolvedFiles['nutrient_details']!,
    );
    final groupWorkbookPath = resolvedFiles['food_group_information'];

    final foodSheet = foodWorkbook.tables['Food details'];
    if (foodSheet == null || foodSheet.rows.length < 4) {
      throw StateError('AFCD Food details sheet is missing or empty.');
    }

    final solidsSheet =
        profileWorkbook.tables['All solids & liquids per 100 g'];
    final liquidsSheet = profileWorkbook.tables['Liquids only per 100 mL'];
    if (solidsSheet == null || liquidsSheet == null) {
      throw StateError(
        'AFCD Nutrient profiles workbook is missing required profile sheets.',
      );
    }

    final groupNames = groupWorkbookPath == null
        ? const <String, String>{}
        : _parseFoodGroups(groupWorkbookPath);
    final supportedNutrients = _loadSupportedNutrients(detailsWorkbook);
    final solidsProfiles = _parseProfileSheet(
      sheet: solidsSheet,
      supportedNutrients: supportedNutrients,
      servingBasis: 'Per 100 g',
    );
    final liquidProfiles = _parseProfileSheet(
      sheet: liquidsSheet,
      supportedNutrients: supportedNutrients,
      servingBasis: 'Per 100 mL',
    );

    final foodRows = <RawFoodRecord>[];
    final normalizedQuery = request.query.trim().toLowerCase();

    for (final row in foodSheet.rows.skip(3)) {
      final publicFoodKey = _cell(row, 0);
      final classification = _cell(row, 1);
      final foodName = _cell(row, 3);
      final foodDescription = _cell(row, 4);
      final samplingDetails = _cell(row, 5);
      if (publicFoodKey.isEmpty || foodName.isEmpty) {
        continue;
      }

      final profile =
          solidsProfiles[publicFoodKey] ?? liquidProfiles[publicFoodKey];
      if (profile == null) {
        continue;
      }

      final category =
          groupNames[classification] ??
          _fallbackCategory(classification: classification);
      final haystack = '$foodName $foodDescription $samplingDetails $category'
          .toLowerCase();
      if (normalizedQuery.isNotEmpty && !haystack.contains(normalizedQuery)) {
        continue;
      }

      final description = [
        if (foodDescription.isNotEmpty) foodDescription,
        if (samplingDetails.isNotEmpty) samplingDetails,
      ].join(' ');

      foodRows.add(
        RawFoodRecord(
          sourceRecordId: publicFoodKey,
          name: foodName,
          category: category,
          country: country,
          sourceName: displayName,
          description: description.isEmpty
              ? 'Imported from the official AFCD data files.'
              : description,
          servingBasis: profile.servingBasis,
          tags: const ['official', 'australia', 'afcd', 'excel import'],
          nutrients: profile.nutrients,
          lastUpdated: DateTime(2025, 12, 23),
        ),
      );

      if (foodRows.length >= request.limit) {
        return foodRows;
      }
    }

    return foodRows;
  }

  Map<String, String> _resolveFiles(Directory root) {
    final found = <String, String>{};
    for (final entry in root.listSync(recursive: true)) {
      if (entry is! File || p.extension(entry.path).toLowerCase() != '.xlsx') {
        continue;
      }
      final name = p.basename(entry.path).toLowerCase();
      for (final fileEntry in {..._requiredFiles, ..._optionalFiles}.entries) {
        if (name == fileEntry.value.toLowerCase()) {
          found[fileEntry.key] = entry.path;
        }
      }
    }

    for (final required in _requiredFiles.entries) {
      if (!found.containsKey(required.key)) {
        throw StateError('AFCD importer requires ${required.value} in $root.');
      }
    }

    return found;
  }

  Map<String, _AfcdProfile> _parseProfileSheet({
    required Sheet sheet,
    required Set<String> supportedNutrients,
    required String servingBasis,
  }) {
    final headers = sheet.rows[2].map(XlsxImportUtils.cellAsString).toList();
    final trackedColumns = <int, RawNutrientRecord Function(String)>{};
    for (var index = 4; index < headers.length; index++) {
      final header = headers[index];
      final baseHeader = _baseHeader(header);
      final label = _trackedNutrients[baseHeader];
      if (label == null || !supportedNutrients.contains(baseHeader)) {
        continue;
      }

      trackedColumns[index] = (rawValue) => RawNutrientRecord(
        label: label,
        amount: XlsxImportUtils.parseNumeric(rawValue) ?? 0,
        unit: _unitFromHeader(header),
      );
    }

    final profiles = <String, _AfcdProfile>{};
    for (final row in sheet.rows.skip(3)) {
      final publicFoodKey = _cell(row, 0);
      if (publicFoodKey.isEmpty) {
        continue;
      }

      final nutrients = <RawNutrientRecord>[];
      for (final entry in trackedColumns.entries) {
        if (entry.key >= row.length) {
          continue;
        }
        final rawValue = _cell(row, entry.key);
        if (XlsxImportUtils.parseNumeric(rawValue) == null) {
          continue;
        }
        nutrients.add(entry.value(rawValue));
      }

      profiles[publicFoodKey] = _AfcdProfile(
        servingBasis: servingBasis,
        nutrients: nutrients,
      );
    }
    return profiles;
  }

  Set<String> _loadSupportedNutrients(Excel detailsWorkbook) {
    final supported = <String>{};
    for (final sheetName in const [
      'Core nutrients',
      'Vitamins',
      'Minerals',
      'Other',
    ]) {
      final sheet = detailsWorkbook.tables[sheetName];
      if (sheet == null || sheet.rows.length < 6) {
        continue;
      }
      for (final row in sheet.rows.skip(5)) {
        final component = _cell(row, 0);
        if (component.isEmpty) {
          continue;
        }
        supported.add(component);
      }
    }
    return supported;
  }

  Map<String, String> _parseFoodGroups(String workbookPath) {
    final workbook = XlsxImportUtils.loadWorkbook(workbookPath);
    final sheet = workbook.tables['Food group information'];
    if (sheet == null || sheet.rows.length < 5) {
      return const {};
    }

    final groups = <String, String>{};
    var currentTopLevel = '';
    for (final row in sheet.rows.skip(4)) {
      final first = _cell(row, 0);
      final second = _cell(row, 1);
      if (first.isEmpty) {
        continue;
      }

      final topLevelId = int.tryParse(first);
      if (topLevelId != null && second.isNotEmpty) {
        currentTopLevel = second;
        groups['$topLevelId'] = second;
        continue;
      }

      if (!first.contains('-')) {
        continue;
      }
      final subgroupCode = first.split(' ').first.trim();
      if (subgroupCode.isEmpty) {
        continue;
      }
      groups[subgroupCode] = currentTopLevel.isEmpty
          ? first
          : '$currentTopLevel / $first';
    }
    return groups;
  }

  String _fallbackCategory({required String classification}) {
    if (classification.isEmpty) {
      return 'AFCD food composition';
    }
    return 'AFCD classification $classification';
  }

  String _cell(List<Data?> row, int index) {
    if (index >= row.length) {
      return '';
    }
    return XlsxImportUtils.cellAsString(row[index]);
  }

  String _baseHeader(String header) {
    return header.replaceAll(RegExp(r'\s+'), ' ').split('(').first.trim();
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

class _AfcdProfile {
  const _AfcdProfile({required this.servingBasis, required this.nutrients});

  final String servingBasis;
  final List<RawNutrientRecord> nutrients;
}
