# Slice124 — HomePage app_meta UTF-8 byte budget

- Date: 2026-09-01
- Scope: HomePage app metadata read/write size checks
- Change: add `AppMetaPayloadBudget` and route prompt-config input limits plus
  recent replay/recall and favorite metadata compaction checks through UTF-8
  byte length instead of Dart string length.
- Tests: add an ASCII-versus-multibyte helper regression and rerun the HomePage
  widget suite (7 focused cases total).
- Verification: focused tests passed (7 cases); full Flutter tests passed
  (`+363`); `flutter analyze` reported zero issues; `git diff --check` passed;
  strict `CI=true ./tool/ci_checks.sh` passed with lockfile, importer,
  compare/accessibility, Web release build, provenance generation, and
  provenance verification gates.
- Rollback: remove the helper and restore the prior HomePage character-length
  checks, then remove the focused test, docs references, and this timeline;
  preserve existing metadata keys, compaction, fallback, and interaction
  behavior.
