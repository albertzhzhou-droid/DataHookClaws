# Slice158 — Export history persistence isolation

- Date: 2026-09-02
- Scope: Export artifact and export-history persistence boundary.
- Change: after an export file is written, `addExportHistory` is now treated as
  supplemental. A history write failure no longer invalidates the returned
  `ExportArtifact` or reports the file write as a failed export.
- Tests: the existing export-service suite passed (9 cases), adding a
  history-only write failure regression that checks the file remains present
  and no history row is fabricated.
- Verification: focused export-service tests passed (9 cases), full Flutter
  tests passed (`+397`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the export-history write boundary, focused regression, docs
  references, and this timeline entry; preserve export formats, deterministic
  paths, AI summary behavior, and recall persistence.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
