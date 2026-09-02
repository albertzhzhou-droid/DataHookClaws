# Slice181 — Export scope filename containment

- Date: 2026-09-02
- Scope: prevent public export scope labels from escaping the configured
  directory through filename construction.
- Canonical edits:
  - `lib/src/api/food_catalog_export_service.dart`
    - Slugify `scopeType` before joining the export filename with the export
      directory; preserve the original scope value in payload and history.
  - `test/domain/export_service_test.dart`
    - Add a traversal-shaped scope-type regression asserting the artifact
      remains inside the configured directory.
- Behavior contract:
  - Path separators and traversal fragments in `scopeType` cannot alter the
    export directory.
  - Existing valid scope names keep their filename shape.
  - Scope payload/history values, directory resolution, formats, and record
    semantics remain unchanged.
- Validation evidence:
  - Focused export-service tests: 12 cases passed.
  - Full `flutter test`: 434 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only the filename slug guard, focused regression,
  docs references, and this timeline; keep existing export behavior.
