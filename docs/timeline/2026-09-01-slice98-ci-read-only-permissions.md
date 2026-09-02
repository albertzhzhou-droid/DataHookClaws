# Slice98 — CI release-evidence read-only permissions

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: constrain the GitHub Actions release-evidence workflow to the
  repository permission it actually needs.

## Changes

- Added the workflow-level `permissions: contents: read` contract to the
  existing `.github/workflows/flutter-ci.yml`.
- Added a focused workflow regression and documented that artifact evidence is
  produced without repository-write authority. No deployment permission or
  duplicate release artifact was introduced.

## Verification and rollback

- Focused workflow tests passed (`+32`), full Flutter tests passed (`+336`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all
  compare gates, Web build, provenance generation, and provenance verification.
- Rollback is surgical: remove the workflow permission block, focused
  assertion, release-note paragraph, and this timeline entry; preserve the
  existing artifact/provenance checks.
