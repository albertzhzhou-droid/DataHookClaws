# Slice164 — Dataset-artifact persistence isolation

- Version: 2026-09-02 / Slice164
- Scope: production hardening of the supplemental dataset-artifact inventory
  write performed after a normalized food import.
- Changes:
  - Wrapped `SyncFoodCatalogUseCase` dataset-artifact metadata persistence in
    a best-effort boundary so a storage outage cannot mask a normalized import
    that has already been committed.
  - Preserved the existing ingestion, normalization, success/failure import-log
    and artifact-schema semantics; only the supplemental metadata write is
    isolated.
  - Added a focused importer regression with a failing artifact repository; it
    verifies the normalized food remains searchable and the import outcome
    remains successful after the artifact write fails.
- Verification:
  - Focused `it_crea`/source-importer tests: 18 cases passed.
  - Full Flutter tests: `+409` passed.
  - `flutter analyze`: zero issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed with lockfile, 14 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the best-effort artifact metadata boundary, its focused
  regression, this timeline entry, and the matching AGENT/plan/queue bullets;
  preserve normalized ingestion, import-log boundaries, artifact schema, and
  importer routing.
- Next: inspect one bounded persistence or release-evidence contract without
  duplicating canonical content.
