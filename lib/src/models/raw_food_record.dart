class RawFoodRecord {
  const RawFoodRecord({
    required this.sourceRecordId,
    required this.name,
    required this.category,
    required this.country,
    required this.sourceName,
    required this.description,
    required this.servingBasis,
    required this.tags,
    required this.nutrients,
    required this.lastUpdated,
  });

  final String sourceRecordId;
  final String name;
  final String category;
  final String country;
  final String sourceName;
  final String description;
  final String servingBasis;
  final List<String> tags;
  final List<RawNutrientRecord> nutrients;
  final DateTime lastUpdated;
}

class RawNutrientRecord {
  const RawNutrientRecord({
    required this.label,
    required this.amount,
    required this.unit,
  });

  final String label;
  final double amount;
  final String unit;
}
