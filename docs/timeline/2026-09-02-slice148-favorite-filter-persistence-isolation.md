# Slice148 — Favorite-filter persistence isolation

- Date: 2026-09-02
- Scope: HomePage favorite country/source/category/sort filter persistence.
- Change: favorite-filter metadata writes are now best-effort; a failed
  `favorite_filters_v1` write leaves the in-memory selection responsive and
  does not escape as an unhandled Future.
- Tests: `test/widget_test.dart` passed (26 cases), including a seeded favorite
  with a repository that fails only favorite-filter writes.
- Verification: focused widget tests passed (26 cases), full Flutter tests
  passed (`+388`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the favorite-filter persistence boundary, focused
  regression, docs references, and this timeline entry; preserve in-memory
  selections, metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
