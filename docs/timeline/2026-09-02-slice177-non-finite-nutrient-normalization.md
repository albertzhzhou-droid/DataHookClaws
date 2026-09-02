# Slice177 — Non-finite nutrient normalization

- Date: 2026-09-02
- Scope: reject non-finite nutrient amounts at the canonical normalization
  boundary.
- Canonical edits:
  - `lib/src/domain/normalization/food_record_normalizer.dart`
    - Drop raw `NaN`/infinite amounts before alias lookup and unit conversion.
    - Drop any conversion result that is null or non-finite before constructing
      a canonical `Nutrient`.
  - `test/domain/normalization_toolkit_test.dart`
    - Added regression coverage for a non-finite raw amount, a conversion
      overflow, and a valid neighboring nutrient.
- Behavior contract:
  - Non-finite values cannot enter canonical food models, persistence, or
    exports through the normalizer.
  - A malformed nutrient does not discard valid nutrients from the same record.
  - Alias mapping, unit conversion, and valid finite amounts remain unchanged.
- Validation evidence:
  - Focused normalization-toolkit tests: 6 cases passed.
  - Full `flutter test`: 429 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17 importer,
    compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback boundary: remove only the finite guards, focused regression, docs
  references, and this timeline; keep existing canonical nutrient behavior for
  valid inputs.
