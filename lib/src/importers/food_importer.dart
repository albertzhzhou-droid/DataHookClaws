import '../models/import_models.dart';
import '../models/raw_food_record.dart';

abstract class FoodImporter {
  String get id;

  String get displayName;

  String get country;

  Future<List<RawFoodRecord>> importFoods(ImportRequest request);
}
