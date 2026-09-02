# Slice135 — Recent-search metadata read isolation

- Date: 2026-09-02
- Scope: HomePage startup restoration of `recent_searches_v1`.
- Change: the repository read is now isolated from the parser. A storage
  exception leaves recent searches unavailable while the shell and independent
  persistence loaders continue startup; malformed JSON behavior is unchanged.
- Tests: `test/widget_test.dart` passed (13 cases), including a repository that
  fails only the recent-search metadata read.
- Verification: full Flutter tests passed (`+375`), strict
  `CI=true ./tool/ci_checks.sh` passed with the canonical dependency file,
  including lockfile, 14 importer tests, compare/accessibility gates, Web
  release build, and provenance generate/verify; `flutter analyze --no-pub`
  reported zero issues and `git diff --check` passed.
- Rollback: remove the recent-search read guard, focused regression, docs
  references, and this timeline entry; preserve recent-search parsing,
  metadata keys, other startup loaders, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
