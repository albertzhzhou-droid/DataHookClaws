# Slice145 — Recent-search persistence isolation

- Date: 2026-09-02
- Scope: HomePage recent-search metadata persistence before standard search.
- Change: a failed `recent_searches_v1` write is now best-effort; the requested
  search continues and the in-memory recent-search state remains current.
- Tests: `test/widget_test.dart` passed (23 cases), including seeded results
  with a repository that fails only recent-search writes.
- Verification: focused widget tests passed (23 cases), full Flutter tests
  passed (`+385`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the recent-search persistence catch, focused regression,
  docs references, and this timeline entry; preserve search execution,
  in-memory recent-search state, metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
