# Slice107 — Source revision provenance gate

- Date: 2026-09-01 (America/Toronto)
- Canonical ref: `codex/public-github-launch`
- Scope: require Web release provenance to carry a non-empty source revision.

## Changes

- Extended the existing `tool/build_release_provenance.dart` CLI with the
  opt-in `--require-revision` flag. It fails before artifact hashing when
  `--revision` is missing or blank.
- Passed `$GITHUB_SHA` with the requirement in both GitHub provenance commands.
  The local `tool/ci_checks.sh` wrapper resolves `DHC_SOURCE_REVISION` first,
  then the checked-out `git rev-parse --verify HEAD`, and passes the same
  requirement to generation and verification.
- Added focused regression coverage for missing and valid source revisions,
  plus workflow/local wiring assertions. No artifact path, source copy, or
  runtime behavior changed.

## Verification and rollback

- Focused `ci_workflow_test.dart` passed (`+41`); full Flutter tests passed
  (`+345`); `flutter analyze` reported zero issues; `git diff --check` passed.
- Strict `CI=true ./tool/ci_checks.sh` passed with the lockfile gate, 14
  importer tests, all compare gates, explicit Web release build,
  shell/version/manifest gates, source-revision provenance generation, and
  provenance verification.
- Rollback is surgical: remove the optional flag and its CI/local arguments,
  focused assertions, release-note text, and this timeline entry; preserve
  the existing hashing and Web shell/version/manifest gates.
