# Slice 120 — Activity trace UTF-8 byte budget

- Date: 2026-09-01 (America/Toronto)
- Scope: make the existing `activity_trace_v1` persistence cap reflect actual
  UTF-8 storage size for multilingual and emoji-rich records.
- Canonical changes: `ActivityTraceStore` now uses UTF-8 byte length when
  rejecting an oversized stored payload and when fitting appended records to
  `maxValueLength`.
- Behavior boundary: schema, action vocabulary, replay behavior, serialized
  queueing, fail-open decoding, and item-count limits remain unchanged.
- Verification: focused ActivityTraceStore tests passed (`+12`), including a
  multibyte overflow regression; full Flutter tests passed (`+358`);
  `flutter analyze` reported zero issues; `git diff --check` passed; and strict
  `CI=true ./tool/ci_checks.sh` passed with the lockfile, importer, compare,
  Web release build, provenance generation, and provenance verification gates.
- Rollback: restore character-length accounting, remove the focused regression
  and documentation entries, and remove this timeline file.
- Storage rule: this is the sole Slice120 timeline entry; no full-content copy
  or duplicate artifact was created.
