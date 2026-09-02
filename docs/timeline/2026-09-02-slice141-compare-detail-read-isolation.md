# Slice141 — Compare-detail read isolation

- Date: 2026-09-02
- Scope: HomePage compare replay detail hydration.
- Change: `getFoodDetails` failures are isolated per compare ID; later IDs
  continue to hydrate and the replay reports truthful partial restoration.
- Tests: `test/widget_test.dart` passed (19 cases), including a repository where
  the first compare detail read fails while the second detail remains available.
- Verification: focused widget tests passed (19 cases), full Flutter tests
  passed (`+381`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the per-ID detail read guard, focused regression, docs
  references, and this timeline entry; preserve partial-restoration status
  semantics, compare IDs, metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
