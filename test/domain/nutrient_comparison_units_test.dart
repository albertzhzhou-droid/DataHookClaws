import 'package:data_hook_claws/src/domain/normalization/nutrient_comparison_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeNutrientComparisonUnit', () {
    test('normalizes milligrams and grams to the same value', () {
      final milligrams = normalizeNutrientComparisonUnit('mg');
      final grams = normalizeNutrientComparisonUnit('g');

      expect(milligrams, isNotNull);
      expect(grams, isNotNull);
      expect(milligrams!.displayUnit, 'g');
      expect(grams!.displayUnit, 'g');
      expect(milligrams.isComparableWith(grams), isTrue);
      expect(milligrams.normalizeAmount(1500), closeTo(1.5, 1e-6));
      expect(grams.normalizeAmount(1.5), closeTo(1.5, 1e-6));
    });

    test('normalizes calories and kilocalories to the same value', () {
      final calories = normalizeNutrientComparisonUnit('cal');
      final kilocalories = normalizeNutrientComparisonUnit('kcal');

      expect(calories, isNotNull);
      expect(kilocalories, isNotNull);
      expect(calories!.isComparableWith(kilocalories!), isTrue);
      expect(calories.normalizeAmount(1000000), closeTo(1000, 1e-6));
      expect(kilocalories.normalizeAmount(1000), closeTo(1000, 1e-6));
    });

    test('normalizes kcal variants to kcal', () {
      final kilocalorieWord = normalizeNutrientComparisonUnit('kilocalorie');
      final kcalories = normalizeNutrientComparisonUnit('kcalories');

      expect(kilocalorieWord, isNotNull);
      expect(kcalories, isNotNull);
      expect(kilocalorieWord!.isComparableWith(kcalories!), isTrue);
      expect(kilocalorieWord.normalizeAmount(1), closeTo(1, 1e-6));
    });

    test('normalizes kJ and kcal to the same value', () {
      final kilojoules = normalizeNutrientComparisonUnit('kJ');
      final kilocalories = normalizeNutrientComparisonUnit('kcal');

      expect(kilojoules, isNotNull);
      expect(kilocalories, isNotNull);
      expect(kilojoules!.isComparableWith(kilocalories!), isTrue);
      expect(kilojoules.normalizeAmount(4184), closeTo(1000, 1e-6));
      expect(kilocalories.normalizeAmount(1000), closeTo(1000, 1e-6));
    });

    test('normalizes joules to kcal with loose energy scale tolerance', () {
      final joules = normalizeNutrientComparisonUnit('J');
      final kilocalories = normalizeNutrientComparisonUnit('kcal');

      expect(joules, isNotNull);
      expect(kilocalories, isNotNull);
      expect(joules!.isComparableWith(kilocalories!), isTrue);
      expect(joules.normalizeAmount(4184), closeTo(1, 1e-6));
    });

    test('normalizes kJoule using the kilojoule scale', () {
      final kilojoules = normalizeNutrientComparisonUnit('kJoule');
      final kilocalories = normalizeNutrientComparisonUnit('kcal');

      expect(kilojoules, isNotNull);
      expect(kilocalories, isNotNull);
      expect(kilojoules!.isComparableWith(kilocalories!), isTrue);
      expect(kilojoules.normalizeAmount(4184), closeTo(1000, 1e-6));
    });

    test('normalizes percentage units', () {
      final percentSign = normalizeNutrientComparisonUnit('%');
      final percentWord = normalizeNutrientComparisonUnit('percent');

      expect(percentSign, isNotNull);
      expect(percentWord, isNotNull);
      expect(percentSign!.isComparableWith(percentWord!), isTrue);
      expect(percentSign.normalizeAmount(100), closeTo(100, 1e-6));
      expect(percentWord.normalizeAmount(50), closeTo(50, 1e-6));
    });

    test('keeps denominator signatures in display units', () {
      final perHundredGrams = normalizeNutrientComparisonUnit('g/100g');
      final grams = normalizeNutrientComparisonUnit('g');

      expect(perHundredGrams, isNotNull);
      expect(grams, isNotNull);
      expect(perHundredGrams!.displayUnit, 'g/100g');
      expect(grams!.displayUnit, 'g');
      expect(perHundredGrams.isComparableWith(grams), isFalse);
    });

    test('normalizes noisy denominator formatting', () {
      final perHundredGrams = normalizeNutrientComparisonUnit('g /( 100 g )');
      expect(perHundredGrams, isNotNull);
      expect(perHundredGrams!.displayUnit, 'g/100g');
    });

    test('returns null for unknown units', () {
      expect(normalizeNutrientComparisonUnit('mystery-unit'), isNull);
      expect(normalizeNutrientComparisonUnit(''), isNull);
    });

    test('uses one tolerance for row variance and extrema equivalence', () {
      const convertedKilojoules = 0.9999999998424;
      expect(
        areNutrientComparisonAmountsEquivalent(convertedKilojoules, 1),
        isTrue,
      );
      expect(
        hasNutrientComparisonAmountVariance([convertedKilojoules, 1]),
        isFalse,
      );
      expect(
        hasNutrientComparisonAmountVariance([convertedKilojoules, 1.00001]),
        isTrue,
      );
    });

    test('labels empty and unsupported units as non-comparable', () {
      expect(nutrientComparisonIncomparableUnitLabel(''), '(empty unit)');
      expect(
        nutrientComparisonIncomparableUnitLabel(' mystery-unit '),
        'mystery-unit',
      );
    });
  });
}
