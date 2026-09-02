# DataHookClaws timeline — Slice91

- Version: `Slice91` (`2026-08-31`, America/Toronto); canonical package version remains `1.0.0+1`.
- Scope: close the artifact-consumption gap by verifying the provenance manifest against the exact built Web directory before upload.
- Existing canonical files changed: `tool/build_release_provenance.dart`, `tool/ci_checks.sh`, `.github/workflows/flutter-ci.yml`, `test/domain/ci_workflow_test.dart`, `docs/release_packaging.md`, `AGENT.md`, `docs/PROJECT_PLAN.md`, and `docs/upgrade_queue.md`.
- Incremental implementation: `--verify` recomputes the sorted artifact snapshot and compares schema, package/version, file count/bytes, paths, digests, and supplied source revision without rewriting the manifest or copying artifact content.
- Regression coverage: successful verification and tampered-file failure are asserted in the existing CI workflow test; local and GitHub pipelines both verify immediately before upload.
- Verification: focused `flutter test test/domain/ci_workflow_test.dart` passed (`+27`); `flutter analyze` reported zero issues; full Flutter tests passed (`+331`); `git diff --check` and strict `CI=true ./tool/ci_checks.sh` passed with importer/compare gates, Web build, provenance generation, and verification.
- Rollback point: remove only the verify mode, CI invocations, incremental docs/test lines, and this timeline entry; preserve the existing provenance generator and Web artifact path.
- Storage rule: this log records only the delta and verification evidence; it intentionally does not copy any complete source, test, release, or documentation file.
