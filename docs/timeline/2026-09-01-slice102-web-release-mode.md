# Slice102 — explicit Web release-mode packaging

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: make the Web artifact's release build mode explicit in every local
  and CI release-evidence path.

## Changes

- Changed the GitHub Actions and local CI Web build commands to
  `flutter build web --release`.
- Added a focused workflow/script regression and updated the existing Web
  packaging command. No new artifact path or duplicate content was introduced.

## Verification and rollback

- Focused workflow tests passed (`+36`), full Flutter tests passed (`+340`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build, provenance
  generation, and provenance verification.
- Rollback is surgical: restore the prior build arguments, remove the focused
  assertion, documentation change, and this timeline entry; preserve the
  provenance and version gates.
