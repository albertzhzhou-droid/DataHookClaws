import 'package:data_hook_claws/src/domain/normalization/category_mapper.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/normalization/tag_normalizer.dart';
import 'package:data_hook_claws/src/domain/normalization/text_normalizer.dart';
import 'package:data_hook_claws/src/domain/normalization/unit_converter.dart';
import 'package:data_hook_claws/src/models/raw_food_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalization toolkit', () {
    test('text normalizer creates stable alias keys', () {
      const normalizer = TextNormalizer();

      expect(normalizer.aliasKey('Vitamin B12'), 'vitamin b12');
      expect(normalizer.aliasKey(' Vitamin-C '), 'vitaminc');
      expect(normalizer.aliasKey('Salt equivalent'), 'salt equivalent');
      expect(normalizer.aliasKey('Omega-3 (EPA + DHA)'), 'omega3 epa  dha');
    });

    test('unit converter normalizes and converts units', () {
      const textNormalizer = TextNormalizer();
      const unitConverter = UnitConverter();

      expect(unitConverter.normalizeUnit('ug', textNormalizer), 'μg');
      expect(unitConverter.normalizeUnit('kJ', textNormalizer), 'kJ');
      expect(
        unitConverter.convert(amount: 1, fromUnit: 'mg', toUnit: 'μg'),
        1000,
      );
      expect(
        unitConverter.convert(amount: 2500, fromUnit: 'mg', toUnit: 'g'),
        2.5,
      );
      expect(
        unitConverter.convert(amount: 2.5, fromUnit: 'g', toUnit: 'mg'),
        2500,
      );
    });

    test('tag normalizer trims, lowers, and deduplicates tags', () {
      const tagNormalizer = TagNormalizer();

      expect(tagNormalizer.normalize([' Protein ', 'protein', 'Omega-3', '']), [
        'protein',
        'omega-3',
      ]);
      expect(tagNormalizer.normalize(['  Ready To Eat  ', 'ready to eat']), [
        'ready to eat',
      ]);
    });

    test('category mapper resolves known aliases', () {
      const categoryMapper = CategoryMapper();

      expect(categoryMapper.map('DG'), 'Vegetables and legumes');
      expect(categoryMapper.map('custom category'), 'custom category');
    });

    test(
      'food record normalizer maps raw records into canonical food items',
      () {
        const normalizer = FoodRecordNormalizer();
        final food = normalizer.normalizeRecord(
          importerId: 'test',
          record: RawFoodRecord(
            sourceRecordId: '001',
            name: ' Sample Food ',
            category: 'DG',
            country: ' Canada ',
            sourceName: 'Example Source',
            description: ' Demo record ',
            servingBasis: ' Per 100 g ',
            tags: const [' Protein ', 'protein', 'Omega-3'],
            nutrients: const [
              RawNutrientRecord(label: 'Vitamin C', amount: 25, unit: 'mg'),
              RawNutrientRecord(label: 'Protein', amount: 12, unit: 'g'),
            ],
            lastUpdated: DateTime(2026, 4, 18),
          ),
        );

        expect(food.id, 'test:001');
        expect(food.name, 'Sample Food');
        expect(food.category, 'Vegetables and legumes');
        expect(food.country, 'Canada');
        expect(food.tags, ['protein', 'omega-3']);
        expect(food.nutrients.any((n) => n.label == 'Vitamin C'), isTrue);
        expect(food.nutrients.any((n) => n.label == 'Protein'), isTrue);
      },
    );
  });
}
