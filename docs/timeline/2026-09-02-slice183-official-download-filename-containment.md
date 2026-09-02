# Slice183 — Official dataset download filename containment

- Date: 2026-09-02
- Scope: prevent caller- or manifest-supplied download filenames from escaping
  the official dataset download directory.
- Canonical edits:
  - `lib/src/data/official_dataset_grabber.dart`
    - Reuse the segment-aware path guard for download targets and reject
      absolute, parent-directory, or directory-only filenames before HTTP use.
  - `test/domain/official_dataset_grabber_test.dart`
    - Add a transport regression proving an escaping filename fails before the
      client is called and cannot create a sibling file.
- Behavior contract:
  - Invalid download filename paths fail closed before network or disk writes.
  - Existing valid manifest filenames resolve to the same `downloads` paths.
  - ZIP extraction containment and download caching semantics remain intact.
- Validation evidence:
  - Focused official-dataset grabber tests: 8 cases passed.
  - Full `flutter test`: 436 cases passed.
  - `flutter analyze`: no issues.
  - `git diff --check`: passed.
  - Strict `CI=true ./tool/ci_checks.sh`: passed, including lockfile, 17
    importer, compare/accessibility, Web build, and provenance generate/verify
    checks.
- Rollback boundary: remove only the download guard, shared-helper wiring,
  focused regression, docs references, and this timeline; keep valid paths.
