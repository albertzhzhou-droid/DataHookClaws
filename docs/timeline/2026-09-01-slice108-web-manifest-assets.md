# Slice108 — Web manifest icon asset provenance

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: ensure Web PWA manifest icon references resolve inside the artifact.

## Changes

- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-web-manifest-assets` flag. It requires a non-empty `icons`
  array, rejects absolute/traversal/external-URL sources, and requires each
  `icons[].src` to resolve to a regular file in the Web artifact.
- Enabled the flag for local/GitHub provenance generation and verification.
- Added focused positive, missing-icon, and unsafe-path regression coverage and
  wiring assertions. No artifact path, source copy, or runtime behavior
  changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+42`); full Flutter tests passed
  (`+346`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/version/manifest/revision gates, icon-asset provenance generation, and
  provenance verification.
- Rollback is surgical: remove the optional icon-assets flag and its
  local/CI arguments, focused assertions, release-note text, and this timeline
  entry; preserve the existing shell, identity, revision, and hashing gates.
