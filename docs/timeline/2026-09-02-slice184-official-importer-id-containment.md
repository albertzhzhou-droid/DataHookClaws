# Slice184 — Official dataset importer-id containment

- Date: 2026-09-02
- Scope: keep official dataset directories inside the configured root when a
  caller supplies an importer identity.
- Canonical edits:
  - `lib/src/data/official_dataset_grabber.dart`
    - Validate `importerId` as one non-empty path component before resolving
      transport or extraction roots; reject absolute and separator-bearing
      values.
  - `test/domain/official_dataset_grabber_test.dart`
    - Add transport and preparer regressions asserting unsafe IDs fail before
      their root resolvers run.
- Behavior contract:
  - Absolute, `.`/`..`, slash, and backslash importer IDs fail closed before
    filesystem or network work.
  - Existing manifest importer IDs keep their current paths and semantics.
  - Download filename and ZIP entry containment guards remain in force.
- Validation evidence:
  - Focused official-dataset grabber tests: 10 cases passed.
  - Full `flutter test`: 438 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only importer-id validation, focused regressions,
  docs references, and this timeline; keep valid paths and extraction behavior.
