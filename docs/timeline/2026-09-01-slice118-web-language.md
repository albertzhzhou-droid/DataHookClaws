# Slice 118 — English Web language contract

- Date: 2026-09-01 (America/Toronto)
- Scope: make the existing Web shell's language explicit and keep generated
  release evidence aligned with the canonical shell.
- Canonical changes: added `<html lang="en">` to `web/index.html`; extended
  `tool/build_release_provenance.dart` with opt-in `--require-web-language`.
- Gate behavior: requires exactly one HTML root tag in canonical and generated
  shells, requires its `lang` attribute to be exactly `en` (case-insensitive
  after trimming), and reports foreign-language, missing-attribute, duplicate
  root, or missing-file failures before hashing/verification completes.
- Wiring: local `tool/ci_checks.sh`, GitHub Actions provenance generation and
  verification, and `docs/release_packaging.md` enable the gate. Focused tests
  cover the valid contract, a foreign-language tamper, and a missing attribute.
- Verification: focused workflow tests passed (`+52`); full Flutter tests
  passed (`+356`); `flutter analyze` reported zero issues; `git diff --check`
  and strict `CI=true ./tool/ci_checks.sh` passed, including release build,
  provenance generation, and verification.
- Rollback: remove only the canonical language attribute, optional checker,
  its CI/local arguments, focused test/docs lines, and this timeline entry;
  preserve the existing shell, deployment, PWA, metadata, and hashing gates.
- Storage rule: this is the sole Slice118 timeline entry; no full-content copy
  or duplicate release artifact was created.
