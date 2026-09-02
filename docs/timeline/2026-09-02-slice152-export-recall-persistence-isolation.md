# Slice152 — Export-recall persistence isolation

- Date: 2026-09-02
- Scope: HomePage recent export recall list persistence.
- Change: `recent_export_recalls_v1` writes now use a best-effort boundary;
  clearing or mutating the live export-recall list remains responsive when the
  supplemental metadata write fails.
- Tests: `test/widget_test.dart` passed (30 cases), including a seeded search
  recall with a repository that fails only export-recall writes.
- Verification: focused widget tests passed (30 cases), full Flutter tests
  passed (`+392`), `flutter analyze --no-pub` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the export-recall persistence boundary, focused regression,
  docs references, and this timeline entry; preserve the live recall list,
  metadata keys, and other write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
