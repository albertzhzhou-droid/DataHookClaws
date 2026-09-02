# Slice140 — Export-history read isolation

- Date: 2026-09-02
- Scope: HomePage startup export-history fallback loading.
- Change: when both the recent-recall cache and `getExportHistory` are
  unavailable, the optional fallback now returns cleanly and keeps the shell
  healthy with an empty recall list.
- Tests: `test/widget_test.dart` passed (18 cases), including a repository that
  fails only the export-history read.
- Verification: focused widget tests passed (18 cases), full Flutter tests
  passed (`+380`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web release build, and provenance generate/verify
  checks.
- Rollback: remove the export-history read guard, focused regression, docs
  references, and this timeline entry; preserve recall-cache behavior, empty
  recall semantics, metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
