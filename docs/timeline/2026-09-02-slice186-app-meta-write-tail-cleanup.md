# Slice186 — App metadata write-tail cleanup

- Date: 2026-09-02
- Scope: bound the in-memory lifecycle of per-key metadata write chains.
- Canonical edits:
  - `lib/src/domain/app_meta_write_queue.dart`
    - Track the settled tail locally and remove it only when identity still
      matches the current key tail; expose a debug-only count for deterministic
      lifecycle assertions.
  - `test/domain/app_meta_write_queue_test.dart`
    - Add success and failure cleanup regressions while retaining an active
      write and existing per-key ordering/error behavior.
- Behavior contract:
  - Completed and failed key tails are released after settlement.
  - A newer enqueue for the same key prevents an older cleanup callback from
    removing the newer chain.
  - Caller-visible write errors and serialization semantics remain unchanged.
- Validation evidence:
  - Focused queue tests: 4 cases passed.
  - Full `flutter test`: 441 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only settled-tail cleanup, debug count accessor,
  focused regressions, docs references, and this timeline; keep ordering and
  error propagation.
