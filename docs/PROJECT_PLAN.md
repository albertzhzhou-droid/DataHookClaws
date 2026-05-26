# DataHookClaws Master Plan

## Mandatory Use

This file is the project-wide plan document that every future agent run must read before making architectural or implementation decisions.

Companion context file:

- `/Users/zhouzhenghang/Desktop/DataHookClaws/AGENT.md`

## Product Target

DataHookClaws should become:

`a local-first, progressively enriched, provenance-first official nutrition database client`

The complete operating loop should be:

1. Open app and use immediately with local data
2. Search a query
3. Return local results first
4. Foreground-fetch easy/high-value official data if local coverage is weak
5. Continue background enrichment while the user is viewing results
6. Normalize and archive all accepted records into the local database
7. Preserve provenance, source versions, and merge auditability
8. Export slices or snapshots of the accumulated database on demand

## Architecture Baseline

The intended stable architecture is:

- UI layer
- Search orchestrator
- Budgeting/routing layer
- Foreground fetch runner
- Background enrichment queue
- Source adapters/importers
- Normalization toolkit
- Provenance-first persistence
- Canonical merge layer
- API/DTO layer
- Export layer
- AI assist layer with strict non-fact authority

Reference architecture detail:

- `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/production_architecture_spec.md`

## Phase Status

### Completed

#### Phase A: Foundation

- Flutter app scaffold
- Initial search/import UI
- importer abstraction

#### Phase B: Persistence And Source Ingestion

- SQLite repository
- import logs
- import history UI
- USDA importer
- Canada CNF importer
- UK CoFID importer
- Japan MEXT importer

#### Phase C: Official Dataset Preparation

- manifest-driven official dataset grabber
- direct download support
- zip package preparation
- Canada CNF auto-download/unzip
- UK/Japan auto-download when local path is omitted

#### Phase D: National Source Governance

- national food source catalog
- integrated vs cataloged status model
- roadmap UI by country

#### Phase E: Normalization Toolkit

- nutrient dictionary
- category mapping
- unit conversion
- label cleaning
- alias key normalization
- modular normalization structure
- normalization tests

#### Phase F: Controlled Search Bus

- `SearchOrchestrator`
- `FetchBudgetPlanner`
- `ForegroundFetchRunner`
- local-first search state machine
- Ollama-backed query expansion entry

#### Phase G: Background Enrichment

- session-local background enrichment queue
- dwell-triggered scheduling
- fetch-job persistence
- UI enrichment status card

#### Phase H: Provenance-First Read Chain

- summary/detail repository reads
- summary/detail DTOs
- provenance detail bottom sheet

#### Phase I: Deterministic Canonical Merge

- `CanonicalMergeService`
- merge-aware repository writes
- canonical snapshot semantics for `foods`
- canonical rebuild support for legacy source-as-canonical data
- unified search results by canonical food

#### Phase J: Merge Audit And Explainability

- persistent merge audit storage
- candidate-level merge explanation
- merge audit rebuild for existing databases
- provenance detail merge explainability in UI and API

#### Phase K: Export Layer

- search result JSON export
- search result CSV export
- country-level export service
- SQLite snapshot export
- minimal home-page export UI
- export verification coverage

#### Phase M/P: Budget Governance And Operations Surface

- `SourceCapabilityRegistry`
- `SourceRoutingService`
- `StorageBudgetManager`
- `ModelBudgetController`
- repository operations reads for fetch jobs, artifacts, and storage paths
- artifact soft removal
- independent Operations page for jobs, artifacts, importer diagnostics, and budgets
- New Zealand surfaced as blocked in operational diagnostics

#### Phase O/P2: Data Quality Review And Observation-Level Search

- read-only merge review issue surface in Operations
- low-confidence, category-conflict, rejected-candidate, and nutrient-variance issue detection
- advanced local search query model
- country/source/category filters
- nutrient range filters with presets
- detail nutrient source comparison
- DTO support for nutrient comparisons

#### Phase Q: Manual Data Governance Writeback

- manual merge/split/override actions from Operations review issues
- source-record merge into an existing canonical food
- source-record split into a new canonical food
- canonical display/category/country/description/serving override
- manual governance log persistence
- source-level merge audit update for manual actions
- SQLite and Memory repository parity for governance writeback

#### Phase N/R: AI Cautious Expansion And Production Engineering

- SQLite `app_meta` settings persistence
- Settings page for Ollama endpoint/model, model budget, storage budget, export directory, and source enablement
- runtime construction from persisted settings for Ollama, model budget, storage budget, export service, and source routing
- cautious AI suggestion services for source routing, merge issue explanation, and export summaries
- all AI output remains logged and non-authoritative
- persistent export history
- system share wrapper for exported files
- Operations export history surface
- GitHub Actions CI for analyze, tests, importer targeted tests, Web build, and Web artifact upload
- release packaging notes for Web, Android, and macOS
- English public README and repository governance files for GitHub publication
- MIT source-code license boundary plus source-data notice

### In Progress

- No active in-progress phase is open right now.

### Next Planned Phase

#### Phase L: More Official Sources

Goal:

- expand real official dataset coverage beyond the current 4 implemented importers

Required outputs:

- at least one new implemented importer from the grabber-ready sources
- importer tests
- normalization and provenance compatibility with the existing canonical merge pipeline

Status update:

- Switzerland importer implemented
- Australia AFCD importer implemented
- France CIQUAL importer implemented
- Denmark Frida importer implemented
- Germany BLS importer implemented
- Italy CREA web importer implemented
- importer registry and local scaffold queue implemented
- New Zealand FOODfiles is blocked for the current architecture because its Terms of Use require original and unaltered presentation of the data
- Germany and Italy importer verification is complete after integrating the recent automation outputs
- Spain BEDCA is blocked because the queued `single_excel` source shape does not match the official public web/database path, and BEDCA use conditions require source attribution plus preservation of original meaning before normalized importer/export use
- Finland Fineli is blocked because the official open-data URL currently redirects to THL maintenance, preventing verification of the CSV package and current license path

## Remaining Strategic Phases

### Phase M: Budget And Storage Governance

Status:

- completed as the first budget-governance pass
- defaults are constructor-configurable but not yet exposed through Settings
- automatic route remains intentionally limited to USDA, Canada CNF, UK CoFID, and Japan MEXT

### Phase N: AI Assist Expansion

Status:

- completed first cautious expansion pass
- source routing assistance is suggestion-only and still constrained by source capabilities and settings
- merge candidate review assistance is explanation-only and does not write merge state
- export summarization writes only export history summary text
- all AI output is logged through `ai_suggestion_log` and constrained by `ModelBudgetController`

Hard limits:

- AI must never generate authoritative nutrient facts
- AI must never overwrite source truth directly

### Phase O: Observation-Level And Advanced Search

Status:

- completed first pass
- advanced filters are local-only
- nutrient range search uses provenance observations with legacy snapshot fallback
- detail panel compares source-level nutrient observations
- future work can add saved filters and more scalable SQL-native planning

### Phase P: Review And Operations Surfaces

Status:

- first Operations page completed
- fetch jobs, dataset artifacts, importer diagnostics, and budgets are visible
- failed automatic-source jobs can be retried
- artifact delete is soft-delete only
- data quality review issues are visible
- export history is visible
- manual merge/split/override writeback is implemented as a first-pass controlled workflow
- manual governance actions are logged and visible in Operations

### Phase Q: Manual Governance

Status:

- completed first writeback pass
- manual merge moves a source record under an existing canonical food and refreshes snapshots
- manual split creates a new canonical food for a source record and refreshes snapshots
- manual override persists curated canonical display/category/country/description/serving fields
- manual actions write governance logs and source-level merge audit entries

Remaining hardening:

- undo/redo is not implemented
- batch review queues are not implemented
- role-based governance permissions are not implemented
- dedicated conflict resolution workspace is not implemented

### Phase R: Production Release Engineering

Status:

- GitHub Actions CI added for analyze, test, targeted importer tests, and Web build artifact
- release packaging notes added
- Web artifact builds locally and in CI definition
- public GitHub repository materials are prepared in English
- `LICENSE`, `NOTICE`, `CONTRIBUTING.md`, `SECURITY.md`, and `CODE_OF_CONDUCT.md` are present
- Android/macOS release signing/notarization are documented but not automated
- no formal public data-product release until license governance is complete

### Source Expansion Sequence

Recommended importer sequence:

1. Switzerland
2. Australia
3. New Zealand, blocked pending legal/product decision
4. France, completed
5. Denmark, completed
6. Germany, completed
7. Italy, completed
8. Spain, blocked pending web/API and license/product review
9. Finland, blocked while official open-data path is under maintenance

Constraints:

- keep grabber and importer responsibilities separate
- keep source licensing/reuse boundaries explicit

Potential additions:

- fetch job inspection page
- dataset artifact management page
- merge review tools
- importer diagnostics

## Stable Technical Rules

- Local DB is the primary product surface.
- Provenance is mandatory.
- AI is assistive only.
- Canonical merge remains deterministic until an explicit later phase replaces or augments it.
- `foods` stays as the fast canonical snapshot model.
- Background enrichment stays resource-controlled.
- New importer sources stay manual-only until source capability metadata explicitly enables automatic routing.
- Artifact deletion remains soft-delete unless a future destructive cleanup phase is approved.
- Advanced filters remain local-only and must not trigger proactive fetching.
- Data quality review may write manual merge/split/override decisions only through the controlled governance workflow.
- AI remains suggestion-only and must not write nutrition facts or authoritative canonical fields.
- Settings persist through SQLite `app_meta`; first-pass runtime service changes apply on next app start unless explicitly hot-reloaded by a later phase.
- CI must keep `flutter analyze`, `flutter test`, source importer targeted tests, and Web build green.

## Required Verification For Future Phase Work

At minimum after meaningful implementation:

- `flutter analyze`
- `flutter test`

When relevant:

- targeted widget verification
- importer-specific tests
- migration/rebuild tests

## Plan Maintenance Rule

Every future agent that changes project scope, phase ordering, implementation status, or phase completion state must update this file in the same run.

## Last Update

### 2026-05-23

- Created `PROJECT_PLAN.md` as the mandatory always-read plan file
- Marked deterministic canonical merge as completed
- Completed merge audit/explainability phase
- Completed export layer phase
- Set importer expansion as the next planned phase

### 2026-05-24

- Implemented Switzerland importer
- Implemented Australia AFCD importer
- Replaced hardcoded importer controls with a descriptor-driven importer registry
- Added importer scaffold queue and local scaffold templates for Codex automation
- Reviewed New Zealand FOODfiles Terms of Use and blocked NZ importer work under the current normalization/canonical architecture
- Advanced the next actionable importer target to France
- Implemented France CIQUAL importer
- Added CIQUAL direct workbook auto-grab wiring
- Advanced the next actionable importer target to Denmark
- Implemented Denmark Frida importer
- Kept Denmark auto-download disabled because Frida sends dataset links through an official email form
- Integrated Germany BLS importer implementation from the automation work and verified parser/sync tests
- Integrated a live Italy CREA / AlimentiNUTrizione importer against the official HTML search/detail portal and verified mocked parser/sync tests
- Removed Germany scaffold placeholder leftovers and fixed Italy test response encoding for UTF-8 labels/units
- Marked Germany and Italy queue items completed
- Implemented Phase M/P budget governance and operations surface
- Added source capability routing, storage/model budget controls, operations diagnostics, artifact soft removal, and automatic-source retry support
- Marked New Zealand as explicitly blocked in runtime source status
- Verified with `flutter analyze` and `flutter test`
- Implemented Phase O/P2 data quality review and observation-level search
- Added advanced local filters, nutrient range search, review issue derivation, and nutrient source comparison
- Verified with `flutter analyze` and `flutter test`
- Implemented Phase N/R AI cautious expansion and production engineering
- Added SQLite-backed Settings, cautious AI suggestion services, export history, share support, CI workflow, and release packaging notes
- Verified with `flutter analyze`, `flutter test`, `flutter test test/domain/source_importers_test.dart`, and `flutter build web`
- Integrated recent worktree automation outputs for Germany and Italy
- Verified with `flutter analyze`, targeted Germany/Italy importer tests, `flutter test`, and `flutter build web`
- Implemented Phase Q manual data governance writeback
- Added manual merge, split, override, governance logs, manual merge audit updates, and Operations review actions
- Verified with `flutter analyze`, `flutter test test/domain/manual_governance_test.dart test/operations_page_test.dart`, `flutter test`, and `flutter build web`
- Prepared GitHub publication materials in English
- Added MIT code license, source-data notice, contribution guide, security policy, and code of conduct
