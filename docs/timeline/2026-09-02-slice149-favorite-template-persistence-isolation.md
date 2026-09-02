# Slice149 — Favorite-template persistence isolation

- Date: 2026-09-02
- Scope: HomePage favorite template save and delete persistence.
- Change: favorite template mutations now use best-effort
  `favorite_templates_v1` persistence; write failures leave the in-memory
  template list responsive and do not escape as unhandled Futures.
- Tests: `test/widget_test.dart` passed (27 cases), including a seeded
  favorite with a repository that fails only favorite-template writes.
- Verification: focused widget tests passed (27 cases), full Flutter tests
  passed (`+389`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the favorite-template persistence boundary, focused
  regression, docs references, and this timeline entry; preserve in-memory
  template state, metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
