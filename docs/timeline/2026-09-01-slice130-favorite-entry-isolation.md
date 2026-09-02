# Slice130 — Favorite persistence entry isolation

- Date: 2026-09-01
- Scope: HomePage `favorite_foods_v1` persistence decoding.
- Change: added a per-entry `_FavoriteFoodRef.fromJson` boundary that rejects
  wrong types and empty required fields without aborting the list. Valid
  entries survive malformed neighbors, and duplicate `foodId` values keep the
  first valid snapshot deterministically.
- Tests: `test/widget_test.dart` passed (8 cases), including malformed,
  duplicate, and valid persisted favorites.
- Verification: full Flutter tests passed (`+370`), strict
  `CI=true ./tool/ci_checks.sh` passed under a temporary environment-only
  sqlite system hook, including lockfile, 14 importer tests,
  compare/accessibility gates, Web release build, and provenance
  generate/verify; `flutter analyze --no-pub` reported zero issues and
  `git diff --check` passed. The temporary pubspec hook was removed afterward.
- Rollback: remove the entry parser/deduplication, focused regression, docs
  references, and this timeline entry; preserve favorite metadata keys,
  UTF-8 budgets, write queue, and valid-data UI behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
