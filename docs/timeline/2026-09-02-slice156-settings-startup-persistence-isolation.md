# Slice156 — Settings startup persistence isolation

- Date: 2026-09-02
- Scope: Application settings startup persistence.
- Change: `SettingsService.load()` now returns in-memory defaults when the
  `app_settings` read is unavailable, and malformed-settings repair writes are
  best-effort. A transient metadata failure cannot abort startup or turn a
  recoverable decode failure into a second failure.
- Tests: the existing settings service suite passed (7 cases), adding
  unavailable-read and malformed-repair-write-failure regressions.
- Verification: focused settings tests passed (7 cases), full Flutter tests
  passed (`+393`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the settings read fallback, best-effort repair helper,
  focused regressions, docs references, and this timeline entry; preserve
  settings sanitization, explicit save semantics, and runtime wiring.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
