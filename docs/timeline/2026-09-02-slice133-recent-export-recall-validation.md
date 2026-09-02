# Slice133 — Recent export recall scope validation

- Date: 2026-09-02
- Scope: HomePage `recent_export_recalls_v1` scope decoding and replay-chip restoration.
- Change: scope labels are trimmed before decoding. Search and favorites
  `all-local-foods` markers retain their existing empty-value compatibility;
  empty or reserved country/favorites/compare values, including malformed
  compare separators, are rejected instead of becoming misleading recall chips.
- Tests: `test/widget_test.dart` passed (11 cases), including malformed scopes
  before valid country, search, favorites, and compare recalls.
- Verification: full Flutter tests passed (`+373`), strict
  `CI=true ./tool/ci_checks.sh` passed with the canonical dependency file,
  including lockfile, 14 importer tests, compare/accessibility gates, Web
  release build, and provenance generate/verify; `flutter analyze --no-pub`
  reported zero issues and `git diff --check` passed.
- Rollback: remove the scope normalization/validation, focused regression, docs
  references, and this timeline entry; preserve valid export recall replay,
  metadata keys, UTF-8 budgets, and the per-key write queue.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
