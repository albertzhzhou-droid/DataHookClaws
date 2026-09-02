# Slice150 — Replay-status persistence isolation

- Date: 2026-09-02
- Scope: HomePage compare replay status persistence.
- Change: `recent_export_replay_statuses_v1` writes now use a best-effort
  boundary; a failed status write leaves the live compare replay status
  visible and does not escape as an unhandled Future during replay or archival.
- Tests: `test/widget_test.dart` passed (28 cases), including a short-ID
  compare recall with a repository that fails only replay-status writes.
- Verification: focused widget tests passed (28 cases), full Flutter tests
  passed (`+390`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the replay-status persistence boundary, focused regression,
  docs references, and this timeline entry; preserve compare replay state,
  metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
