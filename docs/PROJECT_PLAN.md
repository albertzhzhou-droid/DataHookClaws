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
- importer registry and local scaffold queue implemented
- New Zealand FOODfiles is blocked for the current architecture because its Terms of Use require original and unaltered presentation of the data
- next actionable importer sequence now starts at Germany

## Remaining Strategic Phases

### Phase M: Budget And Storage Governance

Implement:

- `StorageBudgetManager`
- `ModelBudgetController`
- more explicit source-routing heuristics

Goals:

- constrain disk growth
- constrain local model costs
- avoid uncontrolled fetch amplification

### Phase N: AI Assist Expansion

Potential additions:

- source routing assistance
- merge candidate review assistance
- dedupe suggestion support
- export summarization

Hard limits:

- AI must never generate authoritative nutrient facts
- AI must never overwrite source truth directly

### Phase O: Observation-Level And Advanced Search

Potential additions:

- nutrient range filters
- observation-aware source comparison
- more advanced alias and multilingual search

### Phase P: Review And Operations Surfaces

### Source Expansion Sequence

Recommended importer sequence:

1. Switzerland
2. Australia
3. New Zealand, blocked pending legal/product decision
4. France, completed
5. Denmark, completed
6. Germany
7. Italy
8. Spain
9. Finland

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
- Advanced the next actionable importer target to Germany
