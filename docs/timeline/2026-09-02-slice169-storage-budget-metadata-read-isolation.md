# Slice169 — Storage budget metadata read isolation

## Version

- Iteration: Slice169
- Date: 2026-09-02
- Scope: `StorageBudgetManager.snapshot` storage-path and artifact-inventory reads
- Rollback unit: this timeline entry, the focused regressions, documentation
  references, and the independent read boundaries in the canonical budget
  manager

## Changes

- Read storage paths and dataset-artifact inventory independently so a
  transient failure in one supplemental source does not discard the other
  filesystem metrics.
- Preserve a renderable snapshot when either read fails and add an explicit
  `Storage path metadata unavailable` or `Dataset artifact inventory
  unavailable` warning, keeping unknown values distinguishable from ordinary
  zero usage.
- Leave budget thresholds, filesystem sizing, and normal successful-read
  behavior unchanged.
- Added focused regressions for each independent read failure.
- Edited only canonical source/test/docs files; no full-content source copy or
  duplicate release artifact was created.

## Verification

- Focused StorageBudgetManager suite: 4 cases passed.
- Full Flutter suite: `+416 All tests passed!`.
- `flutter analyze`: zero issues.
- `git diff --check`: passed.
- Strict `CI=true ./tool/ci_checks.sh`: passed with the canonical dependency
  file, lockfile gate, 14 importer tests, compare/accessibility checks, Web
  release build, and provenance generate/verify checks.

## Rollback

Remove the independent budget-read boundaries, their focused tests, the
related `AGENT.md`, `docs/PROJECT_PLAN.md`, and `docs/UPGRADE_QUEUE.md` entries,
and this timeline file. Preserve filesystem sizing, budget thresholds, and
explicit unavailable-data warnings if retained by a later implementation.

## Next

Inspect one bounded persistence or release-evidence contract while preserving
the no-duplicate-canonical-content rule.
