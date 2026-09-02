import 'package:data_hook_claws/src/domain/fetch_budget_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = FetchBudgetPlanner();

  test('skips fetch for empty query', () {
    final plan = planner.plan(query: '', localHitCount: 0);
    expect(plan.shouldFetch, isFalse);
    expect(plan.importerIds, isEmpty);
  });

  test('skips fetch when local hits are enough', () {
    final plan = planner.plan(query: 'salmon', localHitCount: 10);
    expect(plan.shouldFetch, isFalse);
  });

  test('returns prioritized importers when local results are low', () {
    final plan = planner.plan(query: 'salmon', localHitCount: 0);
    expect(plan.shouldFetch, isTrue);
    expect(plan.importerIds, ['usda', 'canada-cnf']);
    expect(plan.limitPerImporter, 20);
  });

  test('promotes source hints while respecting budget', () {
    final plan = planner.plan(
      query: 'tofu',
      localHitCount: 1,
      sourceHints: const ['jp-standard'],
    );
    expect(plan.importerIds, ['jp-standard', 'usda']);
  });

  test('sanitizes invalid budgets without generating negative requests', () {
    const unsafePlanner = FetchBudgetPlanner(
      maxImporters: -1,
      limitPerImporter: 0,
      localHitThreshold: -3,
    );

    final plan = unsafePlanner.plan(query: 'salmon', localHitCount: 0);

    expect(unsafePlanner.maxImporters, 2);
    expect(unsafePlanner.limitPerImporter, 20);
    expect(unsafePlanner.localHitThreshold, 10);
    expect(plan.importerIds, ['usda', 'canada-cnf']);
    expect(plan.limitPerImporter, 20);
  });

  test('preserves an explicit zero-importer disable switch', () {
    const disabledPlanner = FetchBudgetPlanner(maxImporters: 0);

    final plan = disabledPlanner.plan(query: 'salmon', localHitCount: 0);

    expect(disabledPlanner.maxImporters, 0);
    expect(plan.shouldFetch, isFalse);
    expect(plan.importerIds, isEmpty);
  });

  test('uses the sanitized request limit even when fetch is skipped', () {
    const plannerWithCustomLimit = FetchBudgetPlanner(limitPerImporter: 7);

    final plan = plannerWithCustomLimit.plan(query: '', localHitCount: 0);

    expect(plan.limitPerImporter, 7);
  });

  test('deduplicates malformed prioritized importers in legacy routing', () {
    const plannerWithDuplicates = FetchBudgetPlanner(
      prioritizedImporters: ['usda', 'usda', 'canada-cnf'],
      maxImporters: 3,
    );

    final plan = plannerWithDuplicates.plan(query: 'salmon', localHitCount: 0);

    expect(plan.importerIds, ['usda', 'canada-cnf']);
  });
}
