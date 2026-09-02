# Slice93 — Apple release signing gate

- Date: 2026-08-31 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: close one bounded iOS/macOS release-signing configuration gap without creating a duplicate release copy.

## Changes

- Extended the existing `tool/check_release_metadata.dart` with opt-in
  `--require-apple-signing` validation.
- The gate inspects every iOS and macOS Xcode `Release` configuration, rejects
  development/placeholder identities, and requires either `DEVELOPMENT_TEAM` or
  an explicit distribution `CODE_SIGN_IDENTITY`.
- Kept Apple credentials, provisioning profiles, and notarization external to
  the repository; the documented release-cut command now enables this gate
  alongside Android signing validation while ordinary CI remains unchanged.
- Added focused regression and command-wiring assertions to the existing
  `test/domain/ci_workflow_test.dart`.

## Verification and rollback

- Focused CI workflow tests passed (`+29`); the current template is rejected
  with actionable iOS and macOS signing diagnostics when the production gate is
  requested.
- Full Flutter tests passed (`+333`), `flutter analyze` reported zero issues,
  `git diff --check` passed, and strict `CI=true ./tool/ci_checks.sh` passed
  with 14 importer tests, all compare gates, Web build, and provenance
  generate/verify. The production gate intentionally returns exit 1 for the
  checked-in development/placeholder iOS and macOS identities.
- Rollback is surgical: remove the optional Apple checker, its test/docs lines,
  and this timeline entry; preserve default metadata, Android, and provenance
  checks.
