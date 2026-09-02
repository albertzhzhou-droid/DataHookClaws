# Slice162 — Fetch-job persistence isolation

- Version: 2026-09-02 / Slice162
- Scope: production hardening of foreground and background fetch-job status persistence.
- Changes:
  - Wrapped `ForegroundFetchRunner` job writes in a best-effort boundary so running/success/failure history cannot block source execution or turn a successful source into a false failure.
  - Wrapped `BackgroundEnrichmentQueue` queued/running/success/failure/cancelled writes in the same bounded boundary so persistence outages cannot stop enrichment progress or queue cancellation.
  - Added focused regressions for successful and failed foreground sources and successful background enrichment with a failing job persistor.
- Verification:
  - Focused fetch-runner/queue/orchestrator tests: 8 cases passed.
  - Full Flutter tests: `+407` passed.
  - `flutter analyze`: zero issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed with lockfile, 14 importer, compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the two best-effort helpers, their focused regressions, this timeline entry, and the matching AGENT/plan/queue bullets; preserve importer execution, queue state transitions, and the fetch-job schema.
- Next: inspect one bounded persistence or release-evidence contract without duplicating canonical content.
