import 'package:data_hook_claws/src/data/importer_registry.dart';
import 'package:data_hook_claws/src/data/national_food_sources.dart';
import 'package:data_hook_claws/src/domain/fetch_budget_planner.dart';
import 'package:data_hook_claws/src/domain/source_capability_registry.dart';
import 'package:data_hook_claws/src/domain/source_routing_service.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = SourceCapabilityRegistry(
    importerDescriptors: importerDescriptors,
    entities: nationalFoodEntities,
  );
  final planner = FetchBudgetPlanner(
    sourceRoutingService: SourceRoutingService(registry: registry),
  );

  test('blocked and manual-only sources do not enter automatic routes', () {
    final plan = planner.plan(
      query: 'salmon',
      localHitCount: 0,
      sourceHints: const ['nz-foodfiles', 'ch-swiss-food-db', 'jp-standard'],
    );

    expect(plan.importerIds, ['jp-standard', 'usda']);
    expect(registry.byImporterId('nz-foodfiles')?.isBlocked, isTrue);
    expect(registry.byImporterId('ch-swiss-food-db')?.isManualOnly, isTrue);
  });

  test('skips fetch when local hits are enough', () {
    final plan = planner.plan(query: 'salmon', localHitCount: 10);

    expect(plan.shouldFetch, isFalse);
    expect(plan.importerIds, isEmpty);
  });

  test('recent failures are deprioritized after healthy sources', () {
    final plan = planner.plan(
      query: 'salmon',
      localHitCount: 0,
      sourceHints: const ['usda'],
      recentFailures: [
        FetchJobEntry(
          id: 'job-usda',
          query: 'salmon',
          phase: 'foreground',
          status: 'failure',
          importerId: 'usda',
          startedAt: DateTime(2026),
          finishedAt: DateTime(2026),
          message: 'boom',
        ),
      ],
    );

    expect(plan.importerIds, ['canada-cnf', 'uk-mccance']);
  });
}
