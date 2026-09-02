# Slice180 — Export food-id limit boundary

- Date: 2026-09-02
- Scope: make the public food-id export limit safe for malformed callers.
- Canonical edits:
  - `lib/src/api/food_catalog_export_service.dart`
    - Normalize negative `exportFoodIds` limits to `0` before identifier
      selection, preserving trim/deduplication and positive-limit behavior.
  - `test/domain/export_service_test.dart`
    - Add a regression for a negative limit that asserts a zero-record empty
      JSON artifact and retained export-history write.
- Behavior contract:
  - Negative limits produce an empty artifact and do not attempt detail reads.
  - Zero remains an explicit empty export request.
  - Positive limits, identifier ordering/deduplication, formats, and history
    semantics remain unchanged.
- Validation evidence:
  - Focused export-service tests: 11 cases passed.
  - Full `flutter test`: 433 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the local limit guard, focused regression,
  docs references, and this timeline; keep existing export formats and valid
  limit behavior.
