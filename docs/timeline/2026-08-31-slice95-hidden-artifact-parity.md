# Slice95 — Hidden Web build metadata parity

- Date: 2026-08-31 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: keep the downloaded Web artifact's file set aligned with its provenance manifest without creating a duplicate release copy.

## Changes

- Audited the built Web directory and confirmed Flutter emits the hidden
  `.last_build_id` file.
- Added `include-hidden-files: true` to the existing GitHub Actions upload so
  the file set consumed by artifact users matches the set hashed by
  `tool/build_release_provenance.dart`.
- Locked the option in the existing CI workflow test and documented the
  hidden-metadata inclusion in the existing release notes.

## Verification and rollback

- Focused CI workflow tests passed (`+29`) and `git diff --check` passed.
- Full Flutter tests passed (`+333`), `flutter analyze` reported zero issues,
  `git diff --check` passed, and strict `CI=true ./tool/ci_checks.sh` passed
  with 14 importer tests, all compare gates, Web build, and provenance
  generate/verify.
- Rollback is surgical: remove the upload option, incremental test/docs lines,
  and this timeline entry; preserve the existing artifact and provenance gates.
