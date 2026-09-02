# Slice129 — Saved-view monotonic timestamps

- Date: 2026-09-01
- Scope: saved-view persistence timestamp and ordering contract.
- Change: `MergeReviewSavedView` now rejects `updatedAt` values earlier than
  `createdAt`. During an existing-view update,
  `MergeReviewSavedViewStore` keeps the prior later `updatedAt` when the clock
  rolls back, while retaining the requested name/filter mutation.
- Tests: saved-view model/store focused suite passed (21 cases), including
  inverse timestamp rejection and rollback ordering.
- Verification: full Flutter tests passed (`+369`), strict
  `CI=true ./tool/ci_checks.sh` passed under a temporary environment-only
  sqlite system hook, including lockfile, 14 importer tests,
  compare/accessibility gates, Web release build, and provenance
  generate/verify; `flutter analyze --no-pub` reported zero issues and
  `git diff --check` passed. The temporary pubspec hook was removed afterward.
- Rollback: remove the timestamp invariant, monotonic update selection,
  focused regressions, docs references, and this timeline entry; preserve
  saved-view schema guards, UTF-8 budgets, serialized writes, and filtering.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
