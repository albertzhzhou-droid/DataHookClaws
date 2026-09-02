# Slice142 — Import-log read isolation

- Date: 2026-09-02
- Scope: HomePage refresh, standard search, and advanced-search import-log reads.
- Change: `getImportLogs` is now a safe supplemental read; failures preserve
  the last visible log state while result and count updates continue.
- Tests: `test/widget_test.dart` passed (20 cases), including seeded results
  with a repository that fails only import-log reads.
- Verification: focused widget tests passed (20 cases), full Flutter tests
  passed (`+382`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the safe import-log loader, focused regression, docs
  references, and this timeline entry; preserve result/count reads, prior log
  state, metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
