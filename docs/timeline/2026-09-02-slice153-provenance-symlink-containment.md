# Slice153 — Provenance symlink containment

- Date: 2026-09-02
- Scope: Release provenance output and verification path safety.
- Change: output/verify containment now resolves existing path components
  before comparing destinations with the artifact. A symlink redirect can no
  longer appear external while pointing back into the hashed artifact.
- Tests: `test/domain/ci_workflow_test.dart` passed (55 cases), including a
  symlinked artifact-directory redirect regression with the stable diagnostic.
- Verification: focused CI workflow tests passed (55 cases), full Flutter
  tests passed (`+393`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the containment resolver, focused symlink regression, docs
  references, and this timeline entry; preserve deterministic manifest
  hashing, output/verify semantics, and Web contract checks.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
