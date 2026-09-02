# Release Packaging Notes

DataHookClaws is not ready for a formal public data-product release until source-license governance is complete. These commands only prepare local or CI artifacts.

The GitHub Actions release-evidence job declares only repository `contents: read`
permission. It can check out source and publish its scoped CI artifact, but it
cannot write repository contents; any future deployment must use a separately
reviewed workflow with an explicit permission grant.
Checkout also disables credential persistence, so the job does not leave a
GitHub token in the workspace after source retrieval.

The workflow also groups runs by workflow and Git ref and cancels an older run
when a newer commit supersedes it. This keeps stale release evidence from
competing with the current ref; it does not delete already uploaded artifacts.
The release-evidence job has a 30-minute timeout so a stalled dependency or
build cannot consume CI capacity indefinitely.
Both GitHub Actions and the local strict-check wrapper run
`flutter pub get --enforce-lockfile`; a release-evidence run therefore fails if
the checked-in `pubspec.lock` no longer satisfies the declared dependencies.

## Web

```bash
flutter build web --release
```

The GitHub Actions workflow uploads the `datahookclaws-web` CI artifact. The
archive contains the `web/` build directory and its sibling
`datahookclaws-web.provenance.json` manifest, including hidden build metadata
such as `.last_build_id`; missing inputs fail the upload, and the CI artifact
is retained for 14 days. GitHub Pages deployment is intentionally not enabled.

## Android

Prerequisites:

- Android Studio or Android SDK command-line tools
- accepted Android SDK licenses
- a signing configuration for release builds

Useful local commands:

```bash
flutter build apk --debug
flutter build apk --release
```

Do not distribute a release APK as a public nutrition data product until each bundled or fetched source has an explicit redistribution posture.

## macOS

Prerequisites:

- Xcode
- macOS desktop support enabled in Flutter
- signing and notarization decisions for distribution outside local development

Useful local command:

```bash
flutter build macos
```

No notarization or public release automation is included in the first production-engineering pass.

## Release Metadata Preflight

The package version in `pubspec.yaml` is the canonical release identity. The
checked-in `pubspec.lock` and native platform handoff placeholders must remain
consistent with it. Run the non-mutating preflight from the canonical checkout
before creating a release artifact:

```bash
dart tool/check_release_metadata.dart \
  --require-clean \
  --canonical-ref codex/public-github-launch \
  --require-release-signing \
  --require-apple-signing \
  --require-production-identifiers
```

The same metadata checks run in local `tool/ci_checks.sh` and GitHub Actions;
the clean-worktree and canonical-ref flags are reserved for an intentional
release cut. The command emits deterministic JSON (no wall-clock or machine
path fields) so its result can be retained with release evidence.

`--require-release-signing` is the production-cut safety gate for Android. The
checked-in development configuration still uses the debug key so local release
runs remain possible; a distributable release must replace it with a managed
release signing configuration before this command is expected to pass.

`--require-apple-signing` applies the same fail-fast boundary to iOS and macOS:
each Release configuration must provide a development team or distribution
identity, and template/development identities are rejected. Apple credentials
and provisioning assets remain external to the repository; configure them in
the signing environment before cutting a distributable Apple artifact.

`--require-production-identifiers` rejects template or unresolved Android
`applicationId` and Apple `PRODUCT_BUNDLE_IDENTIFIER` values. Replace the
checked-in `com.example...` identifiers with the final product identifiers
before treating the release-cut preflight as green.

`--require-apple-signing` applies the same fail-fast boundary to iOS and macOS:
each Release configuration must provide a development team or distribution
identity, and template/development identities are rejected. Apple credentials
and provisioning assets remain external to the repository; configure them in
the signing environment before cutting a distributable Apple artifact.

## Artifact Provenance

After a Web build, generate the manifest outside `build/web` so the manifest
cannot change the hashed file set:

```bash
dart tool/build_release_provenance.dart \
  --input build/web \
  --output build/datahookclaws-web.provenance.json \
  --artifact-name datahookclaws-web \
  --require-web-version \
  --require-web-shell \
  --require-web-shell-references \
  --require-web-root-base-href \
  --require-web-metadata-parity \
  --require-web-pwa-contract \
  --require-web-pwa-identity \
  --require-web-viewport \
  --require-web-language \
  --require-web-title-parity \
  --require-web-manifest-icon-metadata \
  --require-web-theme-color-parity \
  --require-web-service-worker-contract \
  --require-web-manifest \
  --require-web-manifest-assets \
  --revision "$(git rev-parse --verify HEAD)" \
  --require-revision
```

The manifest records sorted relative paths, byte counts, SHA-256 digests, the
package version, and the source revision. GitHub Actions passes `$GITHUB_SHA`,
while the local strict-check wrapper uses `DHC_SOURCE_REVISION` when supplied
or resolves the current `git rev-parse --verify HEAD`. The
`--require-revision` gate fails on an empty value, so release evidence cannot
be produced without a source commit reference. GitHub Actions
uploads this manifest alongside the Web artifact; it contains no copied source
or build contents. The optional version gate also requires Flutter's generated
`version.json` to match the canonical package name, semantic version, and build
number before the manifest is accepted. The optional Web shell gate also
requires `index.html`, `flutter_bootstrap.js`, `main.dart.js`, and
`manifest.json` to be regular files.
The optional shell-reference gate also requires `index.html` to reference the
bootstrap script, manifest, favicon, and Apple touch icon, with each target
resolving to a regular file inside the artifact.
The optional root-base-href gate requires exactly one generated `<base>` tag
with `href="/"`, matching the current root deployment contract and rejecting
an unresolved `$FLUTTER_BASE_HREF` placeholder or a subpath drift.
The optional metadata-parity gate reads the canonical descriptions from
`web/index.html` and `web/manifest.json`, then requires the generated
`index.html` and `manifest.json` to carry the same non-empty value.
The optional PWA-contract gate requires a safe relative `start_url`, a known
`display` mode, and non-empty `background_color`/`theme_color` values.
The optional PWA-identity gate requires canonical and generated manifests to
declare the root installation identity (`id="/"` and `scope="/"`) so browser
installation scope cannot drift from the current root deployment.
The optional viewport gate requires canonical and generated `index.html` to
carry exactly one responsive viewport value,
`width=device-width, initial-scale=1.0`.
The optional language gate requires canonical and generated `index.html` to
carry exactly one root `lang="en"` attribute, preventing browser and
assistive-technology language inference drift.
The optional title-parity gate requires canonical and generated `index.html`
to carry exactly one non-empty `<title>` and keeps the visible browser title
stable across the build transformation.
The optional icon-metadata gate requires each icon to declare positive
`WIDTHxHEIGHT` (or `any`) sizes, a supported image MIME type, and only
`any`, `maskable`, or `monochrome` purpose tokens.
The optional theme-color parity gate requires the canonical and generated
`index.html` theme-color meta value to match `manifest.json` `theme_color`.
The optional service-worker contract requires Flutter's generated
`flutter_bootstrap.js` to carry exactly one safe `serviceWorkerVersion` token
and requires `flutter_service_worker.js` to be a cleanup-only worker: it must
skip waiting, unregister on activation, and avoid CacheStorage and fetch
interception. This keeps the current Flutter deprecation path from retaining
stale application caches; adopting an offline cache requires a separately
reviewed versioned policy.
The optional manifest gate also requires its `name` and `short_name` fields to
match the canonical package name.
The optional manifest-assets gate also requires a non-empty `icons` array; each
`icons[].src` must be a safe relative path that resolves to a regular file
inside the Web artifact. Absolute, traversal, external-URL, and missing icon
references fail before the manifest is accepted.
The checked-in Web shell description is product-facing and is kept free of the
default Flutter template text.

The same command can verify an already generated manifest without rewriting it:

```bash
dart tool/build_release_provenance.dart \
  --input build/web \
  --verify build/datahookclaws-web.provenance.json \
  --artifact-name datahookclaws-web \
  --require-web-version \
  --require-web-shell \
  --require-web-shell-references \
  --require-web-root-base-href \
  --require-web-metadata-parity \
  --require-web-pwa-contract \
  --require-web-pwa-identity \
  --require-web-viewport \
  --require-web-language \
  --require-web-title-parity \
  --require-web-manifest-icon-metadata \
  --require-web-theme-color-parity \
  --require-web-service-worker-contract \
  --require-web-manifest \
  --require-web-manifest-assets \
  --revision "$(git rev-parse --verify HEAD)" \
  --require-revision
```

CI runs this verification immediately before upload and fails on any file,
size, digest, version, or source-revision mismatch.

## Canonical Version Retention

The adopted local release/development ref is `codex/public-github-launch` at
`534ffdf` (2026-08-31, America/Toronto). Before removing an older local release
ref, verify that it is a strict ancestor of the adopted ref and record its name
and commit hash in a unique `docs/timeline/*.md` entry. Keep release notes and
source changes in the existing canonical files; do not create full-content copy
directories for version snapshots.

Remote tracking refs are not deleted by local cleanup. Removing an upstream
branch requires explicit remote authority and a separate release record.
