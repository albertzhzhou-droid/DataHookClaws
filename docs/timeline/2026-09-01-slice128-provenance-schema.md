# Slice128 — Provenance manifest strict schema

- Date: 2026-09-01
- Scope: strict release provenance manifest verification.
- Change: `_verifyManifest` now rejects unknown root fields and unknown file-entry
  fields; the expected key set includes optional `sourceRevision` only when the
  verification invocation supplies one. Existing hash/size/path comparisons
  remain unchanged.
- Tests: `flutter test test/domain/ci_workflow_test.dart` passed (54 cases)
  under a temporary environment-only sqlite system hook.
- Verification: full Flutter tests passed (`+367`) and strict
  `CI=true ./tool/ci_checks.sh` passed under that temporary hook, including
  lockfile, 14 importer tests, compare/accessibility gates, Web release build,
  and provenance generate/verify; `flutter analyze --no-pub` reported zero
  issues and `git diff --check` passed. The temporary pubspec hook was removed
  afterward.
- Rollback: remove the exact root/file-entry schema guards, focused regression,
  docs references, and this timeline entry; preserve all artifact hash and Web
  contract checks.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
