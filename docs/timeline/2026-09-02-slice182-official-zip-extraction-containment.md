# Slice182 — Official ZIP extraction containment

- Date: 2026-09-02
- Scope: prevent normalized ZIP entries from escaping the configured official
  dataset extraction directory through sibling-prefix path confusion.
- Canonical edits:
  - `lib/src/data/official_dataset_grabber.dart`
    - Compare normalized candidate paths using a relative-path segment guard;
      reject absolute and parent-directory paths before creating output files.
  - `test/domain/official_dataset_grabber_test.dart`
    - Add a traversal-shaped archive entry regression while retaining a safe
      nested file in the same archive.
- Behavior contract:
  - Entries outside the extraction directory, including `../extracted-evil`,
    are skipped without creating files.
  - Valid files and directories continue to extract as before.
  - Download, manifest, sentinel, and dataset-path semantics remain unchanged.
- Validation evidence:
  - Focused official-dataset grabber tests: 7 cases passed.
  - Full `flutter test`: 435 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only the segment-aware containment guard, focused
  regression, docs references, and this timeline; keep valid ZIP extraction.
