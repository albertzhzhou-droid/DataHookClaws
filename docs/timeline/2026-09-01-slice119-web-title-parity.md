# Slice 119 — Web title parity contract

- Date: 2026-09-01 (America/Toronto)
- Scope: keep the browser title stable between the checked-in Web shell and a
  generated release artifact, without copying canonical content.
- Canonical changes: extended `tool/build_release_provenance.dart` with the
  opt-in `--require-web-title-parity` gate; no runtime or artifact format
  changes were introduced.
- Gate behavior: canonical and generated `index.html` must each contain exactly
  one non-empty `<title>`. The trimmed title text must match; missing, empty,
  duplicate, or changed titles fail before provenance generation or
  verification completes.
- Wiring: local `tool/ci_checks.sh`, GitHub Actions provenance generation and
  verification, and `docs/release_packaging.md` enable the gate. Focused tests
  cover valid, changed, duplicate, and empty-title cases.
- Verification: focused workflow tests passed (`+53`); full Flutter tests
  passed (`+357`); `flutter analyze` reported zero issues; `git diff --check`
  passed; and strict `CI=true ./tool/ci_checks.sh` passed with the lockfile
  gate, 14 importer tests, compare gates, Web release build, title parity,
  provenance generation, and provenance verification.
- Rollback: remove only the title-parity checker, its local/CI arguments,
  focused test/docs lines, and this timeline entry; preserve the existing shell,
  language, metadata, PWA, and hashing gates.
- Storage rule: this is the sole Slice119 timeline entry; no full-content copy
  or duplicate release artifact was created.
