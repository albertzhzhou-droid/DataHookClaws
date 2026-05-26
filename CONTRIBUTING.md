# Contributing

Thank you for considering a contribution to DataHookClaws.

## Development Principles

- Preserve provenance. Imported source records must remain traceable to the
  original authority.
- Keep AI suggestion-only. AI output must not write nutrient facts, overwrite
  canonical fields, or make final merge decisions.
- Keep new sources manual-only until source metadata explicitly permits
  automatic routing.
- Treat licensing and source terms as product constraints, not documentation
  afterthoughts.
- Add tests for importer parsing, repository behavior, UI surfaces, and
  governance logic when relevant.

## Local Checks

Run these before opening a pull request:

```bash
flutter analyze
flutter test
flutter test test/domain/source_importers_test.dart test/domain/it_crea_importer_test.dart
flutter build web
```

## Importer Contributions

Importer contributions should include:

- official source URL and license/terms notes
- parser tests with minimal fixtures or mocked HTTP responses
- descriptor/registry wiring
- source capability metadata
- documentation updates in `README.md`, `AGENT.md`, and
  `docs/PROJECT_PLAN.md`

Do not add a source to automatic foreground/background routing until its cost,
license posture, and parser risk are explicitly reviewed.
