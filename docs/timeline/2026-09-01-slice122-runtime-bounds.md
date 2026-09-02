# Slice122 — Persistence store runtime bounds

- Date: 2026-09-01
- Scope: `ActivityTraceStore` and `MergeReviewSavedViewStore` constructor limits
- Change: replace debug-only item/payload `assert` checks with runtime
  `ArgumentError` validation, using the existing UTF-8 minimum payload budget.
- Tests: add constructor regressions for zero/negative item limits and below-
  minimum payload budgets; keep the multibyte persistence regressions.
- Verification: combined focused store tests passed (`+27`); full Flutter tests
  passed (`+361`); `flutter analyze` reported zero issues; `git diff --check`
  passed; strict `CI=true ./tool/ci_checks.sh` passed with lockfile, importer,
  compare, Web release build, provenance generation, and provenance verification
  gates.
- Rollback: restore the constructor assertions and remove only the focused
  runtime-bound tests, docs references, and this timeline file; preserve the
  UTF-8 byte accounting and valid-configuration behavior.
