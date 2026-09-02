# Slice99 — CI release-evidence concurrency contract

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: prevent superseded GitHub Actions runs from producing competing
  release-evidence artifacts for the same workflow and Git ref.

## Changes

- Added workflow-level concurrency grouping by `github.workflow` and
  `github.ref`, with `cancel-in-progress: true`, to the existing CI workflow.
- Added a focused regression and documented that cancellation affects running
  work only; it does not delete already uploaded artifacts. No new artifact or
  duplicate canonical content was introduced.

## Verification and rollback

- Focused workflow tests passed (`+33`), full Flutter tests passed (`+337`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all
  compare gates, Web build, provenance generation, and provenance verification.
- Rollback is surgical: remove the concurrency block, focused assertion,
  release-note paragraph, and this timeline entry; preserve permissions and
  artifact/provenance checks.
