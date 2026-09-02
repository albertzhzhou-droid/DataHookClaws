# Slice 117 — Responsive Web viewport contract

- Date: 2026-09-01 (America/Toronto)
- Adopted source ref: `codex/public-github-launch`
- Scope: make the mobile viewport behavior of the existing Web shell explicit
  in release evidence without creating a duplicate artifact or content copy.

## Changes

- Added the canonical viewport meta tag to `web/index.html`:
  `width=device-width, initial-scale=1.0`.
- Extended `tool/build_release_provenance.dart` with the opt-in
  `--require-web-viewport` gate. It requires exactly one matching viewport
  value in canonical and generated `index.html`.
- Enabled the gate for local and GitHub provenance generation and verification.
- Added focused positive, mismatched-value, and duplicate-meta regressions,
  plus canonical release docs, plan/queue notes, and rollback guidance.

## Verification

- Focused `test/domain/ci_workflow_test.dart`: passed (`+51`).
- Full Flutter test suite: passed (`+355`).
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile,
  importer/compare gates, Web release build, shell/reference/base-href/
  metadata/PWA/identity/viewport/icon/theme/service-worker/version/manifest/
  revision provenance checks, and generate → verify ordering.

## Rollback

Remove only the viewport source tag, optional viewport checker, its local/CI
arguments, focused test/docs lines, and this timeline entry. Preserve the
existing Web shell, deployment-path, PWA, identity, and hashing gates.
