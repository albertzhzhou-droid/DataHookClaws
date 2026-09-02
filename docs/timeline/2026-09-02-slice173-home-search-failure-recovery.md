# Slice173 — Home search failure recovery

- Date: 2026-09-02
- Scope: HomePage submitted-search error boundaries and stale-request ownership.
- Canonical edits:
  - `lib/src/features/home/home_page.dart`
    - Added request-generation checks around standard and advanced searches.
    - Added stable search failure state, recovery card, and `Retry search` action.
    - Preserved the last visible results and invalidated stale work when the
      query is cleared or a newer request starts.
  - `test/widget_test.dart`
    - Added the transient submitted-search failure and retry regression.
- Behavior contract:
  - A search exception settles the UI (`_isLoading == false`) and exposes a
    retryable `Search unavailable` state rather than an unhandled stream error.
  - A successful retry clears the failure card and restores the canonical local
    results path.
  - Older async results and failures cannot overwrite a newer request.
- Validation evidence:
  - Focused `flutter test test/widget_test.dart`: 30 cases passed.
  - Full `flutter test`: 421 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the HomePage generation/error-state changes,
  focused regression, docs references, and this timeline; keep the existing
  initial-results retry, orchestration, enrichment, and result-merge behavior.
