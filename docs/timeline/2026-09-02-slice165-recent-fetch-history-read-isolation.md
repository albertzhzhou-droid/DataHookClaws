# Slice165 — Recent fetch-history read isolation

- Version: 2026-09-02 / Slice165
- Scope: production hardening of recent failed fetch-job history reads used by
  `SearchOrchestrator` routing.
- Changes:
  - Wrapped recent failure-history reads in a best-effort boundary. A history
    storage outage now supplies an empty failure set rather than blocking local
    search, foreground fetching, or background enrichment.
  - Preserved source routing rules, budget limits, local-search states, and
    enrichment queue semantics; only the optional routing metadata read is
    isolated.
  - Added focused search and enrichment regressions with a repository that
    fails recent fetch-job reads.
- Verification:
  - Focused SearchOrchestrator tests: 9 cases passed.
  - Full Flutter tests: `+411` passed.
  - `flutter analyze`: zero issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed with lockfile, 14 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the best-effort recent-history helper, its focused
  regressions, this timeline entry, and the matching AGENT/plan/queue bullets;
  preserve routing rules, budget limits, local results, and queue behavior.
- Next: inspect one bounded persistence or release-evidence contract without
  duplicating canonical content.
