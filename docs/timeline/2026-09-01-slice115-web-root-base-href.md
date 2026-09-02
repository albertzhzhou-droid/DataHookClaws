# Slice 115 — Web root base-href contract

- Date: 2026-09-01 (America/Toronto)
- Adopted source ref: `codex/public-github-launch`
- Scope: make the current root-hosted Web deployment path explicit in release
  evidence without creating a duplicate artifact or copying canonical content.

## Changes

- Extended `tool/build_release_provenance.dart` with the opt-in
  `--require-web-root-base-href` gate.
- The gate requires generated `index.html` to contain exactly one `<base>` tag
  with `href="/"`; unresolved `$FLUTTER_BASE_HREF`, subpath values, missing
  hrefs, and duplicate base tags fail before hashing or upload.
- Enabled the gate for local and GitHub provenance generation and verification.
- Added focused positive, unresolved-placeholder, and duplicate-base-tag
  regressions, plus wiring/docs/rollback updates in the existing canonical
  files.

## Verification

- Focused `test/domain/ci_workflow_test.dart`: passed (`+49`).
- Full Flutter test suite: passed (`+353`).
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile,
  importer/compare gates, Web release build, shell/reference/base-href/
  metadata/PWA/icon/theme/service-worker/version/manifest/revision provenance
  checks, and generate → verify ordering.

## Rollback

Remove only the optional root-base-href checker, its local/CI arguments,
focused test/docs lines, and this timeline entry. Preserve the existing Web
shell, metadata, PWA, service-worker, manifest, revision, and hashing gates.
