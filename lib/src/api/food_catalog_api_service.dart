import '../data/food_repository.dart';
import 'food_api_dto.dart';

class FoodCatalogApiService {
  FoodCatalogApiService({required FoodRepository repository})
    : _repository = repository;

  final FoodRepository _repository;

  Future<List<FoodSummaryDto>> searchFoods({
    required String query,
    int limit = 20,
  }) async {
    final summaries = await _repository.searchFoodSummaries(
      query,
      limit: limit,
    );
    return summaries.map(FoodSummaryDto.fromSummary).toList(growable: false);
  }

  Future<FoodDetailsDto?> getFoodDetails(String id) async {
    final details = await _repository.getFoodDetails(id);
    if (details == null) {
      return null;
    }
    return FoodDetailsDto.fromDetails(details);
  }
}
