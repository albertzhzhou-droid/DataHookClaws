class FoodSummary {
  const FoodSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.sourceSummary,
    required this.description,
    required this.servingBasis,
    required this.lastUpdated,
  });

  final String id;
  final String name;
  final String category;
  final String country;
  final String sourceSummary;
  final String description;
  final String servingBasis;
  final DateTime lastUpdated;
}
