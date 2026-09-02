# Slice137 — Recent export recall history fallback

- Date: 2026-09-02
- Scope: HomePage startup loading of `recent_export_recalls_v1`.
- Change: an unavailable recall-cache metadata read is now treated as a cache
  miss, so the existing export-history fallback rebuilds valid recall chips
  instead of aborting the loader.
- Tests: `test/widget_test.dart` passed (15 cases), including a repository that
  fails only the recall-cache read while a country history entry remains.
- Verification: full Flutter tests passed (`+377`), strict
  `CI=true ./tool/ci_checks.sh` passed with the canonical dependency file,
  including lockfile, 14 importer tests, compare/accessibility gates, Web
  release build, and provenance generate/verify; `flutter analyze --no-pub`
  reported zero issues and `git diff --check` passed.
- Rollback: remove the recall-cache read guard, focused regression, docs
  references, and this timeline entry; preserve history fallback, valid replay,
  metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
