# Slice127 — Saved-view item strict schema

- Date: 2026-09-01
- Scope: validate the persisted JSON shape of each saved-view item.
- Change: `MergeReviewSavedView.tryFromJson` now requires exactly `id`, `name`,
  `filter`, `createdAt`, and `updatedAt`. An item with an unknown field is
  rejected, while the existing codec continues to skip invalid entries and
  preserve valid entries.
- Tests: `flutter test test/domain/merge_review_saved_view_test.dart
  test/domain/merge_review_saved_view_store_test.dart` passed (19 cases).
- Verification: full Flutter tests passed (`+366`), `flutter analyze` reported
  zero issues, `git diff --check` passed, and strict
  `CI=true ./tool/ci_checks.sh` passed including the lockfile gate, 14 source
  importer tests, compare/accessibility gates, Web release build, and
  provenance generation/verification.
- Rollback: remove the item key-set guard, its focused unknown-field regression,
  documentation references, and this timeline entry. Preserve the exact root
  schema, filter validation, invalid-entry filtering, UTF-8 budgets, and store
  queue behavior.
- Storage/version rule: this iteration edits canonical source and tests only;
  it does not create a full-content copy or duplicate release artifact.
