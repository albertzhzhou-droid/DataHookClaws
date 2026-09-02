# DataHookClaws timeline — Slice90

- Version: `Slice90` (`2026-08-31`, America/Toronto); canonical package version remains `1.0.0+1`.
- Scope: make Web build consumption auditable with a deterministic artifact provenance manifest.
- Existing canonical files changed: `tool/ci_checks.sh`, `.github/workflows/flutter-ci.yml`, `test/domain/ci_workflow_test.dart`, `tool/build_release_provenance.dart`, `docs/release_packaging.md`, `AGENT.md`, `docs/PROJECT_PLAN.md`, `docs/upgrade_queue.md`, and `pubspec.yaml`/`pubspec.lock` were inspected; the dependency files remain unchanged after removing the unnecessary crypto dependency.
- Incremental implementation: the generator hashes regular files with a self-contained SHA-256 implementation, rejects symlinks and output paths inside the artifact, sorts relative paths, and writes only a manifest outside `build/web`. GitHub adds `GITHUB_SHA`; local generation stays deterministic without it.
- Regression coverage: focused CI tests assert known SHA-256 output, sorted paths, byte-for-byte repeated generation, manifest self-exclusion boundary, and local/GitHub upload wiring.
- Verification: focused `flutter test test/domain/ci_workflow_test.dart` passed (`+27`); `flutter analyze` reported zero issues; full Flutter tests passed (`+331`); `git diff --check` and strict `CI=true ./tool/ci_checks.sh` passed with importer/compare gates, Web build, and provenance generation; all 39 manifest entries matched system `shasum`.
- Rollback point: remove only the generator, CI invocations, incremental docs/test lines, and this timeline entry; leave `build/web` generation and canonical source files intact.
- Storage rule: this log records only the delta and verification evidence; it intentionally does not copy any complete source, test, release, or documentation file.
