# Slice144 — Initial results read recovery

- Date: 2026-09-02
- Scope: HomePage initial refresh and its primary `searchFoods` read.
- Change: initial refresh failures now leave a truthful local-results-unavailable
  state with a retry action instead of endless loading or an unhandled async
  error.
- Tests: `test/widget_test.dart` passed (22 cases), including transient primary
  read failure followed by successful retry.
- Verification: focused widget tests passed (22 cases), full Flutter tests
  passed (`+384`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the initial-refresh safety boundary, error card, retry
  regression, docs references, and this timeline entry; preserve standard and
  advanced search behavior, result/log/count reads, metadata keys, and
  write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
