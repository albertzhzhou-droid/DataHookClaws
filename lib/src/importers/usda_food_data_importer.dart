import '../models/import_models.dart';
import '../models/raw_food_record.dart';
import 'food_importer.dart';
import 'usda_api_client.dart';

class UsdaFoodDataImporter implements FoodImporter {
  UsdaFoodDataImporter({UsdaApiClient? apiClient})
    : _apiClient = apiClient ?? UsdaApiClient();

  final UsdaApiClient _apiClient;

  @override
  String get id => 'usda';

  @override
  String get displayName => 'USDA FoodData Central';

  @override
  String get country => 'United States';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    final apiKey = request.apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('USDA importer requires a FoodData Central API key.');
    }

    final query = request.query.trim();
    if (query.isEmpty) {
      throw ArgumentError('USDA importer requires a search query.');
    }

    final foods = await _apiClient.searchFoods(
      apiKey: apiKey,
      query: query,
      limit: request.limit,
    );

    return foods.map(_mapFood).toList(growable: false);
  }

  RawFoodRecord _mapFood(Map<String, dynamic> row) {
    final fdcId = row['fdcId'];
    final publicationDate = DateTime.tryParse(
      (row['publicationDate'] ?? '').toString(),
    );
    final dataType = (row['dataType'] ?? 'USDA').toString();
    final nutrients =
        ((row['foodNutrients'] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>())
            .where((nutrient) => nutrient['value'] != null)
            .take(8)
            .map((nutrient) {
              return RawNutrientRecord(
                label: (nutrient['nutrientName'] ?? 'Unknown nutrient')
                    .toString(),
                amount: ((nutrient['value'] ?? 0) as num).toDouble(),
                unit: (nutrient['unitName'] ?? '').toString(),
              );
            })
            .toList(growable: false);

    final tags = <String>[dataType.toLowerCase(), 'official', 'usda'];

    return RawFoodRecord(
      sourceRecordId: '$fdcId',
      name: (row['description'] ?? 'Unnamed USDA food').toString(),
      category: (row['foodCategory'] ?? dataType).toString(),
      country: country,
      sourceName: displayName,
      description: [
        if ((row['foodCategory'] ?? '').toString().isNotEmpty)
          'Category: ${row['foodCategory']}',
        if ((row['scientificName'] ?? '').toString().isNotEmpty)
          'Scientific: ${row['scientificName']}',
        'Data type: $dataType',
      ].join(' • '),
      servingBasis: 'USDA record',
      tags: tags,
      nutrients: nutrients,
      lastUpdated: publicationDate ?? DateTime.now(),
    );
  }
}
