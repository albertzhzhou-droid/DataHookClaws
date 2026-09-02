# Slice126 — HomePage app_meta per-key write queue

- Date: 2026-09-01
- Scope: serialize HomePage `app_meta` writes by metadata key.
- Change: added the canonical `AppMetaWriteQueue`; all HomePage metadata writes
  now enqueue per key, preserving order for the same key while allowing
  independent keys to progress concurrently. A failed operation is isolated so
  subsequent writes can still run.
- Tests: `flutter test test/domain/app_meta_write_queue_test.dart
  test/widget_test.dart` passed (8 cases).
- Verification: full Flutter tests passed (`+365`), `flutter analyze` reported
  zero issues, `git diff --check` passed, and strict
  `CI=true ./tool/ci_checks.sh` passed including the lockfile gate, 14 source
  importer tests, compare/accessibility gates, Web release build, and
  provenance generation/verification.
- Rollback: remove `AppMetaWriteQueue`, restore the prior direct HomePage
  `setAppMeta` calls, remove its focused regression and documentation references,
  and delete this timeline entry. Preserve metadata keys, UTF-8 byte budgets,
  compaction, fallback, and interaction behavior.
- Storage/version rule: this iteration edits canonical source and tests only;
  it does not create a full-content copy or duplicate release artifact.
