# Slice185 — Home refresh generation ownership

- Date: 2026-09-02
- Scope: prevent supplemental HomePage refreshes from committing data after a
  newer search owns the screen.
- Canonical edits:
  - `lib/src/features/home/home_page.dart`
    - Snapshot the active search generation for initial, import, and enrichment
      refreshes; check it before work and after each repository/log/count await.
  - `test/widget_test.dart`
    - Add a blocked salmon enrichment-refresh regression that submits oats and
      verifies the newer oats result survives release of the stale refresh.
- Behavior contract:
  - A refresh may update results, import logs, count, and compare IDs only while
    its captured search generation is current and the page remains mounted.
  - New searches retain ownership even when an older repository read resolves
    later; valid refreshes and existing search semantics remain unchanged.
- Validation evidence:
  - Focused widget regression: passed.
  - Full `flutter test`: 439 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only the generation snapshot/checks, focused race
  regression, docs references, and this timeline; keep existing search,
  import, enrichment, and supplemental reads.
