class FoodSearchQuery {
  const FoodSearchQuery({
    this.text = '',
    this.countries = const [],
    this.importerIds = const [],
    this.categories = const [],
    this.nutrientRanges = const [],
  });

  final String text;
  final List<String> countries;
  final List<String> importerIds;
  final List<String> categories;
  final List<NutrientRangeFilter> nutrientRanges;

  bool get hasAdvancedFilters =>
      countries.isNotEmpty ||
      importerIds.isNotEmpty ||
      categories.isNotEmpty ||
      nutrientRanges.isNotEmpty;
}

class NutrientRangeFilter {
  const NutrientRangeFilter({
    required this.canonicalLabel,
    required this.unit,
    this.min,
    this.max,
  });

  final String canonicalLabel;
  final String unit;
  final double? min;
  final double? max;
}

class NutrientPreset {
  const NutrientPreset({
    required this.id,
    required this.label,
    required this.canonicalLabel,
    required this.unit,
  });

  final String id;
  final String label;
  final String canonicalLabel;
  final String unit;
}

const nutrientSearchPresets = <NutrientPreset>[
  NutrientPreset(
    id: 'protein',
    label: 'Protein',
    canonicalLabel: 'Protein',
    unit: 'g',
  ),
  NutrientPreset(
    id: 'sodium',
    label: 'Sodium',
    canonicalLabel: 'Sodium',
    unit: 'mg',
  ),
  NutrientPreset(
    id: 'energy',
    label: 'Energy',
    canonicalLabel: 'Energy',
    unit: 'kcal',
  ),
  NutrientPreset(id: 'fat', label: 'Fat', canonicalLabel: 'Fat', unit: 'g'),
  NutrientPreset(
    id: 'carbs',
    label: 'Carbohydrate',
    canonicalLabel: 'Carbohydrate',
    unit: 'g',
  ),
  NutrientPreset(
    id: 'fiber',
    label: 'Fiber',
    canonicalLabel: 'Fiber',
    unit: 'g',
  ),
];
