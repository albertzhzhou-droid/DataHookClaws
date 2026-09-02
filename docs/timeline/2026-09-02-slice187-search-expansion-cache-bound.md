# Slice187 — Search expansion cache bound

- Date: 2026-09-02
- Scope: bound the in-memory query-expansion cache without changing search or
  enrichment results.
- Canonical edits:
  - `lib/src/domain/search_orchestrator.dart`
    - Validate a positive `maxExpansionCacheEntries` constructor value, default
      it to 32, refresh recency on cache hits, and evict the least-recently-used
      expansion after insertion.
    - Re-expand a query when enrichment finds that its expansion was evicted.
  - `test/domain/search_orchestrator_test.dart`
    - Add a three-query regression proving recent-query reuse and least-recently
      used eviction/re-expansion.
- Behavior contract:
  - The cache cannot grow beyond the configured entry cap.
  - A cache hit becomes most recently used; the oldest untouched query is the
    next eviction candidate.
  - Eviction affects only reuse: enrichment still receives a fresh expansion,
    while source routing and existing failure isolation remain unchanged.
- Validation evidence:
  - Focused orchestrator tests: 11 cases passed.
  - Full `flutter test`: 442 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only the cache cap/recency helpers, focused
  eviction regression, docs references, and this timeline; keep expansion,
  routing, and enrichment semantics.
