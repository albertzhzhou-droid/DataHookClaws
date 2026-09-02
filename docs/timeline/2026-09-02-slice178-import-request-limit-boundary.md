# Slice178 — Import request limit boundary

- Date: 2026-09-02
- Scope: make importer request limits safe at the value-object boundary.
- Canonical edits:
  - `lib/src/models/import_models.dart`
    - Normalize negative `ImportRequest.limit` values to `0` in the const
      constructor, so direct and `copyWith` requests share one contract.
  - `test/domain/official_dataset_grabber_test.dart`
    - Added direct and copied negative-limit regression coverage.
- Behavior contract:
  - A negative limit cannot reach importer `.take()` or count-based early-exit
    code paths.
  - `0` remains an explicit empty-request limit rather than a defaulted fetch.
  - Positive limits and official dataset request preparation remain unchanged.
- Validation evidence:
  - Focused official-dataset tests: 6 cases passed.
  - Full `flutter test`: 430 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the constructor guard, focused regression,
  docs references, and this timeline; keep valid and explicit zero-limit
  behavior.
