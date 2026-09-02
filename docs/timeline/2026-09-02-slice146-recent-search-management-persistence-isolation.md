# Slice146 — Recent-search management persistence isolation

- Date: 2026-09-02
- Scope: HomePage recent-search removal and clear-all actions.
- Change: management actions now use best-effort `recent_searches_v1`
  persistence; write failures leave the in-memory list responsive and do not
  escape as unhandled Futures.
- Tests: `test/widget_test.dart` passed (24 cases), including clear-all with a
  repository that fails recent-search writes.
- Verification: focused widget tests passed (24 cases), full Flutter tests
  passed (`+386`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the recent-search management helper, focused regression,
  docs references, and this timeline entry; preserve search recording,
  in-memory state, metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
