# Release Packaging Notes

DataHookClaws is not ready for a formal public data-product release until source-license governance is complete. These commands only prepare local or CI artifacts.

## Web

```bash
flutter build web
```

The GitHub Actions workflow uploads `build/web` as a CI artifact. GitHub Pages deployment is intentionally not enabled.

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
