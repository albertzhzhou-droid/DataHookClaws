# Slice101 — release-evidence lockfile reproducibility

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: ensure release-evidence checks resolve exactly from the checked-in
  dependency lockfile.

## Changes

- Changed the GitHub Actions dependency step to
  `flutter pub get --enforce-lockfile`.
- Added the same lockfile gate to the local `tool/ci_checks.sh` wrapper and a
  focused workflow/script regression. No dependency upgrade or duplicate
  release content was introduced.

## Verification and rollback

- Focused workflow tests passed (`+35`), full Flutter tests passed (`+339`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback is surgical: restore plain `flutter pub get`, remove the local gate,
  focused assertion, release-note paragraph, and this timeline entry; preserve
  existing permissions, concurrency, timeout, and provenance checks.
