import 'package:data_hook_claws/src/api/food_api_dto.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/food_search_query.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'advanced search supports text country source category and nutrients',
    () async {
      final repository = MemoryFoodRepository();
      await repository.upsertFoods([
        _food(
          id: 'canada-cnf:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'Canadian Nutrient File',
          protein: 22,
        ),
        _food(
          id: 'usda:oats',
          name: 'Rolled Oats',
          category: 'Cereal',
          country: 'United States',
          sourceName: 'USDA',
          protein: 11,
        ),
      ]);

      final results = await repository.searchFoodsAdvanced(
        const FoodSearchQuery(
          text: 'salmon',
          countries: ['Canada'],
          importerIds: ['canada-cnf'],
          categories: ['Seafood'],
          nutrientRanges: [
            NutrientRangeFilter(canonicalLabel: 'Protein', unit: 'g', min: 20),
          ],
        ),
      );

      expect(results.single.name, 'Atlantic Salmon');
    },
  );

  test(
    'advanced search falls back to legacy nutrients when observations absent',
    () async {
      final repository = MemoryFoodRepository(
        seedItems: [
          _food(
            id: 'legacy:tofu',
            name: 'Firm Tofu',
            category: 'Legume',
            country: 'Japan',
            sourceName: 'Legacy',
            protein: 14,
          ),
        ],
      );

      final results = await repository.searchFoodsAdvanced(
        const FoodSearchQuery(
          nutrientRanges: [
            NutrientRangeFilter(canonicalLabel: 'Protein', unit: 'g', min: 10),
          ],
        ),
      );

      expect(results.single.name, 'Firm Tofu');
    },
  );

  test(
    'merge review issues include category conflict and nutrient variance',
    () async {
      final repository = MemoryFoodRepository();
      await repository.upsertFoods([
        _food(
          id: 'canada-cnf:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
          protein: 10,
        ),
        _food(
          id: 'uk-mccance:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'United Kingdom',
          sourceName: 'UK CoFID',
          protein: 100,
        ),
        _food(
          id: 'usda:salmon-oil',
          name: 'Atlantic Salmon',
          category: 'Oil',
          country: 'United States',
          sourceName: 'USDA',
          protein: 0,
        ),
      ]);

      final issues = await repository.getMergeReviewIssues();

      expect(
        issues.any(
          (issue) => issue.type == MergeReviewIssueType.lowConfidenceReuse,
        ),
        isTrue,
      );
      expect(
        issues.any(
          (issue) =>
              issue.type == MergeReviewIssueType.categoryConflictCandidate,
        ),
        isTrue,
      );
      expect(
        issues.any(
          (issue) =>
              issue.type == MergeReviewIssueType.multiSourceNutrientVariance,
        ),
        isTrue,
      );
    },
  );

  test('detail dto includes nutrient comparisons', () async {
    final repository = MemoryFoodRepository();
    await repository.upsertFoods([
      _food(
        id: 'canada-cnf:salmon',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'Canada',
        sourceName: 'CNF',
        protein: 20,
      ),
      _food(
        id: 'uk-mccance:salmon',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'United Kingdom',
        sourceName: 'UK CoFID',
        protein: 22,
      ),
    ]);

    final details = await repository.getFoodDetails(
      (await repository.searchFoods('salmon')).single.id,
    );
    final dto = FoodDetailsDto.fromDetails(details!);

    expect(dto.nutrientComparisons, isNotEmpty);
    expect(dto.nutrientComparisons.single.canonicalLabel, 'Protein');
    expect(dto.nutrientComparisons.single.observations.length, 2);
  });
}

FoodItem _food({
  required String id,
  required String name,
  required String category,
  required String country,
  required String sourceName,
  required double protein,
}) {
  return FoodItem(
    id: id,
    name: name,
    category: category,
    country: country,
    sourceName: sourceName,
    description: '$name official source record',
    servingBasis: 'Per 100 g',
    tags: const ['official', 'omega-3'],
    nutrients: [Nutrient(label: 'Protein', amount: protein, unit: 'g')],
    lastUpdated: DateTime(2026, 5, 24),
  );
}
