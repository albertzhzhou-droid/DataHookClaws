import 'package:data_hook_claws/src/api/food_api_dto.dart';
import 'package:data_hook_claws/src/api/food_catalog_api_service.dart';
import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/models/food_details.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/food_summary.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:data_hook_claws/src/search/food_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food summary dto serializes search summaries', () {
    final dto = FoodSummaryDto.fromSummary(
      FoodSummary(
        id: 'food-1',
        name: 'Rolled Oats',
        category: 'Grains',
        country: 'United States',
        sourceSummary: 'USDA',
        description: 'Whole grain oats',
        servingBasis: 'Per 100 g',
        lastUpdated: DateTime(2026, 4, 18),
      ),
    );

    final json = dto.toJson();
    expect(json['id'], 'food-1');
    expect(json['name'], 'Rolled Oats');
    expect(json['sourceSummary'], 'USDA');
  });

  test('food details dto keeps aggregated nutrients and observations', () {
    final dto = FoodDetailsDto.fromDetails(
      FoodDetails(
        id: 'food-1',
        displayName: 'Rolled Oats',
        category: 'Grains',
        countryHint: 'United States',
        description: 'Whole grain oats',
        servingBasis: 'Per 100 g',
        lastAggregatedAt: DateTime(2026, 4, 18),
        aliases: const ['Rolled Oats', 'Oats'],
        sourceRecords: [
          SourceRecordView(
            id: 'record-1',
            importerId: 'usda',
            sourceName: 'USDA',
            sourceRecordId: 'fdc-1',
            country: 'United States',
            recordTitle: 'Rolled Oats',
            recordDescription: 'USDA source record',
            fetchedAt: DateTime(2026, 4, 18),
            sourceUpdatedAt: DateTime(2026, 4, 18),
            mergeAudit: MergeAuditView(
              sourceRecordId: 'record-1',
              action: 'reuse',
              confidence: 0.98,
              matchedBy: 'name-category-serving-nutrient',
              reason: 'Exact alias/category/serving match.',
              itemAliasKey: 'rolled oats',
              itemCategoryKey: 'grains',
              itemServingKey: 'per 100 g',
              candidateEvaluations: const [
                MergeCandidateEvaluationView(
                  candidateCanonicalFoodId: 'canonical:oats:grains:per 100 g',
                  aliasMatched: true,
                  categoryMatched: true,
                  servingMatched: true,
                  nutrientSimilarity: 0.98,
                  accepted: true,
                  reason: 'Exact alias/category/serving match.',
                ),
              ],
              createdAt: DateTime(2026, 4, 18),
            ),
          ),
        ],
        aggregatedNutrients: const [
          Nutrient(label: 'Protein', amount: 13.2, unit: 'g'),
        ],
        nutrientObservations: const [
          NutrientObservationView(
            sourceRecordId: 'record-1',
            label: 'Protein',
            canonicalLabel: 'Protein',
            amount: 13.2,
            unit: 'g',
            originalUnit: 'g',
          ),
        ],
      ),
    );

    final json = dto.toJson();
    expect((json['aggregatedNutrients'] as List<Object?>).length, 1);
    expect((json['sources'] as List<Object?>).length, 1);
    expect(
      ((((json['sources'] as List<Object?>).single
              as Map<String, Object?>)['mergeAudit'])
          as Map<String, Object?>)['action'],
      'reuse',
    );
    expect(
      ((json['observationsBySource'] as Map<String, Object?>)['record-1']
              as List<Object?>)
          .length,
      1,
    );
  });

  test('food search index ranks relevant foods first', () {
    final index = FoodSearchIndex();
    final foods = [
      FoodItem(
        id: '1',
        name: 'Rolled Oats',
        category: 'Grains',
        country: 'United States',
        sourceName: 'USDA',
        description: 'Whole grain oats',
        servingBasis: 'Per 100 g',
        tags: const ['fiber', 'breakfast'],
        nutrients: const [Nutrient(label: 'Protein', amount: 13.2, unit: 'g')],
        lastUpdated: DateTime(2026, 4, 18),
      ),
      FoodItem(
        id: '2',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'Canada',
        sourceName: 'CNF',
        description: 'Rich in omega-3',
        servingBasis: 'Per 100 g',
        tags: const ['fish'],
        nutrients: const [Nutrient(label: 'Protein', amount: 20.4, unit: 'g')],
        lastUpdated: DateTime(2026, 4, 18),
      ),
    ];

    final results = index.search(items: foods, query: 'oats fiber');
    expect(results.first.food.name, 'Rolled Oats');
    expect(results.first.score, greaterThanOrEqualTo(1));
  });

  test('food search index normalizes punctuation-heavy queries', () {
    final index = FoodSearchIndex();
    final foods = [
      FoodItem(
        id: '1',
        name: 'Vitamin C Orange Juice',
        category: 'Beverages',
        country: 'United Kingdom',
        sourceName: 'CoFID',
        description: 'Citrus drink',
        servingBasis: 'Per 100 g',
        tags: const ['Vitamin-C', 'citrus'],
        nutrients: const [Nutrient(label: 'Vitamin C', amount: 25, unit: 'mg')],
        lastUpdated: DateTime(2026, 4, 18),
      ),
    ];

    final results = index.search(items: foods, query: ' vitamin-c ');
    expect(results.single.food.id, '1');
  });

  test(
    'api service returns summary dto list from indexed search results',
    () async {
      final repository = MemoryFoodRepository(
        seedItems: [
          FoodItem(
            id: '1',
            name: 'Atlantic Salmon',
            category: 'Seafood',
            country: 'Canada',
            sourceName: 'CNF',
            description: 'Rich in omega-3',
            servingBasis: 'Per 100 g',
            tags: const ['fish', 'omega-3'],
            nutrients: const [
              Nutrient(label: 'Protein', amount: 20.4, unit: 'g'),
            ],
            lastUpdated: DateTime(2026, 4, 18),
          ),
        ],
      );
      final service = FoodCatalogApiService(repository: repository);

      final results = await service.searchFoods(query: 'omega 3');

      expect(results.single.id, startsWith('canonical:'));
      expect(results.single.name, 'Atlantic Salmon');
      expect(results.single.sourceSummary, 'CNF');
    },
  );

  test('api service returns provenance detail dto', () async {
    final repository = MemoryFoodRepository(
      seedItems: [
        FoodItem(
          id: '1',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
          description: 'Rich in omega-3',
          servingBasis: 'Per 100 g',
          tags: const ['fish', 'omega-3'],
          nutrients: const [
            Nutrient(label: 'Protein', amount: 20.4, unit: 'g'),
          ],
          lastUpdated: DateTime(2026, 4, 18),
        ),
      ],
    );
    final service = FoodCatalogApiService(repository: repository);

    final summaries = await service.searchFoods(query: 'salmon');
    final details = await service.getFoodDetails(summaries.single.id);

    expect(details?.id, summaries.single.id);
    expect(details?.aggregatedNutrients.single.unit, 'g');
    expect(details?.sources.single.sourceName, 'CNF');
    expect(details?.sources.single.mergeAudit?.action, 'create');
    expect(
      details?.observationsBySource.values.first.single.canonicalLabel,
      'Protein',
    );
  });
}
