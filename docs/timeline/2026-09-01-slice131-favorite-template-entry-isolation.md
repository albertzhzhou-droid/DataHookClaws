# Slice131 — Favorite template entry isolation

- Date: 2026-09-01
- Scope: HomePage `favorite_templates_v1` persistence decoding.
- Change: replaced the unsafe template-entry cast path with a per-entry
  fail-closed parser. Wrongly typed required/optional fields and malformed
  supplied timestamps are skipped without aborting later valid templates;
  absent legacy timestamps keep the prior compatibility fallback.
- Tests: `test/widget_test.dart` passed (9 cases), including a malformed
  template before a valid template.
- Verification: full Flutter tests passed (`+371`), strict
  `CI=true ./tool/ci_checks.sh` passed under a temporary environment-only
  sqlite system hook, including lockfile, 14 importer tests,
  compare/accessibility gates, Web release build, and provenance
  generate/verify; `flutter analyze --no-pub` reported zero issues and
  `git diff --check` passed. The temporary pubspec hook was removed afterward.
- Rollback: remove the favorite-template entry parser, focused regression,
  docs references, and this timeline entry; preserve metadata keys,
  valid-template behavior, UTF-8 budgets, and the write queue.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
