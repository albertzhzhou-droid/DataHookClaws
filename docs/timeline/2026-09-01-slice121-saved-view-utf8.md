# Slice 121 — Saved review view UTF-8 byte budget

- Date: 2026-09-01 (America/Toronto)
- Scope: make the existing `merge_review_saved_views_v1` persistence cap
  reflect serialized UTF-8 bytes for multilingual saved-view names and filter
  payloads.
- Canonical changes: `MergeReviewSavedViewStore` now uses UTF-8 byte length when
  rejecting an oversized stored payload and when fitting a saved mutation.
- Behavior boundary: schema, name normalization, filter semantics, serialized
  queueing, no-write-on-rejection behavior, and item-count limits remain
  unchanged.
- Verification: focused saved-view store tests passed (`+11`), including
  multibyte load and save overflow cases; full Flutter tests passed (`+359`);
  `flutter analyze` reported zero issues; `git diff --check` passed; and strict
  `CI=true ./tool/ci_checks.sh` passed with the lockfile, importer, compare,
  Web release build, provenance generation, and provenance verification gates.
- Rollback: restore character-length accounting, remove the focused regression
  and documentation entries, and remove this timeline file.
- Storage rule: this is the sole Slice121 timeline entry; no full-content copy
  or duplicate artifact was created.
