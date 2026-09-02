# Slice111 — Web PWA startup/display contract

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: keep generated PWA startup and display metadata release-safe.

## Changes

- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-web-pwa-contract` flag. It requires a safe relative
  `start_url`, a recognized `display` mode, and non-empty
  `background_color`/`theme_color` values in `manifest.json`.
- Enabled the flag for local/GitHub provenance generation and verification.
- Added focused valid, external-start, unknown-display, and missing-color
  regression coverage and wiring assertions. No artifact path, source copy, or
  runtime behavior changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+45`); full Flutter tests passed
  (`+349`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/reference/metadata/PWA/version/manifest/revision gates, icon-asset
  provenance generation, and provenance verification.
- Rollback is surgical: remove the optional PWA-contract flag and its local/CI
  arguments, focused assertions, release-note text, and this timeline entry;
  preserve the existing shell, icon, metadata, identity, revision, and hashing
  gates.
