# Slice175 — Source route identity deduplication

- Date: 2026-09-02
- Scope: duplicate importer identity handling in capability-aware and legacy
  source routing.
- Canonical edits:
  - `lib/src/domain/source_routing_service.dart`
    - De-duplicated eligible defaults and source hints while preserving their
      first-seen ordering and existing failure/blocked filtering.
  - `lib/src/domain/fetch_budget_planner.dart`
    - De-duplicated legacy hinted and prioritized importer order before applying
      the route budget.
  - `test/domain/fetch_budget_planner_test.dart` and
    `test/domain/source_routing_service_test.dart`
    - Added duplicate-default and duplicate-hint regressions.
- Behavior contract:
  - A malformed repeated importer ID can be scheduled at most once per route.
  - First-seen priority, healthy-before-failed ordering, route limits, and
    explicit budget/disable behavior remain unchanged.
- Validation evidence:
  - Focused planner/routing tests: 13 cases passed.
  - Full `flutter test`: 427 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the route de-duplication, focused regressions,
  docs references, and this timeline; keep numeric budget guards and existing
  source-routing semantics.
