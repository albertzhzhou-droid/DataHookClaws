# Slice136 — Compare prompt-config read isolation

- Date: 2026-09-02
- Scope: HomePage startup loading of `compare_replay_draft_prompt_config_v1`.
- Change: a prompt-config repository read exception now retains the in-memory
  default configuration and does not abort export-recall restoration; valid
  recalls continue to load independently.
- Tests: `test/widget_test.dart` passed (14 cases), including a repository that
  fails only the prompt-config metadata read while a country recall restores.
- Verification: full Flutter tests passed (`+376`), strict
  `CI=true ./tool/ci_checks.sh` passed with the canonical dependency file,
  including lockfile, 14 importer tests, compare/accessibility gates, Web
  release build, and provenance generate/verify; `flutter analyze --no-pub`
  reported zero issues and `git diff --check` passed.
- Rollback: remove the prompt-config read guard, focused regression, docs
  references, and this timeline entry; preserve default config semantics,
  export recall restoration, metadata keys, and write-queue behavior.
- Storage/version rule: canonical source/tests/docs were edited incrementally;
  no full-content copy or duplicate release artifact was created.
