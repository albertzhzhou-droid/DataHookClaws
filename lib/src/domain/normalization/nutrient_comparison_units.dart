/// A canonical unit used to compare nutrient observations.
///
/// [scaleToCanonical] converts a value in the source unit to [displayUnit].
/// Denominators are retained so values expressed per serving are not compared
/// with values expressed per 100 g (or with values that have no denominator).
class NutrientComparisonUnit {
  const NutrientComparisonUnit({
    required this.dimension,
    required this.canonicalUnit,
    required this.scaleToCanonical,
    this.denominator,
  });

  final NutrientComparisonUnitDimension dimension;
  final String canonicalUnit;
  final double scaleToCanonical;
  final String? denominator;

  String get displayUnit {
    final normalizedDenominator = denominator;
    if (normalizedDenominator == null || normalizedDenominator.isEmpty) {
      return canonicalUnit;
    }
    return '$canonicalUnit/$normalizedDenominator';
  }

  double normalizeAmount(double amount) => amount * scaleToCanonical;

  bool isComparableWith(NutrientComparisonUnit other) {
    return dimension == other.dimension && displayUnit == other.displayUnit;
  }
}

enum NutrientComparisonUnitDimension { mass, volume, energy, percentage, other }

const double nutrientComparisonAmountTolerance = 0.000001;

bool areNutrientComparisonAmountsEquivalent(double left, double right) {
  return (left - right).abs() <= nutrientComparisonAmountTolerance;
}

bool hasNutrientComparisonAmountVariance(Iterable<double> amounts) {
  final iterator = amounts.iterator;
  if (!iterator.moveNext()) {
    return false;
  }
  final reference = iterator.current;
  while (iterator.moveNext()) {
    if (!areNutrientComparisonAmountsEquivalent(reference, iterator.current)) {
      return true;
    }
  }
  return false;
}

String nutrientComparisonIncomparableUnitLabel(String rawUnit) {
  final trimmed = rawUnit.trim();
  return trimmed.isEmpty ? '(empty unit)' : trimmed;
}

/// Converts a source nutrient unit into a comparison-safe canonical unit.
///
/// Returns `null` for empty or unsupported units. Unit names are matched
/// case-insensitively, while denominator signatures remain part of
/// [NutrientComparisonUnit.displayUnit].
NutrientComparisonUnit? normalizeNutrientComparisonUnit(String rawUnit) {
  final normalized = rawUnit.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  final separatorIndex = normalized.indexOf('/');
  final numerator = separatorIndex < 0
      ? normalized
      : normalized.substring(0, separatorIndex);
  final denominator = separatorIndex < 0
      ? null
      : _normalizeDenominator(normalized.substring(separatorIndex + 1));
  final canonicalToken = numerator
      .trim()
      .replaceAll(RegExp(r'[\(\),;:]'), '')
      .trim()
      .split(RegExp(r'\s+'))
      .first;

  if (canonicalToken.isEmpty) {
    return null;
  }

  NutrientComparisonUnit build({
    required NutrientComparisonUnitDimension dimension,
    required String canonicalUnit,
    required double scaleToCanonical,
  }) {
    return NutrientComparisonUnit(
      dimension: dimension,
      canonicalUnit: canonicalUnit,
      scaleToCanonical: scaleToCanonical,
      denominator: denominator == null || denominator.isEmpty
          ? null
          : denominator,
    );
  }

  switch (canonicalToken) {
    case 'g':
    case 'gr':
    case 'gram':
    case 'gramme':
    case 'grams':
      return build(
        dimension: NutrientComparisonUnitDimension.mass,
        canonicalUnit: 'g',
        scaleToCanonical: 1,
      );
    case 'kg':
    case 'kilogram':
    case 'kilograms':
      return build(
        dimension: NutrientComparisonUnitDimension.mass,
        canonicalUnit: 'g',
        scaleToCanonical: 1000,
      );
    case 'mg':
    case 'milligram':
    case 'milligrams':
      return build(
        dimension: NutrientComparisonUnitDimension.mass,
        canonicalUnit: 'g',
        scaleToCanonical: 0.001,
      );
    case 'ug':
    case 'µg':
    case 'μg':
    case 'mcg':
    case 'microgram':
    case 'micrograms':
      return build(
        dimension: NutrientComparisonUnitDimension.mass,
        canonicalUnit: 'g',
        scaleToCanonical: 0.000001,
      );
    case 'ml':
    case 'milliliter':
    case 'millilitre':
    case 'milliliters':
    case 'millilitres':
      return build(
        dimension: NutrientComparisonUnitDimension.volume,
        canonicalUnit: 'ml',
        scaleToCanonical: 1,
      );
    case 'l':
    case 'liter':
    case 'litre':
    case 'liters':
    case 'litres':
      return build(
        dimension: NutrientComparisonUnitDimension.volume,
        canonicalUnit: 'ml',
        scaleToCanonical: 1000,
      );
    case 'kcal':
    case 'calorie':
    case 'calories':
    case 'kcalorie':
    case 'kilocalorie':
    case 'kilocalories':
    case 'kilocal':
    case 'kcalories':
      return build(
        dimension: NutrientComparisonUnitDimension.energy,
        canonicalUnit: 'kcal',
        scaleToCanonical: 1,
      );
    case 'cal':
      return build(
        dimension: NutrientComparisonUnitDimension.energy,
        canonicalUnit: 'kcal',
        scaleToCanonical: 0.001,
      );
    case 'kj':
    case 'kjoule':
    case 'kjoules':
    case 'kilojoule':
    case 'kilojoules':
      return build(
        dimension: NutrientComparisonUnitDimension.energy,
        canonicalUnit: 'kcal',
        scaleToCanonical: 0.2390057361,
      );
    case 'j':
    case 'joule':
    case 'joules':
      return build(
        dimension: NutrientComparisonUnitDimension.energy,
        canonicalUnit: 'kcal',
        scaleToCanonical: 0.0002390057361,
      );
    case '%':
    case 'percent':
    case 'pct':
      return build(
        dimension: NutrientComparisonUnitDimension.percentage,
        canonicalUnit: '%',
        scaleToCanonical: 1,
      );
    case 'iu':
    case 'ius':
    case 'internationalunit':
    case 'internationalunits':
      return build(
        dimension: NutrientComparisonUnitDimension.other,
        canonicalUnit: 'IU',
        scaleToCanonical: 1,
      );
    default:
      return null;
  }
}

String _normalizeDenominator(String denominator) {
  return denominator
      .trim()
      .replaceAll(RegExp(r'[\(\),;:]'), '')
      .replaceAll(RegExp(r'\s+'), '');
}
