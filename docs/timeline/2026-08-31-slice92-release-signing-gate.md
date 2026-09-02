# Slice92 — Android release signing gate

- Date: 2026-08-31 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: close one bounded production-release configuration gap without creating a duplicate release copy.

## Changes

- Extended the existing `tool/check_release_metadata.dart` with opt-in
  `--require-release-signing` validation.
- The gate parses the Android `release` build-type block, requires an explicit
  `signingConfig`, and rejects debug signing or the template signing TODO.
- Kept ordinary local and GitHub CI metadata checks unchanged; the intentional
  release-cut command in `docs/release_packaging.md` now opts into the gate.
- Added focused regression and command-wiring assertions to the existing
  `test/domain/ci_workflow_test.dart`.

## Verification and rollback

- Focused CI workflow tests passed (`+28`); the current development config is
  intentionally rejected with a debug-signing diagnostic when the production
  gate is requested.
- Full Flutter tests passed (`+332`), `flutter analyze` reported zero issues,
  `git diff --check` passed, and strict `CI=true ./tool/ci_checks.sh` passed
  with 14 importer tests, all compare gates, Web build, and provenance
  generate/verify. The production gate intentionally returns exit 1 for the
  checked-in debug signing configuration.
- Rollback is surgical: remove the optional checker branch, its test/docs
  additions, and this timeline entry; preserve default metadata and provenance
  checks.
