# Slice155 — Provenance dangling-path resolution

- Date: 2026-09-02
- Scope: Release provenance containment-path resolution.
- Change: artifact input, output, and verify paths now resolve through a
  fail-closed wrapper. Dangling or otherwise unresolvable symlinks produce a
  stable diagnostic and stop before hashing or writing instead of leaking an
  uncaught filesystem stack.
- Tests: `test/domain/ci_workflow_test.dart` passed (55 cases), extending the
  deterministic path-safety regression with dangling output, verify, and input
  symlink cases.
- Verification: focused CI workflow tests passed (55 cases), full Flutter
  tests passed (`+393`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the safe containment resolver, focused dangling-link
  regressions, docs references, and this timeline entry; preserve regular
  artifact-root validation, destination containment, deterministic hashing,
  and Web contract checks.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
