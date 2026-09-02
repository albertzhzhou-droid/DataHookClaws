# Slice123 — Saved-view strict root schema

- Date: 2026-09-01
- Scope: `MergeReviewSavedViewCodec.decode`
- Change: require the persisted root object to contain exactly
  `schemaVersion` and `views`; unknown root fields fail open before any item
  decoding or store canonicalization.
- Tests: add a valid saved view with an unknown root field and assert an empty
  decoded result; retain all existing schema, invalid-entry, UTF-8, and store
  queue coverage.
- Verification: focused saved-view codec/store tests passed (18 cases); full
  Flutter tests passed (`+362`); `flutter analyze` reported zero issues;
  `git diff --check` passed; strict `CI=true ./tool/ci_checks.sh` passed with
  lockfile, importer, compare/accessibility, Web release build, provenance
  generation, and provenance verification gates.
- Rollback: remove only the exact-root-key guard, focused regression, docs
  references, and this timeline file; preserve schema-version checks, invalid
  entry handling, UTF-8 budgets, and serialized store behavior.
