import 'nutrient.dart';

class FoodItem {
  const FoodItem({
    required this.id,
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

  final String id;
  final String name;
  final String category;
  final String country;
  final String sourceName;
  final String description;
  final String servingBasis;
  final List<String> tags;
  final List<Nutrient> nutrients;
  final DateTime lastUpdated;
}
