import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/foreground_fetch_runner.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/importers/food_importer.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:data_hook_claws/src/models/raw_food_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful source survives fetch-job persistence failure', () async {
    final repository = MemoryFoodRepository();
    final runner = ForegroundFetchRunner(
      syncUseCase: SyncFoodCatalogUseCase(
        repository: repository,
        normalizer: const FoodRecordNormalizer(),
        importers: [_FakeImporter(id: 'usda')],
      ),
    );
    final statuses = <String>[];

    final result = await runner.run(
      query: 'salmon',
      importerIds: const ['usda'],
      limitPerImporter: 20,
      persistJob: (entry) async {
        statuses.add(entry.status);
        throw StateError('fetch-job storage unavailable');
      },
    );

    expect(statuses, ['running', 'success']);
    expect(result.succeededSources, ['usda']);
    expect(result.importedFoods, hasLength(1));
    expect(await repository.searchFoods('salmon'), hasLength(1));
  });

  test(
    'source failure remains contained when status persistence fails',
    () async {
      final repository = MemoryFoodRepository();
      final runner = ForegroundFetchRunner(
        syncUseCase: SyncFoodCatalogUseCase(
          repository: repository,
          normalizer: const FoodRecordNormalizer(),
          importers: [_FailingImporter(id: 'usda')],
        ),
      );
      final statuses = <String>[];

      final result = await runner.run(
        query: 'salmon',
        importerIds: const ['usda'],
        limitPerImporter: 20,
        persistJob: (entry) async {
          statuses.add(entry.status);
          throw StateError('fetch-job storage unavailable');
        },
      );

      expect(statuses, ['running', 'failure']);
      expect(result.succeededSources, isEmpty);
      expect(result.importedFoods, isEmpty);
    },
  );
}

class _FakeImporter implements FoodImporter {
  _FakeImporter({required this.id});

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  String get country => 'Test';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) async {
    return [
      RawFoodRecord(
        sourceRecordId: '$id-${request.query}',
        name: '${request.query} $id',
        category: 'Test',
        country: 'Test',
        sourceName: id,
        description: 'Test description',
        servingBasis: 'Per 100 g',
        tags: const ['test'],
        nutrients: const [
          RawNutrientRecord(label: 'Protein', amount: 10, unit: 'g'),
        ],
        lastUpdated: DateTime(2026, 5, 23),
      ),
    ];
  }
}

class _FailingImporter implements FoodImporter {
  _FailingImporter({required this.id});

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  String get country => 'Test';

  @override
  Future<List<RawFoodRecord>> importFoods(ImportRequest request) {
    throw StateError('source unavailable');
  }
}
