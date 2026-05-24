import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/canonical_merge_service.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses canonical for exact name category serving match', () {
    const service = CanonicalMergeService();
    final first = _food(
      id: 'canada-cnf:salmon-1',
      name: 'Atlantic Salmon',
      category: 'Seafood',
      country: 'Canada',
      sourceName: 'CNF',
      protein: 20.4,
    );
    final candidate = CanonicalMergeCandidate(
      canonicalFoodId: service.canonicalIdFor(first),
      categoryKey: service.categoryKey(first.category),
      servingKey: service.servingKey(first.servingBasis),
      aliasKeys: {service.aliasKey(first.name)},
      nutrients: first.nutrients,
    );

    final audit = service.decide(
      item: _food(
        id: 'uk-mccance:salmon-1',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'United Kingdom',
        sourceName: 'CoFID',
        protein: 20.0,
      ),
      candidates: [candidate],
    );

    expect(audit.decision.action, CanonicalMergeAction.reuse);
    expect(audit.decision.canonicalFoodId, candidate.canonicalFoodId);
    expect(audit.candidateEvaluations.single.accepted, isTrue);
  });

  test('does not merge when category conflicts', () {
    const service = CanonicalMergeService();
    final candidate = CanonicalMergeCandidate(
      canonicalFoodId: 'canonical:salmon:seafood:per 100 g',
      categoryKey: service.categoryKey('Seafood'),
      servingKey: service.servingKey('Per 100 g'),
      aliasKeys: {service.aliasKey('Atlantic Salmon')},
      nutrients: const [Nutrient(label: 'Protein', amount: 20.4, unit: 'g')],
    );

    final item = _food(
      id: 'uk-mccance:salmon-spread',
      name: 'Atlantic Salmon',
      category: 'Spreads',
      country: 'United Kingdom',
      sourceName: 'CoFID',
      protein: 8.2,
    );
    final audit = service.decide(item: item, candidates: [candidate]);

    expect(audit.decision.action, CanonicalMergeAction.create);
    expect(audit.decision.canonicalFoodId, service.canonicalIdFor(item));
    expect(audit.candidateEvaluations.single.accepted, isFalse);
    expect(
      audit.candidateEvaluations.single.reason,
      contains('Category mismatch'),
    );
  });

  test('create without candidates keeps explicit no-candidate reason', () {
    const service = CanonicalMergeService();
    final item = _food(
      id: 'jp-standard:tofu-1',
      name: 'Firm Tofu',
      category: 'Legumes',
      country: 'Japan',
      sourceName: 'MEXT',
      protein: 7.1,
    );

    final audit = service.decide(item: item, candidates: const []);

    expect(audit.decision.action, CanonicalMergeAction.create);
    expect(audit.candidateEvaluations, isEmpty);
    expect(audit.decision.reason, contains('No canonical candidates'));
  });

  test(
    'repository merges multi-source foods into one canonical snapshot',
    () async {
      final repository = MemoryFoodRepository();
      await repository.upsertFoods([
        _food(
          id: 'canada-cnf:salmon-1',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
          protein: 20.4,
          tags: const ['omega-3'],
          lastUpdated: DateTime(2026, 5, 23, 9),
        ),
        _food(
          id: 'uk-mccance:salmon-1',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'United Kingdom',
          sourceName: 'CoFID',
          protein: 21.0,
          tags: const ['oily fish'],
          lastUpdated: DateTime(2026, 5, 23, 10),
        ),
      ]);

      final results = await repository.searchFoods('salmon');
      final details = await repository.getFoodDetails(results.single.id);

      expect(results, hasLength(1));
      expect(results.single.country, 'Multi-source');
      expect(results.single.sourceName, 'Merged official sources');
      expect(details, isNotNull);
      expect(details!.sourceRecords, hasLength(2));
      expect(details.aliases, containsAll(['omega-3', 'oily fish']));
      expect(details.sourceRecords.first.mergeAudit, isNotNull);
      expect(
        details.sourceRecords
            .singleWhere((record) => record.sourceName == 'CoFID')
            .mergeAudit!
            .action,
        'reuse',
      );
      expect(
        details.aggregatedNutrients
            .singleWhere((nutrient) => nutrient.label == 'Protein')
            .amount,
        21.0,
      );
    },
  );

  test('alias search still resolves to canonical snapshot', () async {
    final repository = MemoryFoodRepository();
    await repository.upsertFoods([
      _food(
        id: 'canada-cnf:salmon-1',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'Canada',
        sourceName: 'CNF',
        protein: 20.4,
        tags: const ['omega-3'],
        lastUpdated: DateTime(2026, 5, 23, 9),
      ),
      _food(
        id: 'uk-mccance:salmon-1',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'United Kingdom',
        sourceName: 'CoFID',
        protein: 21.0,
        tags: const ['oily fish'],
        lastUpdated: DateTime(2026, 5, 23, 10),
      ),
    ]);

    final results = await repository.searchFoods('oily fish');

    expect(results, hasLength(1));
    expect(results.single.name, 'Atlantic Salmon');
  });
}

FoodItem _food({
  required String id,
  required String name,
  required String category,
  required String country,
  required String sourceName,
  double protein = 0,
  List<String> tags = const [],
  DateTime? lastUpdated,
}) {
  return FoodItem(
    id: id,
    name: name,
    category: category,
    country: country,
    sourceName: sourceName,
    description: '$sourceName record for $name',
    servingBasis: 'Per 100 g',
    tags: tags,
    nutrients: [Nutrient(label: 'Protein', amount: protein, unit: 'g')],
    lastUpdated: lastUpdated ?? DateTime(2026, 5, 23),
  );
}
