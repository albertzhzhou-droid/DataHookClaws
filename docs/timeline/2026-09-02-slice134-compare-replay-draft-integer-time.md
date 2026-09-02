# Slice134 — Compare replay draft integer timestamps

- Date: 2026-09-02
- Scope: HomePage `recent_export_replay_drafts_v1` timestamp decoding.
- Change: persisted draft timestamps now accept only integer values or integer
  strings. Fractional, non-finite, and other typed values are skipped instead
  of being silently truncated into a plausible epoch-millisecond value; the
  existing archive path marks the affected draft as requiring manual rebuild.
- Tests: `test/widget_test.dart` passed (12 cases), including a future
  fractional timestamp paired with a compare draft status.
- Verification: full Flutter tests passed (`+374`), strict
  `CI=true ./tool/ci_checks.sh` passed with the canonical dependency file,
  including lockfile, 14 importer tests, compare/accessibility gates, Web
  release build, and provenance generate/verify; `flutter analyze --no-pub`
  reported zero issues and `git diff --check` passed.
- Rollback: remove the persisted-integer parser, focused regression, docs
  references, and this timeline entry; preserve valid draft retention,
  status/archive semantics, metadata keys, UTF-8 budgets, and the write queue.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
