# Slice160 — Query expansion persistence isolation

- Date: 2026-09-02
- Scope: Query-expansion model/JSON parsing and suggestion-log persistence
  boundary.
- Change: `QueryExpansionService.expand` now isolates supplemental suggestion
  logging from model execution and parsing. Valid model expansions remain
  usable when logging fails; request and budget fallbacks remain deterministic
  when fallback logging also fails.
- Tests: the existing query-expansion and model-budget suites passed (9 cases),
  adding failing-persistor regressions for valid output, request fallback, and
  budget fallback.
- Verification: focused query-expansion/budget tests passed (9 cases), full
  Flutter tests passed (`+402`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the best-effort query-expansion log boundaries, focused
  regressions, docs references, and this timeline entry; preserve model budget
  accounting, expansion parsing, public persistor behavior, and deterministic
  search fallbacks.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
