# DataHookClaws Agent Operating Context

## Mandatory Read Order For Every Future Agent Run

1. Read `/Users/zhouzhenghang/Desktop/DataHookClaws/AGENT.md`
2. Read `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/PROJECT_PLAN.md`
3. If architecture detail is needed, read `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/production_architecture_spec.md`

## Mandatory Update Rule

After every agent run that changes code, tests, architecture, importer coverage, or roadmap status:

1. Update this `AGENT.md`
2. Update `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/PROJECT_PLAN.md` if plan status or sequencing changed
3. Record what was completed, what remains, and what verification was run

This rule is part of the project workflow and should be treated as required project maintenance.

## Project Definition

DataHookClaws is a Flutter/Dart app for building a local-first nutrition database from official national food composition sources. The working target is:

`an immediately usable, locally searchable, progressively enriched, provenance-first official nutrition database client`

The app is not intended to ship with a full world database preloaded. It is intended to:

- search local data first
- fetch official source data on demand
- continue background enrichment while the user is browsing
- archive normalized results into a reusable local database
- preserve provenance and exportability

## Current Operating Principles

- Local database is the primary user-facing data layer.
- Official source records are the source of truth.
- AI is assistive only. It may expand queries or suggest routing, but it must not invent nutrient facts.
- Canonical merge must be deterministic first. Do not replace it with AI merge without an explicit new phase.
- Legacy `foods` remains as the fast search snapshot model.
- Provenance tables remain the detailed source-tracking model.

## What Has Been Implemented So Far

### Foundation And Early Import Pipeline

- Created the Flutter app foundation and initial search/import workflow.
- Defined the project flow around:
  - source ingestion
  - normalization
  - persistence
  - search
  - UI presentation
- Established importer abstractions so each official source can be integrated separately.

### Persistence And Local Data Layer

- Replaced the original in-memory-only demo behavior with SQLite persistence.
- Added and stabilized a repository layer with both memory and SQLite implementations.
- Preserved legacy fast-read tables:
  - `foods`
  - `food_tags`
  - `nutrients`
  - `import_logs`
- Added provenance-oriented tables:
  - `canonical_food`
  - `source_record`
  - `nutrient_observation`
  - `food_alias`
  - `dataset_artifact`
  - `fetch_job`
  - `ai_suggestion_log`

### Import Logs And Operational Traceability

- Added import log storage and retrieval.
- Added import history UI on the home page.
- Made importer execution traceable by source, query, status, count, and timestamp.

### Official Importers Implemented

- USDA FoodData Central importer
- Canada CNF CSV importer
- UK CoFID Excel importer
- Japan MEXT 2023 Excel importer
- Switzerland Excel importer
- France CIQUAL 2025 Excel importer
- Denmark Frida spreadsheet importer
- Australia AFCD multi-file Excel importer
- Germany BLS 4.0 Excel importer
- Italy CREA web portal importer

### Official Dataset Grabber Layer

- Added official dataset grabber infrastructure so importers can consume local prepared files while download logic stays separate.
- Implemented manifest-driven preparation for:
  - direct file downloads
  - zip packages
  - pre-expanded directories
- Current auto-prepared sources:
  - UK CoFID
  - Japan MEXT 2023
  - Canada CNF
- Switzerland
- France CIQUAL 2025
- Australia AFCD
- Current grabber-ready but importer-pending sources:
  - New Zealand FOODfiles, currently blocked by source terms

### National Source Catalog

- Refactored source governance into a national layered catalog.
- Sources are now organized by country/administrative entity instead of a flat list.
- Catalog distinguishes implemented sources from cataloged sources.
- National source catalog currently includes:
  - United States
  - Canada
  - United Kingdom
  - Japan
  - Australia
  - New Zealand
  - France
  - Finland
  - Denmark
  - Germany
  - Switzerland
  - Spain
  - Italy

### Importer Registry And Scaffold Layer

- Added a descriptor-driven importer registry so importer wiring and home-page source controls no longer rely on hardcoded per-country branches.
- Added a local importer expansion queue:
  - `tool/importer_expansion_queue.json`
- Added template-driven importer scaffold support:
  - `tool/importer_templates/`
  - `tool/scaffold_importer.dart`
- Added reusable scaffold logic in:
  - `lib/src/tooling/importer_scaffold.dart`
- This scaffold layer is intended to support temporary Codex automation that advances importer work one country at a time.

### Normalization Toolkit

- Built a reusable normalization pipeline instead of ad hoc importer-specific mapping.
- Split the normalization logic into modular subparts, including:
  - nutrient dictionary
  - category mapper
  - unit converter
  - label cleaning
  - alias key normalization
  - text normalization helpers
- Added tests for:
  - alias key normalization
  - unit conversion
  - label cleaning

### API And Search Layer

- Added API-facing DTOs and a service layer for search and details.
- Added reusable search indexing support.
- Added summary DTO and detail DTO separation.
- Preserved lightweight list behavior while enabling provenance-first detail reads.

### Query Expansion And Local AI Entry

- Added Ollama client integration targeting local `http://127.0.0.1:11434`
- Added `QueryExpansionService`
- AI is currently restricted to query expansion and source-hint assistance
- AI output is logged to `ai_suggestion_log`
- AI failure degrades silently to non-AI behavior

### Phase 0-1: Controlled Search Bus

- Added `SearchOrchestrator` as the main search entrypoint.
- Search now follows:
  - local query first
  - foreground fetch if budget rules allow
  - archive new results into the local database
- Added `FetchBudgetPlanner`
- Added `ForegroundFetchRunner`
- Search state now exposes:
  - `idle`
  - `local`
  - `fetching`
  - `archived`
  - `failed`
- Home page search was moved away from direct repository-only behavior into orchestrated search.

### Phase 2.5: Background Enrichment Queue

- Added session-local `BackgroundEnrichmentQueue`
- Added dwell-triggered enrichment after archived search results
- Added queue behaviors:
  - single concurrency
  - same-query deduplication
  - queued cancellation
  - graceful stop after current source when a new query supersedes an old one
- Background enrichment writes `fetch_job` records
- Results auto-refresh after successful enrichment writes
- Added lightweight background enrichment UI state card

### Phase 3: Provenance-First Read Chain

- Added provenance-first repository read interfaces:
  - `searchFoodSummaries`
  - `getFoodDetails`
- Added dedicated read models:
  - `FoodSummary`
  - `FoodDetails`
  - `SourceRecordView`
  - `NutrientObservationView`
- Added provenance detail DTOs
- Added clickable food cards and bottom-sheet detail presentation
- Detail panel now shows:
  - overview
  - aggregated nutrients
  - official sources
  - aliases

### Phase 4: Deterministic Canonical Merge

- Added `CanonicalMergeService`
- Canonical merge is currently deterministic and rule-based.
- Merge inputs are based on:
  - alias-normalized name
  - normalized category
  - normalized serving basis
- Nutrient similarity is used only as a secondary confirmation signal.
- Repository write paths now merge imported source records under shared canonical foods when rules match.
- `foods` now acts as a canonical snapshot table, not a per-source row table.
- Multi-source canonical snapshots now:
  - collapse duplicate search results
  - preserve multiple `source_record` entries
  - preserve `nutrient_observation` provenance
  - expand `food_alias`
- SQLite now has a lightweight canonical merge state marker and rebuild path for old source-as-canonical layouts.

### Phase 5: Merge Audit Surface And Explainability

- Extended deterministic merge so every merge decision now produces a full audit envelope, not just a final action.
- Added candidate-level evaluation output covering:
  - alias match
  - category match
  - serving match
  - nutrient similarity
  - accepted/rejected state
  - explicit reason
- Added persistent merge audit storage in SQLite:
  - `merge_audit`
  - `merge_audit_candidate`
- Added merge audit rebuild on open for existing databases that predate Phase 5.
- Extended provenance details so each `source_record` now carries source-level merge audit data.
- Extended API detail DTOs to expose merge audit fields.
- Extended `FoodDetailSheet` so each official source card now shows:
  - merge decision
  - matchedBy
  - confidence
  - reason
  - candidate review
- Added a canonical summary message in the detail sheet showing how many official source records are merged into the canonical entry.

### Phase L: More Official Sources

- Added `SwissFoodCompositionExcelImporter`
- Added `FranceCiqualExcelImporter`
- Added `DenmarkFridaExcelImporter`
- Added `AustraliaAfcdImporter`
- Kept both sources out of `FetchBudgetPlanner` foreground/background priorities for now so importer expansion does not silently increase search-time cost
- Refactored `HomePage` source controls to render from importer descriptors instead of four hardcoded importer cards
- Added importer parser and sync-flow tests for Switzerland, France, Denmark, and Australia
- Added scaffold tests for the importer queue/template layer
- Reviewed New Zealand FOODfiles Terms of Use and marked the NZ importer as blocked for the current architecture because the data must be presented in original and unaltered form
- Integrated Germany BLS 4.0 importer and Italy CREA web portal importer from the recent automation work
- Germany BLS reads the official workbook layout from a user-provided `.xlsx` path
- Italy CREA imports live search/detail records from the official AlimentiNUTrizione portal
- Added and verified Germany/Italy importer parser and sync-flow tests
- Marked Finland Fineli as blocked because the official open-data URL currently redirects to THL maintenance, preventing verification of the CSV package and current license path
- Advanced the actionable importer queue beyond CH/AU/FR/DK/DE/IT; remaining queued sources are blocked pending source-shape or license/product decisions

### Phase K: Export Layer

- Added a local file export service:
  - `FoodCatalogExportService`
- Added export models:
  - `ExportFormat`
  - `ExportDetailLevel`
  - `ExportArtifact`
- Implemented export targets:
  - search summary JSON
  - search detailed JSON
  - search summary CSV
  - search detailed CSV
  - SQLite snapshot copy
- Added country-slice export capability in the service layer.
- Added repository support for:
  - `searchFoodSummariesByCountry`
  - `copyDatabaseSnapshot`
- SQLite snapshot export now copies the active database file as-is, preserving provenance, merge audit, logs, and artifacts.
- Added a minimal export UI section on the home page.
- Export results now surface file path and record count in the UI.
- Export files are written into the app document directory under `exports/`.

### Phase M/P: Budget Governance And Operations Surface

- Added source capability governance:
  - `SourceCapabilityRegistry`
  - `SourceRoutingService`
- Automatic search-time routing is now constrained by source capability metadata instead of only hardcoded planner order.
- First automatic route remains limited to:
  - `usda`
  - `canada-cnf`
  - `uk-mccance`
  - `jp-standard`
- Switzerland, Australia, France, Denmark, Germany, Italy, Spain, and Finland remain outside automatic foreground/background routing unless a later phase explicitly enables them.
- New Zealand FOODfiles is now surfaced as `Blocked` rather than merely cataloged.
- Spain BEDCA is now surfaced as `Blocked` because the queued `single_excel` shape does not match the official public web/database access path and BEDCA reuse conditions require attribution plus preservation of original meaning.
- Finland Fineli is now surfaced as `Blocked` because the official open-data URL currently redirects to THL maintenance, so the CSV package and current license path cannot be verified.
- Added `StorageBudgetManager` with first-pass default budgets:
  - database: `512MB`
  - dataset artifacts: `2GB`
  - exports: `1GB`
  - cache/prepared downloads: `512MB`
- Added `ModelBudgetController` for Ollama query expansion:
  - maximum `6` calls per minute
  - `3s` timeout policy
  - `256` max predicted tokens
  - cooldown after model failures
  - fallback logging when the model is unavailable or budget-denied
- Extended repository operations support:
  - fetch job filtering by importer/status/phase/query
  - dataset artifact listing
  - artifact soft removal
  - storage path discovery
- Added an independent Operations page with:
  - fetch job inspection and retry for eligible automatic sources
  - dataset artifact inspection, soft removal, and re-prepare action
  - importer diagnostics
  - storage and model budget status
- Artifact removal is intentionally soft-delete only. Local files are not deleted.

### Phase O/P2: Data Quality Review And Observation-Level Search

- Added read-only data quality review support:
  - `MergeReviewIssue`
  - `MergeReviewIssueType`
  - `MergeReviewSeverity`
  - repository `getMergeReviewIssues`
- Operations page now includes `Data quality review` for:
  - low-confidence canonical reuse
  - category-conflict candidates
  - created canonical records that had rejected candidates
  - multi-source nutrient variance
- Added advanced local search models:
  - `FoodSearchQuery`
  - `FoodSearchFilters`-style fields through query lists
  - `NutrientRangeFilter`
  - nutrient presets for protein, sodium, energy, fat, carbohydrate, and fiber
- Added repository advanced search interfaces:
  - `searchFoodsAdvanced`
  - `searchFoodSummariesAdvanced`
- Advanced search is local-only and does not trigger foreground fetch or background enrichment.
- Home page now has an `Advanced filters` panel for:
  - country
  - source/importer id
  - category
  - nutrient preset
  - min/max nutrient range
- Detail DTOs and `FoodDetailSheet` now expose `Nutrient source comparison` with:
  - aggregated snapshot value
  - per-source observation values
  - source name and country
  - variance status
- Alias and multilingual-friendly matching is strengthened by reusing normalization toolkit alias keys across advanced local search.

### Phase Q: Manual Data Governance Writeback

- Added controlled manual governance writeback for review issues.
- Added repository interfaces for:
  - manual source-record merge into an existing canonical food
  - manual source-record split into a new canonical food
  - manual canonical field override
  - manual governance log reads
- Added SQLite persistence for manual governance:
  - `manual_governance_log`
  - `manual_canonical_override`
- Manual merge/split actions update provenance ownership, refresh canonical snapshots, and write source-level merge audit entries with `matched_by='manual-governance'`.
- Manual canonical overrides are reapplied during snapshot refresh so later imports do not immediately erase curated display/category/country/description/serving fields.
- Operations `Data quality review` issue cards now expose manual actions:
  - merge suggested candidate
  - split source record
  - override canonical fields
  - open detail sheet
- Operations now includes a `Manual governance log` section for recent human actions.
- Memory and SQLite repositories both implement the writeback surface for tests and runtime parity.

### Phase N/R: AI Cautious Expansion And Production Engineering

- Added Settings persistence through SQLite `app_meta`:
  - `AppSettings`
  - `SettingsService`
  - configurable Ollama endpoint/model
  - configurable model call budget, timeout, and max tokens
  - configurable storage budgets
  - configurable export directory
  - source enabled/disabled map with blocked sources forced disabled
- Added a Settings page accessible from Home and Operations.
- `main.dart` now constructs Ollama, model budget, storage budget, export service, and automatic source routing from persisted settings.
- Added cautious AI suggestion services:
  - `SourceRoutingSuggestionService`
  - `MergeCandidateExplanationService`
  - `ExportSummaryService`
- AI suggestions remain non-authoritative:
  - no AI nutrient facts
  - no AI canonical-field overwrite
  - no AI merge decisions
  - all AI outputs continue to be logged in `ai_suggestion_log`
- Added persistent export history:
  - `export_history`
  - JSON/CSV/SQLite snapshot exports record path, format, detail level, record count, scope, status, and summary
- Added `share_plus`-backed export file sharing through `ExportShareService`.
- Home export card now exposes the latest export and Share action.
- Operations page now includes an Export history section.
- Added GitHub Actions CI:
  - `flutter analyze`
  - `flutter test`
  - targeted source importer tests
  - `flutter build web`
  - Web build artifact upload
- Added release packaging notes in `docs/release_packaging.md`.

### Public Repository Preparation

- Rewrote the public `README.md` in English for GitHub publication.
- Added repository governance and legal boundary files:
  - `LICENSE`
  - `NOTICE`
  - `CONTRIBUTING.md`
  - `SECURITY.md`
  - `CODE_OF_CONDUCT.md`
- The repository license covers project source code only. Official nutrition datasets, downloaded artifacts, trademarks, and source database rights remain governed by their respective official source terms.

## Current User-Facing Capabilities

- Local nutrition search
- Foreground official-source fetch on search
- Session-local background enrichment while browsing results
- Import history viewing
- Provenance detail bottom sheet
- Canonical search result deduplication across sources already merged
- Local persistence of imported data
- Merge audit explanation for each source record in detail view
- Operations data quality review
- Manual merge/split/override writeback from review issues
- Manual governance action log
- Advanced local filters and nutrient range search
- Nutrient source comparison in details
- Local JSON / CSV export
- Local SQLite snapshot export
- Settings page for model, storage, export, and source controls
- Export history and system share entry
- GitHub CI and Web artifact build workflow
- English public repository documentation and code-license boundary files

## Current Known Boundaries

- Canonical merge is deterministic by default. Manual merge/split/override writeback now exists, but AI still cannot make merge decisions.
- Background enrichment is session-local only. It does not survive app restart.
- Remote upload exports are not implemented.
- New Zealand is grabber-ready but blocked by source terms.
- Spain is blocked pending web/API and license review, and Finland is blocked while the official Fineli open-data path is under maintenance.
- Operations page is inspection-first. It does not include destructive cleanup.
- Manual governance is first-pass writeback only. It does not yet include undo/redo, batch approval, role-based authorization, or a dedicated conflict resolution workspace.
- Advanced nutrient filtering is local-only and does not trigger proactive source fetching.
- Settings changes that affect already-constructed runtime services are applied on next app start in the first implementation.

## Verification Status At Last Update

The latest completed verification after Phase 4 was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase 5 was:

- `flutter test` passed
- `flutter analyze` passed

The latest completed verification after Phase K was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase L France expansion was:

- `flutter analyze` passed
- `flutter test test/domain/source_importers_test.dart` passed
- `flutter test test/domain/official_dataset_grabber_test.dart` passed

The latest completed verification after Phase L Denmark expansion was:

- `flutter analyze` passed
- `flutter test test/domain/source_importers_test.dart` passed
- `flutter test` passed

The latest completed verification after Phase M/P budget and operations work was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase O/P2 data quality and observation search work was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase N/R AI cautious expansion and production engineering work was:

- `flutter analyze` passed
- `flutter test` passed
- `flutter test test/domain/source_importers_test.dart` passed
- `flutter build web` passed

The latest completed verification after Phase Q manual data governance writeback was:

- `flutter analyze` passed
- `flutter test test/domain/manual_governance_test.dart test/operations_page_test.dart` passed
- `flutter test` passed
- `flutter build web` passed

The latest completed repository publication preparation was:

- English `README.md` rewrite completed
- `LICENSE`, `NOTICE`, `CONTRIBUTING.md`, `SECURITY.md`, and `CODE_OF_CONDUCT.md` added
- pending final publish-time validation and GitHub push

## Next Recommended Focus

The next technically coherent phase is:

- manual governance hardening

After that:

- governance undo/history detail and safer confirmation flows
- batch review queues and saved review filters
- AI-assisted but non-authoritative review explanations

## Files That Matter Most Right Now

- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/search_orchestrator.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/background_enrichment_queue.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/canonical_merge_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/source_capability_registry.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/source_routing_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/storage_budget_manager.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/model_budget_controller.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/settings_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/ai_assist_services.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/food_quality_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/data/sqlite_food_repository.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/data/memory_food_repository.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/models/manual_governance.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/features/home/home_page.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/features/operations/operations_page.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/features/settings/settings_page.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/PROJECT_PLAN.md`

## Update Log

### 2026-05-23

- Consolidated project history into `AGENT.md`
- Established mandatory future workflow:
  - always read `AGENT.md`
  - always read `docs/PROJECT_PLAN.md`
  - always update `AGENT.md` after meaningful agent work
- Implemented Phase 5 merge audit surface:
  - persistent merge audit tables
  - merge audit rebuild for existing DBs
  - detail/API merge explainability
  - Phase 5 tests and verification
- Implemented Phase K export layer:
  - local JSON / CSV exports
  - SQLite snapshot export
  - home-page export UI
  - export service and repository coverage
  - Phase K tests and verification

### 2026-05-24

- Implemented France CIQUAL 2025 importer
- Added direct CIQUAL workbook auto-grab wiring
- Fixed Excel numeric parsing so decimal-comma and `traces` / `< 0,2` values normalize correctly
- Added France importer parser and sync-flow tests
- Marked France as integrated and advanced the queue target to Denmark
- Implemented Denmark Frida importer
- Kept Denmark auto-download disabled because official dataset links are sent via the Frida form
- Added Denmark importer parser and sync-flow tests
- Marked Denmark as integrated and advanced the queue target to Germany
- Integrated Germany BLS 4.0 importer wiring and parser from the automation work
- Integrated the Italy CREA importer against the official AlimentiNUTrizione HTML search/detail portal
- Removed Germany scaffold placeholder leftovers after real source importer coverage was added to `source_importers_test.dart`
- Fixed Italy importer mocked response encoding so UTF-8 nutrient labels and units are testable
- Marked Germany and Italy queue items completed
- Implemented Phase M/P budget governance and operations surface
- Added source capability routing, storage/model budget controls, Operations page, artifact soft removal, and job retry support
- Marked New Zealand as explicitly blocked in source status and operations diagnostics
- Verified with `flutter analyze` and `flutter test`
- Implemented Phase O/P2 data quality review and observation-level search
- Added advanced local filters, nutrient range search, review issue derivation, and detail nutrient source comparison
- Verified with `flutter analyze` and `flutter test`
- Implemented Phase N/R AI cautious expansion and production engineering
- Added Settings persistence/page, source enable controls, export history, share support, cautious AI suggestion services, CI workflow, and release packaging notes
- Verified with `flutter analyze`, `flutter test`, targeted importer tests, and `flutter build web`
- Integrated the recent worktree automation outputs for Germany and Italy
- Verified with `flutter analyze`, `flutter test test/domain/source_importers_test.dart test/domain/it_crea_importer_test.dart`, `flutter test`, and `flutter build web`
- Implemented Phase Q manual data governance writeback
- Added manual source-record merge, source-record split, canonical override, manual governance logs, and Operations review actions
- Verified with `flutter analyze`, `flutter test test/domain/manual_governance_test.dart test/operations_page_test.dart`, `flutter test`, and `flutter build web`
- Prepared GitHub publication materials in English and added source-code license/governance files
