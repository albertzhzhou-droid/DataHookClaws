# Slice125 — Saved-filter strict root schema

- Date: 2026-09-01
- Scope: `MergeReviewFilter.tryFromJson`
- Change: reject unknown JSON fields while allowing the optional `severity`
  and `type` fields; invalid/future-shaped filters continue to fail closed to
  `All` through the existing `decode` boundary.
- Tests: add the unknown-field case to the strict parser regression and rerun
  the saved-view codec coverage (10 focused cases).
- Verification: focused tests passed (10 cases); full Flutter tests passed
  (`+363`); `flutter analyze` reported zero issues; `git diff --check` passed;
  strict `CI=true ./tool/ci_checks.sh` passed with lockfile, importer,
  compare/accessibility, Web release build, provenance generation, and
  provenance verification gates.
- Rollback: remove only the filter key-set guard and focused invalid-field
  case, docs references, and this timeline file; preserve schema-version,
  enum validation, fail-open decoding, and saved-view behavior.
