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
}
