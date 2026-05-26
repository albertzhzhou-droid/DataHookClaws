import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('national source catalog is grouped by administrative entity', () {
    expect(nationalFoodEntities.length, greaterThanOrEqualTo(10));
    expect(nationalFoodEntities.any((entity) => entity.code == 'US'), isTrue);
    expect(nationalFoodEntities.any((entity) => entity.code == 'JP'), isTrue);
    expect(
      nationalFoodEntities.any(
        (entity) => entity.sources.any((source) => source.id == 'fr-ciqual'),
      ),
      isTrue,
    );
  });

  test('flattened source list retains integrated and blocked sources', () {
    expect(
      nationalFoodSources.any((source) => source.status == 'Integrated'),
      isTrue,
    );
    expect(
      nationalFoodSources.any((source) => source.status == 'Blocked'),
      isTrue,
    );
    expect(
      nationalFoodSources.any(
        (source) => source.id == 'ch-swiss-food-db' && source.isIntegrated,
      ),
      isTrue,
    );
    expect(
      nationalFoodSources.any(
        (source) => source.id == 'au-afcd' && source.isIntegrated,
      ),
      isTrue,
    );
    expect(
      nationalFoodSources.any(
        (source) => source.id == 'fr-ciqual' && source.isIntegrated,
      ),
      isTrue,
    );
    expect(
      nationalFoodSources.any(
        (source) => source.id == 'dk-frida' && source.isIntegrated,
      ),
      isTrue,
    );
  });
}
