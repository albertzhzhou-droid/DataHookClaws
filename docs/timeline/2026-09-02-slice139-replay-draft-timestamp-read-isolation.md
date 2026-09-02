# Slice139 — Replay-draft timestamp read isolation

- Date: 2026-09-02
- Scope: HomePage startup loading of `recent_export_replay_drafts_v1`.
- Change: draft-timestamp storage failures are isolated as an optional layer;
  replay statuses still restore, and a Draft without a readable timestamp is
  archived as `Unavailable (manual rebuild required)`.
- Tests: `test/widget_test.dart` passed (17 cases), including a repository that
  fails only the draft-timestamp metadata read while a persisted Draft status
  remains available.
- Verification: focused widget tests passed (17 cases), full Flutter tests
  passed (`+379`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the draft-timestamp read guard, focused regression, docs
  references, and this timeline entry; preserve status restoration, archival
  semantics, metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
