# Slice159 — AI suggestion persistence isolation

- Date: 2026-09-02
- Scope: Shared AI-assist model-result and suggestion-log persistence boundary.
- Change: `AiAssistServiceBase.runSuggestion` now isolates supplemental log
  writes from model execution. Successful model output is returned even when
  its log write fails; model and budget fallbacks remain deterministic when
  fallback logging also fails.
- Tests: the existing settings/AI suite passed (9 cases), including regressions
  for successful routing output and deterministic routing fallback with a
  failing suggestion persistor.
- Verification: focused settings/AI tests passed (9 cases), full Flutter tests
  passed (`+399`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the best-effort AI log helpers, focused regressions, docs
  references, and this timeline entry; preserve model budget accounting,
  public persistence methods, deterministic caller fallbacks, and routing or
  export behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
