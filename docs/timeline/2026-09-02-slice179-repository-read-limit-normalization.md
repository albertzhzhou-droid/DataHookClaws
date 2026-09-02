# Slice179 — Repository read limit normalization

- Date: 2026-09-02
- Scope: make public repository page sizes safe across memory and SQLite
  implementations.
- Canonical edits:
  - `lib/src/data/repository_read_limits.dart`
    - Added a shared normalizer that maps negative read limits to `0` while
      preserving the meaning of an explicit zero page.
  - `lib/src/data/memory_food_repository.dart`
    - Applied the normalized limit to advanced search, summaries, country
      slices, MergeReview, and diagnostic/history reads.
    - Made zero-limit advanced search return before matching any item.
  - `lib/src/data/sqlite_food_repository.dart`
    - Applied the normalized limit to the same public reads before in-memory
      slicing or SQLite `LIMIT` parameters.
  - `test/domain/advanced_search_and_review_test.dart`
    - Added Memory negative-limit coverage.
  - `test/domain/sqlite_repository_migration_test.dart`
    - Added SQLite negative-limit coverage for search and fetch history.
- Behavior contract:
  - Negative read limits return empty pages and never reach unsafe slicing,
    early-exit, or database limit semantics.
  - Zero remains an explicit empty-page request.
  - Positive limits, ordering, filtering, and persistence behavior remain
    unchanged.
- Validation evidence:
  - Focused repository tests: 10 cases passed.
  - Full `flutter test`: 432 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the helper, call-site guards, focused tests,
  docs references, and this timeline; keep valid read-limit behavior.
