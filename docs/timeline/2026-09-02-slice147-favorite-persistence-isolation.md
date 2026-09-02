# Slice147 — Favorite persistence isolation

- Date: 2026-09-02
- Scope: HomePage favorite toggle, removal, and clear-all mutations.
- Change: favorite mutations now use a safe `favorite_foods_v1` persistence
  helper; write failures leave the in-memory favorite state responsive and do
  not escape as unhandled Futures.
- Tests: `test/widget_test.dart` passed (25 cases), including a seeded result
  whose favorite write fails.
- Verification: focused widget tests passed (25 cases), full Flutter tests
  passed (`+387`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the favorite persistence helper, focused regression, docs
  references, and this timeline entry; preserve favorite in-memory state,
  metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
