# Slice109 — Web shell reference integrity

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: ensure index.html shell references resolve inside the artifact.

## Changes

- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-web-shell-references` flag. It requires references to
  `flutter_bootstrap.js`, `manifest.json`, `favicon.png`, and
  `icons/Icon-192.png`, and checks each target is a regular file in the Web
  artifact.
- Enabled the flag for local/GitHub provenance generation and verification.
- Added focused positive, missing-target, and missing-reference regression
  coverage and wiring assertions. No artifact path, source copy, or runtime
  behavior changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+43`); full Flutter tests passed
  (`+347`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/reference/version/manifest/revision gates, icon-asset provenance
  generation, and provenance verification.
- Rollback is surgical: remove the optional shell-reference flag and its
  local/CI arguments, focused assertions, release-note text, and this timeline
  entry; preserve the existing shell, icon, identity, revision, and hashing
  gates.
