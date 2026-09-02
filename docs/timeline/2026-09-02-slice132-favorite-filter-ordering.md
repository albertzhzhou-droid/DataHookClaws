# Slice132 — Favorite filter persistence ordering

- Date: 2026-09-02
- Scope: HomePage `favorite_filters_v1` decoding and startup restoration.
- Change: a wrongly typed persisted `sortMode` now falls back to `recent`
  without aborting valid dimensions. Favorite foods, filters, and templates
  load through one ordered sequence with per-loader error isolation, so filter
  pruning runs after the favorite list is available rather than racing it.
- Tests: `test/widget_test.dart` passed (10 cases), including malformed
  `sortMode` and cross-country filter restoration.
- Verification: full Flutter tests passed (`+372`), strict
  `CI=true ./tool/ci_checks.sh` passed with the canonical dependency file,
  including lockfile, 14 importer tests, compare/accessibility gates, Web
  release build, and provenance generate/verify; `flutter analyze --no-pub`
  reported zero issues and `git diff --check` passed.
- Rollback: remove the safe sort-mode decode, ordered favorite loader,
  focused regression, docs references, and this timeline entry; preserve
  favorite metadata keys, valid filter semantics, UTF-8 budgets, and the write
  queue.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
