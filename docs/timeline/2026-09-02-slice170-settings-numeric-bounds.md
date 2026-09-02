# Slice170 — Settings numeric bounds

## Version

- Iteration: Slice170
- Date: 2026-09-02
- Scope: `SettingsService` numeric sanitization at read and save boundaries
- Rollback unit: this timeline entry, the focused regression, documentation
  references, and the numeric sanitization helpers in the canonical settings
  service

## Changes

- Normalize negative `modelMaxCallsPerMinute` values to the default while
  retaining zero as an explicit AI-disable setting.
- Require positive values for model timeout, max tokens, and database,
  artifact, export, and cache budgets; unsafe values now fall back to their
  defaults before runtime construction or persistence.
- Apply the same normalization to persisted reads and explicit saves so the
  stored `app_settings` payload cannot reintroduce invalid runtime limits.
- Added a focused regression covering malformed persisted values, normalized
  runtime settings, and normalized saved JSON.
- Edited only canonical source/test/docs files; no full-content source copy or
  duplicate release artifact was created.

## Verification

- Focused Settings/AI suite: 12 cases passed.
- Full Flutter suite: `+417 All tests passed!`.
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed with the canonical dependency
  file, lockfile gate, 14 importer tests, compare/accessibility checks, Web
  release build, and provenance generate/verify checks.

## Rollback

Remove the numeric sanitization helpers, their focused regression, the related
`AGENT.md`, `docs/PROJECT_PLAN.md`, and `docs/UPGRADE_QUEUE.md` entries, and
this timeline file. Preserve source enablement sanitization, explicit zero-call
disable semantics, and settings persistence.

## Next

Inspect one bounded persistence or release-evidence contract while preserving
the no-duplicate-canonical-content rule.
