# Slice112 — Web manifest icon metadata contract

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: keep PWA icon metadata semantically usable by installers.

## Changes

- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-web-manifest-icon-metadata` flag. It validates every icon's
  `sizes` (`WIDTHxHEIGHT` or `any`), supported image MIME `type`, and optional
  `purpose` tokens (`any`, `maskable`, or `monochrome`).
- Enabled the flag for local/GitHub provenance generation and verification.
- Added focused valid, missing-file, invalid-size, invalid-type, and
  invalid-purpose regression coverage and wiring assertions. No artifact path,
  source copy, or runtime behavior changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+46`); full Flutter tests passed
  (`+350`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/reference/metadata/PWA/icon/version/manifest/revision gates, icon-asset
  provenance generation, and provenance verification.
- Rollback is surgical: remove the optional icon-metadata flag and its local/CI
  arguments, focused assertions, release-note text, and this timeline entry;
  preserve the existing shell, icon-assets, PWA, identity, revision, and
  hashing gates.
