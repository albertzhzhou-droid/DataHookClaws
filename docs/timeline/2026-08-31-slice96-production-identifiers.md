# Slice96 — Production platform identifiers

- Date: 2026-08-31 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: close the template bundle/application identifier gap for distributable platform builds without creating a duplicate release copy.

## Changes

- Extended the existing `tool/check_release_metadata.dart` with opt-in
  `--require-production-identifiers` validation.
- The gate rejects template or unresolved Android `applicationId` and iOS/macOS
  Release `PRODUCT_BUNDLE_IDENTIFIER` values, while leaving test-only bundle
  identifiers out of the production check.
- Enabled the gate in the documented release-cut command and recorded the
  current `com.example...` values as a deliberate fail-fast blocker.
- Added focused three-platform rejection and command-wiring assertions to the
  existing CI workflow test.

## Verification and rollback

- Focused CI workflow tests passed (`+30`), full Flutter tests passed (`+334`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all
  compare gates, Web build, and provenance generate/verify.
- Rollback is surgical: remove only the optional identifier checker, its test/
  documentation lines, and this timeline entry; preserve signing, metadata,
  artifact, and provenance checks.
