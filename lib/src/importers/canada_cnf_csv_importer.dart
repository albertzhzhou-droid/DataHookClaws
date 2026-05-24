import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';

class CanadaCnfCsvImporter implements FoodImporter {
  @override
  String get id => 'canada-cnf';

  @override
  String get displayName => 'Canadian Nutrient File';

  @override
  String get country => 'Canada';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final directoryPath = request.datasetPath?.trim();
    if (directoryPath == null || directoryPath.isEmpty) {
      throw ArgumentError('Canadian importer requires a CSV directory path.');
    }

    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      throw StateError('Directory not found: $directoryPath');
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .toList(growable: false);

    final foodFile = _findFile(directoryPath, files, ['food', 'name']);
    final nutrientAmountFile = _findFile(directoryPath, files, [
      'nutrient',
      'amount',
    ]);
    final nutrientNameFile = _findFile(directoryPath, files, [
      'nutrient',
      'name',
    ]);

    final foodRows = await _readCsvRows(foodFile);
    final nutrientAmountRows = await _readCsvRows(nutrientAmountFile);
    final nutrientNameRows = await _readCsvRows(nutrientNameFile);

    final nutrientDefinitions = {
      for (final row in nutrientNameRows)
        row['nutrientnameid'] ?? '': (
          name: row['nutrientname'] ?? row['tagname'] ?? 'Unknown nutrient',
          unit: row['unit'] ?? '',
        ),
    };

    final nutrientsByFood = <String, List<RawNutrientRecord>>{};
    for (final row in nutrientAmountRows) {
      final foodId = row['foodid'] ?? '';
      final nutrientId = row['nutrientnameid'] ?? '';
      final nutrientDefinition = nutrientDefinitions[nutrientId];
      final value = double.tryParse(row['nutrientvalue'] ?? '');
      if (foodId.isEmpty || nutrientDefinition == null || value == null) {
        continue;
      }

      nutrientsByFood.putIfAbsent(foodId, () => []);
      nutrientsByFood[foodId]!.add(
        RawNutrientRecord(
          label: nutrientDefinition.name,
          amount: value,
          unit: nutrientDefinition.unit,
        ),
      );
    }

    final normalizedQuery = request.query.trim().toLowerCase();
    final foods = <RawFoodRecord>[];

    for (final row in foodRows) {
      final foodId = row['foodid'] ?? '';
      final description = row['fooddescription'] ?? '';
      if (foodId.isEmpty || description.isEmpty) {
        continue;
      }

      if (normalizedQuery.isNotEmpty &&
          !description.toLowerCase().contains(normalizedQuery)) {
        continue;
      }

      foods.add(
        RawFoodRecord(
          sourceRecordId: foodId,
          name: description,
          category: row['foodgroupid']?.isNotEmpty == true
              ? 'Group ${row['foodgroupid']}'
              : 'Canadian Nutrient File',
          country: country,
          sourceName: displayName,
          description:
              'Imported from official Canadian Nutrient File CSV package.',
          servingBasis: 'Per 100 g',
          tags: const ['official', 'cnf', 'csv import'],
          nutrients: (nutrientsByFood[foodId] ?? const [])
              .take(12)
              .toList(growable: false),
          lastUpdated:
              DateTime.tryParse(row['fooddateofentry'] ?? '') ?? DateTime.now(),
        ),
      );

      if (foods.length >= request.limit) {
        break;
      }
    }

    return foods;
  }

  Future<List<Map<String, String>>> _readCsvRows(String path) async {
    final content = await File(path).readAsString(encoding: utf8);
    final rawRows = const CsvDecoder(dynamicTyping: false).convert(content);
    if (rawRows.isEmpty) {
      return const [];
    }

    final headers = rawRows.first
        .map((cell) => cell.toString().trim().toLowerCase().replaceAll(' ', ''))
        .toList(growable: false);

    return rawRows
        .skip(1)
        .map((row) {
          final mapped = <String, String>{};
          for (
            var index = 0;
            index < headers.length && index < row.length;
            index++
          ) {
            mapped[headers[index]] = row[index].toString().trim();
          }
          return mapped;
        })
        .toList(growable: false);
  }

  String _findFile(
    String directoryPath,
    List<String> fileNames,
    List<String> fragments,
  ) {
    final matchingName = fileNames.firstWhere(
      (name) {
        final normalized = name.toLowerCase();
        return fragments.every((fragment) => normalized.contains(fragment));
      },
      orElse: () => throw StateError(
        'Could not find required CSV file containing: ${fragments.join(', ')}',
      ),
    );

    return p.join(directoryPath, matchingName);
  }
}
