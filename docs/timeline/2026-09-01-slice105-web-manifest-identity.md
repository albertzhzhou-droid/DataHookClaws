# Slice105 — Web manifest identity provenance

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: keep generated Web PWA identity aligned with the canonical package
  before release evidence is accepted.

## Changes

- Extended the existing provenance CLI with opt-in
  `--require-web-manifest`, requiring `manifest.json` `name` and `short_name`
  to equal the package name from `pubspec.yaml`.
- Enabled the gate for local/GitHub provenance generation and verification and
  added positive/tampered-identity coverage. No duplicate artifact or source
  copy was introduced.

## Verification and rollback

- Focused workflow tests passed (`+39`), full Flutter tests passed (`+343`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/version/manifest gates, provenance generation, and provenance
  verification.
- Rollback is surgical: remove the optional manifest checker, its CLI
  arguments, focused test/docs lines, and this timeline entry; preserve shell,
  version, and base provenance gates.
