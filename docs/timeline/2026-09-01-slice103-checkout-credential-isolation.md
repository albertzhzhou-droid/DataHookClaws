# Slice103 — checkout credential isolation

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: prevent the release-evidence workflow from persisting GitHub checkout
  credentials in its workspace.

## Changes

- Set `persist-credentials: false` on the existing `actions/checkout@v4` step.
- Added a focused workflow regression and documented the workspace credential
  boundary. No permission grant, artifact, or duplicate canonical content was
  introduced.

## Verification and rollback

- Focused workflow tests passed (`+37`), full Flutter tests passed (`+341`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build, provenance
  generation, and provenance verification.
- Rollback is surgical: remove the checkout option, focused assertion,
  release-note sentence, and this timeline entry; preserve read-only
  permissions, concurrency, timeout, lockfile, and provenance checks.
