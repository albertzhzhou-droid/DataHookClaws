# Slice176 — Model budget runtime bounds

- Date: 2026-09-02
- Scope: release-safe construction of the model-call budget controller.
- Canonical edits:
  - `lib/src/domain/model_budget_controller.dart`
    - Sanitized negative call limits and non-positive timeout, token, and
      failure-cooldown values in the constructor.
    - Preserved `maxCallsPerMinute: 0` as an explicit model-disable switch.
  - `test/domain/model_budget_controller_test.dart`
    - Added invalid runtime budget and zero-call-disable regression coverage.
- Behavior contract:
  - Invalid runtime values cannot create immediate/negative timeouts,
    unusable token limits, or a disabled failure cooldown by accident.
  - Valid budget evaluation, call pruning, failure cooldown, and model fallback
    behavior remain unchanged.
- Validation evidence:
  - Focused model-budget tests: 4 cases passed.
  - Full `flutter test`: 428 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only constructor guards, focused regression, docs
  references, and this timeline; keep existing budget state-machine behavior.
