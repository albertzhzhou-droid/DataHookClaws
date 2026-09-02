# DataHookClaws timeline — Slice89

- Version: `Slice89` (`2026-08-31`, America/Toronto); canonical source remains `codex/public-github-launch` with package version `1.0.0+1`.
- Scope: make release identity reproducible and catch native version propagation drift before an artifact is cut.
- Existing canonical files changed: `tool/ci_checks.sh`, `.github/workflows/flutter-ci.yml`, `test/domain/ci_workflow_test.dart`, `docs/release_packaging.md`, `AGENT.md`, `docs/PROJECT_PLAN.md`, and `docs/upgrade_queue.md`.
- Incremental implementation: the new `tool/check_release_metadata.dart` validates the single top-level SemVer/build number, generated lockfile SDK constraints, and Android/iOS/macOS version handoff tokens. Optional clean-worktree and exact-canonical-ref gates are explicit flags; output is deterministic JSON without timestamps or machine paths.
- Regression coverage: current metadata passes, malformed SemVer fails, and both local/GitHub CI wiring are asserted in the existing CI workflow test.
- Verification: focused `flutter test test/domain/ci_workflow_test.dart` passed (`+25`); `flutter analyze` reported zero issues; full Flutter tests passed (`+329`); `git diff --check` and strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all compare gates, deterministic metadata output, and Web build.
- Rollback point: remove only the preflight script/invocations, incremental docs/test lines, and this timeline entry; leave canonical application and release files intact.
- Storage rule: this log records only the delta and verification state; it intentionally does not copy any complete source, test, release, or documentation file.
