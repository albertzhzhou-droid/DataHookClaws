# Slice 116 — Root PWA identity contract

- Date: 2026-09-01 (America/Toronto)
- Adopted source ref: `codex/public-github-launch`
- Scope: make the browser installation identity and scope explicit for the
  current root-hosted Web artifact without creating a duplicate release copy.

## Changes

- Added canonical `id: "/"` and `scope: "/"` fields to the existing
  `web/manifest.json`.
- Extended `tool/build_release_provenance.dart` with the opt-in
  `--require-web-pwa-identity` gate. It requires both canonical and generated
  manifests to carry the exact root identity values.
- Enabled the gate for local and GitHub provenance generation and verification.
- Added focused positive and generated id/scope tamper regressions, plus
  release docs, plan/queue notes, and rollback guidance in canonical files.

## Verification

- Focused `test/domain/ci_workflow_test.dart`: passed (`+50`).
- Full Flutter test suite: passed (`+354`).
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile,
  importer/compare gates, Web release build, shell/reference/base-href/
  metadata/PWA/identity/icon/theme/service-worker/version/manifest/revision
  provenance checks, and generate → verify ordering.

## Rollback

Remove only the canonical id/scope fields, optional PWA-identity checker, its
local/CI arguments, focused test/docs lines, and this timeline entry. Preserve
the existing Web shell, metadata, PWA startup, base-href, service-worker,
manifest, revision, and hashing gates.
