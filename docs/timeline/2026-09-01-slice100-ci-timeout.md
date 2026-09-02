# Slice100 — CI release-evidence timeout contract

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: bound the maximum runtime of the GitHub Actions release-evidence job.

## Changes

- Added `timeout-minutes: 30` to the existing `analyze-test-web` job.
- Added a focused workflow regression and documented the resource boundary.
  No artifact, source copy, or deployment behavior was added.

## Verification and rollback

- Focused workflow tests passed (`+34`), full Flutter tests passed (`+338`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all
  compare gates, Web build, provenance generation, and provenance verification.
- Rollback is surgical: remove the timeout, focused assertion, release-note
  sentence, and this timeline entry; preserve permissions, concurrency, and
  artifact/provenance checks.
