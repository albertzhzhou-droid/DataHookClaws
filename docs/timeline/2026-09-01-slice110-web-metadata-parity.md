# Slice110 — Web metadata parity provenance

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: keep canonical Web descriptions aligned with generated artifacts.

## Changes

- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-web-metadata-parity` flag. It reads the single non-empty
  description from canonical `web/index.html` and `web/manifest.json`, then
  requires generated `index.html` and `manifest.json` to carry that value.
- Enabled the flag for local/GitHub provenance generation and verification.
- Added focused positive and index/manifest tamper regression coverage and
  wiring assertions. No artifact path, source copy, or runtime behavior
  changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+44`); full Flutter tests passed
  (`+348`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/reference/metadata/version/manifest/revision gates, icon-asset
  provenance generation, and provenance verification.
- Rollback is surgical: remove the optional metadata-parity flag and its
  local/CI arguments, focused assertions, release-note text, and this timeline
  entry; preserve the existing shell, icon, identity, revision, and hashing
  gates.
