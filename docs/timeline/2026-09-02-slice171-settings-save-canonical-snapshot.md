# Slice171 — Settings save canonical snapshot

- Date: 2026-09-02
- Scope: settings persistence and form-state reconciliation
- Change: `SettingsService.save` now returns the sanitized `AppSettings` that
  was written; `SettingsPage` adopts that snapshot after a successful save.
- Regression coverage: unsafe numeric form input is persisted with safe bounds;
  the service return value matches the persisted canonical payload.
- Focused verification: Settings/AI 12 cases and settings-page 3 cases passed.
- Full verification: Flutter tests passed (`+418`), `flutter analyze` reported
  zero issues, and `git diff --check` passed.
- Strict verification: `CI=true ./tool/ci_checks.sh` passed with the canonical
  dependency file, including lockfile, 14 importer, compare/accessibility, Web
  build, and provenance generate/verify checks.
- Rollback: restore the prior void save contract and raw form-state assignment;
  remove only this slice's regression/docs references and this timeline.
- Boundary preserved: numeric sanitization, explicit zero-call AI disable,
  source enablement filtering, persistence keys, and all export/search flows.
