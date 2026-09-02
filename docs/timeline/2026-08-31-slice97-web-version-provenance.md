# Slice97 — Web version provenance contract

- Date: 2026-08-31 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: ensure a built Web artifact's generated version metadata agrees with the canonical package identity before it is consumed.

## Changes

- Extended the existing `tool/build_release_provenance.dart` with opt-in
  `--require-web-version` validation for Flutter's `version.json`.
- The gate compares package name, app name, semantic version, and build number
  with `pubspec.yaml`; local and GitHub generate/verify steps now enable it.
- Added positive and tampered-version coverage to the existing CI workflow test
  and documented the command in the existing release notes.

## Verification and rollback

- Focused CI workflow tests passed (`+31`), full Flutter tests passed (`+335`),
  `flutter analyze` reported zero issues, and `git diff --check` passed.
  Strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all
  compare gates, Web build, provenance generation, and provenance verification
  including the Web version gate.
- Rollback is surgical: remove the optional version gate, CI arguments,
  incremental test/docs lines, and this timeline entry; preserve base
  provenance generation and verification.
