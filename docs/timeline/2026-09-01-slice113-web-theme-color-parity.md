# Slice113 — Web theme-color parity contract

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: keep the PWA theme color consistent across source and generated shell.

## Changes

- Added the canonical `<meta name="theme-color" content="#0175C2">` to the
  existing `web/index.html`.
- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-web-theme-color-parity` flag. It requires one identical,
  non-empty theme color in source `web/index.html`, source `web/manifest.json`,
  generated `index.html`, and generated `manifest.json`.
- Enabled the flag for local/GitHub provenance generation and verification and
  added focused valid and index/manifest tamper coverage. No artifact path,
  source copy, or runtime behavior changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+47`); full Flutter tests passed
  (`+351`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/reference/metadata/PWA/icon/theme/version/manifest/revision gates,
  provenance generation, and provenance verification.
- Rollback is surgical: remove the theme-color source tag, optional checker,
  local/CI arguments, focused assertions, release-note text, and this timeline
  entry; preserve the existing shell, icon, metadata, PWA, identity, revision,
  and hashing gates.
