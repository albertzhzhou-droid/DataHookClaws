# Slice168 — Export directory resolution read isolation

## Version

- Iteration: Slice168
- Date: 2026-09-02
- Scope: `SettingsService.effectiveExportDirectory` storage-path metadata
- Rollback unit: this timeline entry, the focused regression, documentation
  references, and the fallback in the canonical settings service

## Changes

- Treated repository storage-path metadata as supplemental input to export
  directory resolution.
- Added a fail-open fallback to `Directory.current/exports` when the metadata
  read throws or returns an empty exports path.
- Preserved precedence for a non-empty explicit `AppSettings.exportDirectory`;
  its trimmed value remains the selected path.
- Added a focused regression proving a storage-path read failure resolves to the
  deterministic fallback and does not retry the metadata read.
- Edited only canonical source/test/docs files; no full-content source copy or
  duplicate release artifact was created.

## Verification

- Focused Settings/AI suite: 10 cases passed.
- Full Flutter suite: `+414 All tests passed!`.
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed with the canonical dependency
  file, lockfile gate, 14 importer tests, compare/accessibility checks, Web
  release build, and provenance generate/verify checks.

## Rollback

Remove the storage-path try/catch fallback, its focused test, the related
`AGENT.md`, `docs/PROJECT_PLAN.md`, and `docs/UPGRADE_QUEUE.md` entries, and
this timeline file. Preserve explicit export-directory precedence, settings
sanitization, and export formats.

## Next

Inspect one bounded persistence or release-evidence contract while preserving
the no-duplicate-canonical-content rule.
