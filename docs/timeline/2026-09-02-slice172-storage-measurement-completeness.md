# Slice172 — Storage measurement completeness

- Date: 2026-09-02
- Scope: StorageBudgetManager filesystem measurement
- Change: measurements now carry bytes plus completeness through an injectable
  `StorageBudgetFileSystem` adapter. Invalid database paths and partial
  artifact/export/cache scans remain renderable and emit explicit warnings.
- Regression coverage: deterministic database measurement failure and mixed
  valid/invalid artifact inventory.
- Focused verification: StorageBudgetManager tests passed (6 cases).
- Full verification: Flutter tests passed (`+420`), `flutter analyze` reported
  zero issues, and `git diff --check` passed.
- Strict verification: `CI=true ./tool/ci_checks.sh` passed with the canonical
  dependency file, including lockfile, 14 importer, compare/accessibility, Web
  build, and provenance generate/verify checks.
- Rollback: remove the adapter, completeness metadata/warnings, focused tests,
  docs references, and this timeline; preserve repository-read isolation and
  budget threshold behavior.
- Boundary preserved: empty paths remain known zero; repository failures keep
  their existing independent warning semantics; no source copies are added.
