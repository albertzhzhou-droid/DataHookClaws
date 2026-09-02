# Slice174 — Fetch budget input bounds

- Date: 2026-09-02
- Scope: planner and source-routing numeric input contracts.
- Canonical edits:
  - `lib/src/domain/fetch_budget_planner.dart`
    - Sanitized negative importer budgets and thresholds plus non-positive
      per-importer limits in the const constructor.
    - Preserved `maxImporters: 0` as an explicit disable switch and returned
      the sanitized limit from skipped plans.
    - Clamped any defensive legacy-route count before `take`.
  - `lib/src/domain/source_routing_service.dart`
    - Clamped a directly supplied negative `maxImporters` to an empty route.
  - `test/domain/fetch_budget_planner_test.dart` and
    `test/domain/source_routing_service_test.dart`
    - Added invalid-budget, explicit-disable, skipped-plan, and negative-route
      regressions.
- Behavior contract:
  - Invalid numeric inputs cannot produce negative `Iterable.take` counts or
    negative `ImportRequest.limit` values.
  - Valid ordering, recent-failure prioritization, and zero-importer disable
    behavior remain unchanged.
- Validation evidence:
  - Focused planner/routing tests: 11 cases passed.
  - Full `flutter test`: 425 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the numeric guards, focused regressions, docs
  references, and this timeline; keep existing route ordering and importer
  semantics.
