# Slice 114 — Web service-worker cleanup contract

- Date: 2026-09-01 (America/Toronto)
- Adopted source ref: `codex/public-github-launch`
- Scope: make the generated Flutter Web service-worker/version behavior an
  explicit release-evidence contract without adding a second artifact or
  copying canonical project content.

## Changes

- Extended `tool/build_release_provenance.dart` with the opt-in
  `--require-web-service-worker-contract` gate.
- The gate requires one safe, non-empty `serviceWorkerVersion` in generated
  `flutter_bootstrap.js`, plus regular-file `flutter_service_worker.js` with
  explicit install/activate lifecycle, `self.skipWaiting()`, and
  `self.registration.unregister()` behavior.
- The gate rejects CacheStorage access and fetch interception, preserving the
  current cleanup-only Flutter deprecation-worker policy until a separately
  reviewed versioned offline-cache design is adopted.
- Enabled the same gate for local and GitHub provenance generation and
  verification; added focused positive, stale-worker, and unsafe-version
  regressions.
- Updated `docs/release_packaging.md`, `AGENT.md`, `docs/PROJECT_PLAN.md`, and
  `docs/upgrade_queue.md` with the contract and rollback boundary.

## Verification

- Focused `test/domain/ci_workflow_test.dart`: passed (`+48`).
- Full Flutter test suite: passed (`+352`).
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile,
  importer/compare gates, Web release build, shell/metadata/PWA/icon/theme/
  service-worker/version/manifest/revision provenance checks, and generate →
  verify ordering.

## Rollback

Remove only the optional service-worker checker, its local/CI arguments,
focused test/docs lines, and this timeline entry. Preserve the existing Web
shell, metadata, PWA, manifest, revision, and artifact-hashing gates.
