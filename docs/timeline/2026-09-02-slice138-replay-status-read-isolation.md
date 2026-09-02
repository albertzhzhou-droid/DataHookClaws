# Slice138 — Replay-status read isolation

- Date: 2026-09-02
- Scope: HomePage startup loading of `recent_export_replay_statuses_v1`.
- Change: status-cache storage failures are now isolated as an optional layer;
  valid compare recall chips remain visible without a status suffix while the
  rest of replay restoration and archive handling continues.
- Tests: `test/widget_test.dart` passed (16 cases), including a repository that
  fails only the replay-status metadata read.
- Verification: focused widget tests passed (16 cases), full Flutter tests
  passed (`+378`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the replay-status read guard, focused regression, docs
  references, and this timeline entry; preserve valid recall chips, status
  semantics, metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
