# Slice161 — Import log persistence isolation

- Date: 2026-09-02
- Scope: Sync import result and import-log persistence boundary.
- Change: `SyncFoodCatalogUseCase` now treats success and failure import logs as
  supplemental diagnostics. A successful import returns normalized foods even
  when its success log write fails; a primary import error is rethrown even
  when failure-log persistence also fails.
- Tests: the existing source-importer suite passed (17 cases), adding
  failing-log-repository regressions for success-log failure and original
  failure preservation.
- Verification: focused source-importer tests passed (17 cases), full Flutter
  tests passed (`+404`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the best-effort import-log boundary, focused regressions,
  docs references, and this timeline entry; preserve ingestion, normalization,
  artifact persistence, original error semantics, and importer routing.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
