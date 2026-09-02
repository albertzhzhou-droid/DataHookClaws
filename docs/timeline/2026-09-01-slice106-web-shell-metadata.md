# Slice106 — Web shell product metadata

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: remove default Flutter template copy from the Web shell's user-facing
  description.

## Changes

- Updated the existing `web/manifest.json` and `web/index.html` descriptions to
  describe DataHookClaws as a local-first nutrition database built from
  official food-composition sources.
- Added a focused regression for both source files and documented the metadata
  boundary. No new artifact or duplicate source copy was introduced.

## Verification and rollback

- Focused workflow tests passed (`+40`), full Flutter tests passed (`+344`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/version/manifest gates, provenance generation, and provenance
  verification.
- Rollback is surgical: restore the prior description strings, remove the
  focused assertion, release-note sentence, and this timeline entry; preserve
  manifest identity and provenance gates.
