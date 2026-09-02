# Slice94 — Web artifact upload contract

- Date: 2026-08-31 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: make the existing Web artifact consumer contract fail-closed and lifecycle-explicit without creating a duplicate release copy.

## Changes

- Added `if-no-files-found: error` to the existing GitHub Actions upload so a
  missing Web build or provenance manifest cannot produce a misleading green
  job.
- Set `retention-days: 14` for the `datahookclaws-web` CI artifact.
- Documented the bounded archive layout (`web/` plus the sibling provenance
  manifest) and retention in the existing release notes.
- Extended the existing CI workflow test with upload-option assertions.

## Verification and rollback

- Focused CI workflow tests passed (`+29`) and `git diff --check` passed.
- Full Flutter tests passed (`+333`), `flutter analyze` reported zero issues,
  `git diff --check` passed, and strict `CI=true ./tool/ci_checks.sh` passed
  with 14 importer tests, all compare gates, Web build, and provenance
  generate/verify.
- Rollback is surgical: remove the two upload options, incremental test/docs
  lines, and this timeline entry; preserve build and provenance verification.
