# Slice154 — Provenance artifact-root symlink rejection

- Date: 2026-09-02
- Scope: Release provenance artifact input root validation.
- Change: the artifact input must now be a regular directory rather than a
  symlink. Root symlinks fail closed so an external directory cannot be
  silently adopted as the hashed release artifact.
- Tests: `test/domain/ci_workflow_test.dart` passed (55 cases), extending the
  path-safety regression with a symlinked artifact-root case.
- Verification: focused CI workflow tests passed (55 cases), full Flutter
  tests passed (`+393`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the artifact-root type guard, focused regression, docs
  references, and this timeline entry; preserve destination containment,
  deterministic hashing, and Web contract checks.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
