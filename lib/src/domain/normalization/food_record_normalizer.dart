import 'category_mapper.dart';
import 'nutrient_dictionary.dart';
import 'tag_normalizer.dart';
import 'text_normalizer.dart';
import 'unit_converter.dart';
import '../../models/food_item.dart';
import '../../models/nutrient.dart';
import '../../models/raw_food_record.dart';

class FoodRecordNormalizer {
  const FoodRecordNormalizer({
    this.categoryMapper = const CategoryMapper(),
    this.nutrientDictionary = const NutrientDictionary(),
    this.tagNormalizer = const TagNormalizer(),
    this.textNormalizer = const TextNormalizer(),
    this.unitConverter = const UnitConverter(),
  });

  final CategoryMapper categoryMapper;
  final NutrientDictionary nutrientDictionary;
  final TagNormalizer tagNormalizer;
  final TextNormalizer textNormalizer;
  final UnitConverter unitConverter;

  // Importers should stay close to source files. This layer is where we
  // collapse country-specific naming into the app's internal schema.
  List<FoodItem> normalizeBatch({
    required String importerId,
    required List<RawFoodRecord> records,
  }) {
    return records
        .map(
          (record) => normalizeRecord(importerId: importerId, record: record),
        )
        .toList(growable: false);
  }

  FoodItem normalizeRecord({
    required String importerId,
    required RawFoodRecord record,
  }) {
    final nutrientsByLabel = <String, Nutrient>{};
    for (final rawNutrient in record.nutrients) {
      final normalized = _normalizeNutrient(rawNutrient);
      if (normalized == null) {
        continue;
      }
      nutrientsByLabel[normalized.label] = normalized;
    }

    return FoodItem(
      id: '$importerId:${record.sourceRecordId}',
      name: textNormalizer.cleanText(record.name),
      category: _normalizeCategory(record.category),
      country: textNormalizer.cleanText(record.country),
      sourceName: textNormalizer.cleanText(record.sourceName),
      description: textNormalizer.cleanText(record.description),
      servingBasis: textNormalizer.cleanText(record.servingBasis),
      tags: tagNormalizer.normalize(record.tags),
      nutrients: nutrientsByLabel.values.toList(growable: false),
      lastUpdated: record.lastUpdated,
    );
  }

  Nutrient? _normalizeNutrient(RawNutrientRecord rawNutrient) {
    final aliasKey = textNormalizer.aliasKey(rawNutrient.label);
    final canonical = nutrientDictionary.lookup(aliasKey);
    final resolvedLabel =
        canonical?.label ?? textNormalizer.cleanText(rawNutrient.label);
    final normalizedSourceUnit = unitConverter.normalizeUnit(
      rawNutrient.unit,
      textNormalizer,
    );
    final resolvedUnit = canonical?.unit ?? normalizedSourceUnit;
    final convertedAmount = unitConverter.convert(
      amount: rawNutrient.amount,
      fromUnit: normalizedSourceUnit,
      toUnit: resolvedUnit,
    );

    if (convertedAmount == null) {
      return null;
    }

    return Nutrient(
      label: resolvedLabel,
      amount: convertedAmount,
      unit: resolvedUnit,
    );
  }

  String _normalizeCategory(String rawCategory) {
    final cleaned = textNormalizer.cleanText(rawCategory);
    return categoryMapper.map(cleaned);
  }
}
