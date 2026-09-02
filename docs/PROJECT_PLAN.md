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
- persisted severity + issue-type review filtering with AND semantics
- visible/page, matching-backlog, and total-backlog counts; clear action; and fail-open recovery for invalid saved filters
- named saved review views with save/apply/delete controls, deterministic retention, and fail-open recovery for invalid saved-view payloads
- current-page review issue selection with per-card controls, select-visible/clear actions, live-region counts, and no repository side effects
- versioned, delimiter-safe logical review issue identities with strict decoding, type-specific subjects, and deterministic duplicate collapse
- versioned, non-executing queued/deferred worklist items with atomic repository-backed persistence, bounded retention, and corruption-safe recovery
- current-page Queue/Defer/Untrack controls, whole-worklist counts, per-card status/snapshot-change indicators, isolated retry, and confirmed corruption recovery without governance execution
- default-collapsed read-only worklist inventory across persisted identities, with 20-item local paging, exact snapshot/identity inspection, and no repository or governance side effects
- ephemeral All/Queued/Deferred inventory filtering with whole-snapshot counts, filtered paging, deterministic page reset/clamping, and no persistence or repository side effects
- bounded local inventory search across an explicit stored-field whitelist, composed with status and paging without persistence or live lookups
- repository-native filtering across the complete derived backlog before offset/limit, with deterministic ordering and 100-item Previous/Next pages
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

#### Phase R+: Complete-App Experience And Workflow Parity

- The goal-aligned complete-mode lane is now active.
- Focus points:
  - favorites + comparison workflow to close the result loop
  - action-trace logging and replay on home + operations workflow surfaces
  - shared serialized action-trace persistence and cross-page snapshot delivery
  - action-filtered activity trace playback and replay-safety handling on home
  - saved/structured action traces for recent search and governance behavior
  - trace replay recovery-study lane added (fingerprint, resumable action sessions, partial recovery)
  - export recall replay from recent export history (search + country scopes)
  - batch review workbench planning and governance undo/redo strategy
  - background persistence research for queue recovery and quota impact
  - compare accessibility regression gate hardening (dynamic status phrase anchor checks, template contract completion, recall chip semantics)
- Current status:
  - favorites persistence and collection replay shipped
  - in-progress comparison workflow shipped as a basic 3-item selection and nutrient panel
  - in-progress home-page action-trace log with action filters and replay gating
  - in-progress near-cycle home-task session grouping (time-windowed) for action-loop review and replay
  - completed home-page near-cycle task-loop session grouping with 20-minute session windows and session-level replay
  - in-progress operations governance trace logging for retry/merge/split/override/share
  - completed same-repository trace serialization across Home/Operations, including queue recovery, clear ordering, payload validation, and background Home snapshot updates
  - completed the non-executing MergeReview worklist domain/store foundation: queued/deferred snapshots persist by structured logical issue identity without invoking governance actions
  - completed current-page MergeReview worklist controls: Queue/Defer/Untrack, confirmed clear recovery, whole-list counts, exact-ID status chips, and stored-snapshot change indicators
  - completed a read-only cross-page MergeReview worklist inventory with local 20-item paging, full saved identity/evidence inspection, last-page normalization, and refresh-error snapshot retention
  - completed local All/Queued/Deferred inventory filtering with whole-list chip counts, matching-subset paging, zero-match handling, and ephemeral reconstruction reset
  - completed bounded local inventory search with explicit stored-field scope, status intersection, deterministic page reset/clamping, and no repository/app-meta/governance/trace side effects
  - completed held-read inventory regression hardening: loading disables all local controls and stale callbacks, while a successful shrinking snapshot retains status/query and clamps the page
  - implemented home-page recent-export query/country recall and deterministic re-search workflow
  - added clear-all control for recent export recall chips for recall-list lifecycle management
  - made recent-export recall list persist through app restarts via `app_meta` and avoid rehydrating cleared lists
  - queue and roadmap alignment completed (see `docs/upgrade_queue.md`)
  - completed compare accessibility gate hardening for status phrase anchoring and `requiresLiveRegion` contract cleanup
  - completed compare 无障碍语义锚点稳定性修复：将动态 compare 状态短语与 `Export status message:` 容器对齐，降低动态赋值文本与实际语义渲染偏移导致的误报
  - fixed analyze趋势脚本 `--help` 在 CI/CI wrapper 非 tty 场景下返回码 2 的问题，改为显式 help 分支和稳定 CLI 行为
  - completed compare 回放提醒行为研究闭环：新增 `tool/analyze_compare_replay_prompt_funnel.dart` 与
    `test/domain/analyze_compare_replay_prompt_funnel_test.dart`，支持按 `scopeKey + promptSessionIndex` 聚合 urgent_prompt 行为漏斗并验证本地回归
  - completed compare prompt 漏斗口径收敛：移除冗余 session 汇总字段 `scope`，新增缺失文件与 payload 上限回归测试，防止无效输入影响脚本闭环。
  - completed compare 门禁脚本离线可执行化：`tool/ci_checks.sh` 使用最小 `--packages` 配置运行 compare 无障碍/趋势/看板/提醒漏斗脚本，支持无网情况下本地完整闭环回归与严格失败传播。
  - completed 本地 CI wrapper 稳定性收敛：`tool/ci_checks.sh` 的 `run_local_dart_check` 增加参数边界检查与空参数安全展开，修复 set -u 下的 `unbound variable` 假失败，确保 compare 草稿清理/unit/accessibility/trend/funnel 步骤在本地复核可执行。
  - completed `tool/ci_checks.sh` Flutter 命令解析收敛：引入 `FLUTTER_CMD` 统一调度，并支持 `DHC_FLUTTER_BIN` 与 `DHC_DART_BIN` 自动派生 flutter 可执行文件，减少 PATH 不含 flutter 时的 command-not-found 噪音干扰。
  - completed 细化 CI 严格策略分层：`tool/ci_checks.sh` 将 Dart 严格控制 (`DHC_FORCE_DART_CHECKS`) 与 Flutter 严格控制 (`DHC_FORCE_FLUTTER_CHECKS`) 解耦，避免非 CI 环境下仅为 Dart 校验就受 Flutter 缺失阻断。
  - completed compare accessibility 锚点映射修复：`tool/check_compare_accessibility.dart` 在 snapshot phrase 校验路径中统一使用 `_semanticHostForPhrase`（含 `Export status message:` fallback），使动态状态短语的语义/实时区域断言与实际渲染容器对齐。
  - implementation to continue from this goal in small-step slices

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

### Phase R+: Complete-App Experience And Workflow Parity

Goal:

- close the functional loop for end-users beyond core import/search/merge/export

Required outputs:

- favorites (star/collection) and fast recall
- result comparison card stack with source-level traces
- behavior trace replay for search/import/governance actions
- batch review workspace planning and implementation plan
- governance action undo/redo foundation
- persistent background queue recovery and change-impact notes

Status:

- in progress with initial production slices shipped:
  - favorites + fast recall
  - 3-item result comparison skeleton with nutrient list view
  - action-trace logging on home page (search/import/favorite/compare/export) with action filtering
  - operations governance action trace logging (retry, merge, split, override, share)
  - shared `ActivityTraceStore` serializes Home/Operations metadata mutations and broadcasts successful snapshots; the current guarantee is same-isolate and same repository-object identity
  - compare accessibility regression + compare undo recovery regression checks
    (local/CI 双轨：非 CI 通过 `tool/ci_checks.sh` 跳过，CI 走严格失败)
  - compare 单位归一化脚本回归开始接入 `tool/ci_checks.sh` 与 GitHub CI
  - compare 回放失败状态可访问性快照语义检查接入 `tool/check_compare_accessibility.dart`
  - compare 无障碍快照统计已接入结构化解析器 `tool/parse_compare_accessibility_report.dart`
    与 `COMPARE_REPLAY_A11Y_CI_METRICS` / `COMPARE_REPLAY_A11Y_PARSED_JSON` 指标产物
  - compare 无障碍快照解析器 contract 升级到 v1.0.1：
    schemaVersion 严格校验、未知 severity 与 payload 长度告警、长度上限与指标扩展项已接入 CI 解析输出
  - compare 无障碍快照趋势治理脚本升级完成：
    `tool/analyze_compare_accessibility_trends.dart` 支持 `--window-runs`（按条数）与 `--window-days`（按时间窗）分析模式；新增 `alerts` 输出与阈值环境变量（schemaMismatch / unknownSeverity / pass / phraseSuccess / semantics / liveRegion），并新增 `rateTrend`（首尾变动）与 `runTimestampUtc` 时间来源。已新增 `maxDrop`、`maxConsecutiveDownRuns` 指标与 `DHC_A11Y_TREND_FAIL_ON_ALERTS` 严格执行策略，并已接入 `tool/ci_checks.sh` 与 GitHub CI 的 Compare accessibility 趋势阶段。
  - compare 无障碍趋势治理增补：支持历史文件追加输出（`--history-file` / `--history-max-entries`）与告警抖动窗口（`--trend-noise-window`），并将 `trendHistory` 与抑制元数据并入趋势摘要。
  - compare 无障碍趋势治理进一步增补：新增日报/周报看板脚本 `tool/build_compare_accessibility_trend_digest.dart`，用于历史趋势可视化与稳定告警候选识别（`--regression-window`）。
    - 看板参数（`--daily-limit` / `--weekly-limit` / `--regression-window`）支持通过环境变量 `DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT`、`DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT`、`DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW` 外置管理。
  - completed compare 无障碍锚点对齐修复：`tool/check_compare_accessibility.dart` 的动态短语检测已改为映射到真实语义容器（`Export status message:`）并加入候选 host fallback，减少动态文案与语义检测错位。
  - completed check script lint 细化修复：`tool/check_compare_accessibility.dart` 清理 null-aware 集合字面量告警，基于最小 `--packages` 配置复核
    四阶段无障碍闭环（check→parse→trend→看板）通过。
- remaining for completion:
  - behavior trace replay for all workflow classes
  - canonical-aware replay semantics for compare/favorite restoration and action filtering
  - governance undo/redo and replayability for non-idempotent actions
  - source-level comparison source lineage and export linkage
- next checkpoints: governance undo/redo foundation and batch review workspace planning

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
- future work can extend current-page selection into cross-page inventory and revision-validated execution, while also adding more scalable SQL-native planning

### Phase P: Review And Operations Surfaces

Status:

- first Operations page completed
- fetch jobs, dataset artifacts, importer diagnostics, and budgets are visible
- failed automatic-source jobs can be retried
- artifact delete is soft-delete only
- data quality review issues are visible
- review issues can be filtered by severity and issue type; the schema-versioned selection survives page reconstruction through `app_meta`
- invalid or future filter payloads fail open to All so review items are not accidentally hidden
- named non-All filter combinations can be saved, applied, and deleted independently of the active filter; same-name saves update in place and the bounded schema-versioned list survives page reconstruction
- applying a saved view resets review pagination and uses the review-only refresh lane; deleting a saved view neither changes the active filter nor reloads review data
- current visible review issues can be selected individually or together; filter/page/view changes clear selection, while same-query refreshes retain only IDs still visible in the latest successful result
- generated review IDs are canonical `MergeReviewIssueIdentity` v1 payloads; mutable evidence is excluded, nutrient label is explicit, and Memory/SQLite derive matching identities for the parity fixture
- queued/deferred review work items persist in `merge_review_worklist_v1`; updates retain original `createdAt`, refresh issue evidence snapshots, keep `updatedAt` monotonic across clock rollback, and sort queued before deferred
- worklist batches are one-read/one-write atomic within the same isolate and repository object, reject capacity or UTF-8 payload overflow without partial writes, and require explicit clear before mutating malformed/unsupported/duplicate/over-cap persisted state
- current-page selection can atomically Queue or Defer all selected visible issues and Untrack only selected exact IDs; failures preserve selection and the last good status snapshot, while successful writes remove only submitted IDs
- whole-worklist queued/deferred counts and exact-ID card chips come from an independent load/error/retry lane; the `Review snapshot changed` marker compares stored evidence fields only and is not live database revision validation
- confirmed Clear removes only worklist snapshots and recovers malformed persistence without deleting food/governance data; worklist controls never invoke merge/split/override or append governance/activity records
- worklist writes freeze the mutable review context, manual governance writes and worklist writes are mutually exclusive, and refresh requests arriving during a worklist write are coalesced into one post-mutation refresh
- a default-collapsed inventory browses the entire loaded worklist in store order, 20 snapshots per local page, including identities outside the current review page; paging has no repository/query/governance/trace side effects
- inventory items expose the full structured identity and stored evidence/timestamps only; initial read failure shows no fabricated empty inventory, later refresh failure preserves the last good snapshot, and shrinking mutations clamp the page offset
- inventory expansion is controlled by parent page state so loading/error rebuilds preserve inspection context without PageStorage type collisions with nested selectable text
- inventory status chips filter the loaded snapshot locally as All/Queued/Deferred, retain store order, reset to the first matching page on change, clamp after mutations, and default to ephemeral All after reconstruction without writing `app_meta`
- zero-match status filters keep both pagers disabled; filter callbacks are disabled and method-guarded during worklist load/write, while retained snapshots remain browsable after later read failure
- inventory search is limited to canonical ID, target source ID, subject key, suggested canonical ID, reason, candidate summary, and issue identity; trim-plus-case-insensitive literal matching excludes type/status/timestamps/placeholders and never performs a live lookup
- search composes after status and before local paging, resets/clamps the combined page, preserves store order, reconstructs empty, and is disabled/method-guarded with the other inventory controls during worklist load/write
- a controlled held-read regression proves that search/clear/status/pager callbacks cannot mutate local state while loading and that a successful refreshed snapshot preserves active status/query while clamping a now-invalid second page
- Memory and SQLite expose the same `MergeReviewIssueQuery` / `MergeReviewIssuePage` contract: stable ordering, filter-before-page semantics, and full total/matching counts
- Operations pages the filtered backlog in 100-item windows, including matches beyond the former first-100 client window
- filter/page interactions use an independent review-only refresh lane with inline progress, inline retryable errors, and latest-response-wins race protection
- review-only refreshes do not reload jobs, artifacts, import logs, exports, governance logs, or storage budget state
- initialization, toolbar, and post-mutation aggregate refreshes run operations and review lanes concurrently with independent generation/error/retry state; one lane's failure no longer discards the other's successful snapshot
- subsequent operations refreshes retain the last successful content and use inline progress instead of replacing the body with a full-page spinner
- action routing follows actual side effects: artifact removal is operations-only, sharing performs no repository refresh, and failed merge/split/override actions do not trigger redundant reads
- SQLite derives the full review backlog from a fixed-size, transaction-scoped bulk snapshot instead of per-food detail reads; all snapshot SELECTs share one transaction and avoid dynamic `IN` parameter growth
- bulk review hydration preserves the legacy `foods` plus `canonical_food` eligibility boundary, excludes orphan provenance rows in SQL, and chooses duplicate audits deterministically by newest timestamp then greatest ID
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
- worklist persistence, current-page non-executing controls, a read-only cross-page inventory, local status filtering, and stored-field text search exist, but there is no orphan or identity-migration discovery, live target revision revalidation/CAS, background synchronization, cross-page selection, or batch merge/split/override execution protocol
- SQLite review derivation uses a transaction-scoped bulk snapshot but still fully materializes the issue backlog in Dart; SQL-native filter pushdown, a materialized review index, and constant-memory cursors are not implemented
- role-based governance permissions are not implemented
- dedicated conflict resolution workspace is not implemented

### Phase R: Production Release Engineering

Status:

- GitHub Actions CI added for analyze, test, targeted importer tests, and Web build artifact
- release packaging notes added
- Web artifact builds locally and in CI definition
- public GitHub repository materials are prepared in English
- `LICENSE`, `NOTICE`, `CONTRIBUTING.md`, `SECURITY.md`, and `CODE_OF_CONDUCT.md` are present
- Android/iOS/macOS signing and notarization remain external; opt-in release
  metadata gates now reject unsafe signing identities without provisioning
  credentials
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

### 2026-08-17

- Home-page favorites are now persisted and can replay saved searches.
- Result comparison now supports selecting up to 3 visible foods and showing a nutrient-level diff list.
- Search refresh and advanced search paths reconcile comparison selection state to keep UI consistency.
- Continued update queue growth via `docs/upgrade_queue.md` with near-term future-parity research tasks.
- Added home-page recall flow for recent exports: exported search scopes can be tapped to rerun immediately.
- Extended recall flow with scope-aware replay and deterministic context reset for advanced filters.
- Added quick clear action for recent export recalls and queued recall-memory persistence/ephemerality research in `docs/upgrade_queue.md`.
- Implemented persistent storage for recent export recall memory so cleared recall lists survive app restarts.
- Completed compare accessibility regression gate hardening in CI scripts/tests: added trend/digest parser assertions, strict-mode regression guard tests, and fixed CI workflow test shell-string interpolation to keep static verification stable under analyzer checks.
- 增加 compare 无障碍门禁闭环的离线复核：用 AOT 编译脚本验证 `check_compare_accessibility` / `parse_compare_accessibility_report` / `analyze_compare_accessibility_trends` / `build_compare_accessibility_trend_digest` 与单位/回放清理检查在同一闭环内全部通过。
- 新增 `ci_workflow_test.dart` 对 `ci_checks.sh` 的本地隔离策略（`DART_CHECKS_HOME` 与 `HOME + DART_SUPPRESS_ANALYTICS`）进行静态断言，避免 shell `$` 插值与离线 hook 场景下的静态回归误报。
- `README` 的 AOT 离线复核指令改为变量化参数（`FLUTTER_DART_BIN`），便于本地环境直接复用。
- 在 `tool/ci_checks.sh` 里补齐 Dart/Flutter 严格模式职责分离的回归要求后，`ci_workflow_test.dart` 新增 Flutter 步骤块静态断言：本地 `CI=false` 场景下 Flutter 步骤不再受 `DHC_FORCE_DART_CHECKS` 影响，需通过 `DHC_FORCE_FLUTTER_CHECKS` 或 CI 才触发严格。README 也同步补充了变量边界说明。
- 在 `tool/ci_checks.sh` 增加 `DHC_FLUTTER_BIN` 可执行性硬约束：自定义 Flutter 路径若失效则立即报错退出，避免误配路径被静默降级为系统 `flutter`。
- 增补 `test/domain/ci_workflow_test.dart` 关键 fail-fast 回归，验证 `DART_BIN`/`FLUTTER_BIN` 无效时本地与 CI 模式均可被检测，并使用临时目录隔离测试输入避免路径污染；用于对 `ci_checks.sh` 严格模式行为做跨场景回归固化。
- 收紧 `ci_checks.sh` 的可执行性边界：`DART_BIN` 与 flutter 命令改为 `-x` 检测；新增回归覆盖 `DART_BIN` 为“存在但不可执行”文件的 fail-fast 情况，防止 command 可见但不可执行路径被错误放行。
- 修复趋势告警边界回归测试歧义：`test/domain/ci_workflow_test.dart` 将 warning 场景中的 `analyze_compare_accessibility_trends` 调用设置为 `CI=false`，将本该通过的告警下降样本与 strict 失败路径分离；并在严格路径复核阈值下保持正确 fail。
- 继续收敛 compare 提醒漏斗脚本：统一 session 汇总口径（只保留 `scopeKey`），新增缺失输入文件与 payload 上限告警测试，避免漏斗脚本在 CI/静态回归中被无效输入放大噪声；当前环境仍受 sqlite3 hook 与权限限制，暂未完成脚本运行时闭环。

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
- Added home-page favorites and 3-item comparison workflow for complete-app mode MVP in this goal lane
- 增加 compare 无障碍门禁文档“离线 AOT 重放”说明，明确在 hook 受限环境下仍可复核完整链路指标。

### 2026-08-26

- 本轮复核无结构性改动的完整验证闭环仍通过：
  - `flutter test test/domain/ci_workflow_test.dart --reporter compact` 通过
  - `CI=true ./tool/ci_checks.sh` 通过（包含 analyze、全量 test、compare 无障碍/解析/趋势/趋势看板、compare replay 提醒漏斗、web 构建）
- compare 趋势告警边界保持稳定：`test/domain/ci_workflow_test.dart` 的 warning/strict 分离用例与实际 `ci_checks.sh` 一致，非 strict 场景不应被 CI 门禁变量误杀。
- 并补齐升级队列状态：`docs/upgrade_queue.md` 中 “M4 比较营养单位归一化脚本执行（本地核验）”已标记完成（脚本路径已在 `ci_checks` strict + `ci_workflow_test` 中持续通过）。
- 本轮追加：
  - 对 `tool/check_compare_unit_normalization.dart` 补充边界回归：空值/反例样本、比较口径一致性场景与分母冲突场景。
  - 新增 `docs/compare_unit_normalization_release_checklist.md`，将 M4 compare 单位归一化 release 的核验动作收敛为可复核清单。
  - 持续收敛 compare 单位归一化 CI 门禁参数化：在 `tool/ci_checks.sh` 与 `.github/workflows/flutter-ci.yml` 中补齐 `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE` 的默认与透传，避免环境内 fixture 路径漂移；并在 `test/domain/ci_workflow_test.dart` 增加静态一致性断言。
  - 增加 `ci_workflow_test` 覆盖：`check_compare_unit_normalization.dart` 在运行时会遵循 `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE` 覆盖路径（含回归样例）；并同步补充 `README` / `compare_unit_normalization_release_checklist.md` 说明。
  - 修正回归测试断言方向：`compare unit smoke check falls back when custom fixture path is missing` 改为在 `stderr` 验证 `Normalization fixture not found` 提示，保持与脚本输出通道一致。
  - 验证命令：`DHC_FORCE_DART_CHECKS=true CI=false ./tool/ci_checks.sh`（Dart 阶段通过，Flutter 阶段按非 CI 策略软跳过）。

### 2026-08-30

- compare 单位归一化 fixture 容错闭环继续收敛：
  - `tool/check_compare_unit_normalization.dart` 将文件读取与 JSON 解码纳入回退保护，损坏 JSON 不再在门禁启动阶段直接抛错。
  - fixture 三个 case 数组现在要求元素为 JSON object，且总用例数不能为零；非法结构会明确写入 stderr 后运行内置回归集，不再静默丢弃条目。
  - `test/domain/ci_workflow_test.dart` 新增 invalid JSON、非对象数组项与空 fixture 三条运行时回归。
  - 本轮修改前基线验证：`DHC_FORCE_DART_CHECKS=true CI=false ./tool/ci_checks.sh` 的 Dart 门禁全链通过；Flutter 阶段因 SDK cache 写权限限制按非 CI 策略软跳过。
- compare prompt trace 与漏斗口径修复：
  - `promptInstanceId` 改为 scope + 已求值毫秒时间 + `promptSessionIndex`，恢复同一弹窗生命周期的可关联、跨会话实例的可区分性。
  - `tool/analyze_compare_replay_prompt_funnel.dart` 的文本汇总改用真实 snake_case action，并把所有实际 defer 分支聚合到 `deferred`、prompt 内清理聚合到 `clearNow`。
  - `analyze_compare_replay_prompt_funnel_test.dart` 增加 `dismissed_by_user`、`dismissed_no_action`、`clear_from_prompt` 与人类可读汇总回归。
- compare 单位显示正确性修复：
  - 方差判定、min/max 匹配与高低值语义统一使用 `nutrientComparisonAmountTolerance`（1e-6），近似等价值不再被同时误标为 highest。
  - 空单位与未知单位都进入 non-comparable unit mismatch；新增容差一致性与空单位标签单测。
- CI 可配置性闭环：GitHub job 显式映射 repository variable `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE`，并由 `ci_workflow_test.dart` 固化该 YAML 注入路径。
- activity trace 并发可靠性闭环：
  - Home 与 Operations 的 `activity_trace_v1` 读改写统一迁移到共享 `ActivityTraceStore`，同一 repository 实例上的 append/load/clear 串行执行。
  - 成功写入通过广播快照同步仍挂载的 Home；失败写入不广播、不影响主操作，并且不会毒化后续队列。
  - 损坏/超长 payload fail-open，无效 map 在 12 条 retention 之前过滤；超大新事件不再清空仍可编码的旧历史。
  - 目标验证：store 并发/广播/压缩/失败恢复/清除排序 11 项与 Home/Operations 页面目标回归合计 21 项通过；`flutter analyze` 零问题。
  - 边界：队列仅保证同 isolate、同 repository 对象；独立 wrapper 或直接写 `activity_trace_v1` 仍会绕过。
- MergeReview 完整 backlog 查询闭环：
  - 新增 `MergeReviewIssueQuery` / `MergeReviewIssuePage` 与 repository 查询入口；Memory/SQLite 统一执行完整派生、稳定排序、筛选、计数、分页。
  - Operations 新增 100 条 Previous/Next 分页，并以页面/匹配/总数三层口径展示结果；严重度 × type 组合可以命中旧首屏窗口外的 issue。
  - 保留旧 `getMergeReviewIssues(limit:)` 兼容入口与 `limit: 0` 行为；模型、Memory、SQLite 和 widget 均有定向回归。
  - SQLite 派生已改为固定查询数的单事务 bulk snapshot：eligible canonical、sources、aliases、legacy nutrients、observations、audits、candidates 分组读取，避免逐条 details N+1 与动态 `IN` 参数上限；交互刷新隔离见下一项。
  - bulk 与旧逐食物 hydration oracle 的完整 issue 字段保持一致；重复 audit 按 `created_at DESC, id DESC` 稳定 first-wins，1005 组 canonical/source/audit/candidate 回归通过。
  - 当前边界：仍在 Dart 内完整物化 FoodDetails 与派生 issue，再做筛选、计数和 offset 分页；尚未 SQL-native filter pushdown，也不是常量内存查询。
- MergeReview 局部刷新与竞态恢复：
  - 严重度/type/clear/Previous/Next 仅调用 review query；工具栏和治理/import 变更仍走全量刷新。
  - 独立 generation 保证 latest-response-wins；请求期间分页禁用，失败在 review 区域内提示并可按同一 filter/offset Retry。
  - 旧成功页只在应用 filter/offset 与当前控件一致时显示，避免局部失败后把旧卡片误呈现为新筛选结果。
  - 初始化/工具栏/治理后的 aggregate refresh 已拆成并行 operations/review lane；各自失败、重试与 generation 独立，一侧失败不阻断另一侧提交。
  - 动作刷新按实际副作用路由：artifact 仅 operations，share 不刷新，merge/split/override 仅成功后双刷新；mounted-safe status 独立于读取错误。
  - 目标验证：首次 review 失败、工具栏 review 失败保留快照、首次 operations 失败三类部分失败回归均通过。
- MergeReview 命名保存视图：
  - 当前非 All 严重度/type 组合可命名保存、应用、删除；活动筛选与保存视图使用独立 `app_meta` 键和独立加载失败域。
  - `merge_review_saved_views_v1` 使用 versioned envelope，最多保留 12 项；名称 trim/折叠空白、最长 80 字符，同名（忽略大小写）更新保留 id/createdAt，并以 updatedAt/name/id 稳定排序。
  - 应用保存视图回到 offset 0 并只刷新 review lane；删除不改变当前活动筛选、不触发 review query。损坏、未来 schema 和超长 payload 均 fail-open。
  - 当前边界：写队列仅覆盖同 isolate、同 repository 对象；独立 wrapper/进程仍可能 last-writer-wins，且尚未提供重命名、导出/共享或批量治理动作。
- MergeReview 当前页选择基础：
  - issue card Checkbox 与 `Select visible` / `Clear selection` 提供当前成功页面内的临时多选；live-region 文案报告 selected/visible 两层计数，选择操作不调用 repository 或写入 `app_meta`。
  - filter、offset、saved-view apply 同步清空；相同 saved view 重复 apply 只清选择而不重查。同 query 最新成功刷新做 visible-ID intersection，自动 offset correction 清空；失败或过期响应不修剪。
  - refresh pending 时逐卡和 Select visible 禁用，Clear 仍可立即撤销；方法内部再次校验 loading/current page，避免陈旧 callback 绕过控件状态。
  - 当前边界：仅当前页、仅内存，不支持跨页/全匹配、重启恢复、待办状态或批量治理；v1 identity 只是去重后的逻辑键而非持久数据库主键，真实批量动作前仍需 target revision/snapshot 与执行前重验。
- MergeReview 结构化逻辑身份：
  - `MergeReviewIssueIdentity` v1 使用固定前缀与 unpadded base64url canonical JSON；strict decode 校验完整字段集、schema、类型、冻结 type token 与规范 re-encode，Unicode/分隔符不再改变字段边界。
  - source audit issue 以 source/type/audit 为核心，category conflict 加 candidate canonical，nutrient variance 以 canonical/type/exact label 为核心且不依赖 first observation。reason/summary/数值/单位/展示名/顺序/时间变化不改 ID。
  - 同一逻辑 identity 的重复 candidate/损坏输入在派生层按最新时间及固定词法 tie-break 确定性折叠；Memory 与 SQLite 在故意打乱 hydration 顺序的四类型 fixture 上输出相同 encoded IDs。
  - 当前边界：identity 是派生逻辑键而非数据库 PK、revision 或 idempotency token；source move、subject 改名、schema 升级会换 ID。旧 trace/note ID 不迁移，真实批处理仍需 target snapshot、执行前重验、部分失败与重试协议。
- MergeReview 非执行型 worklist 数据层：
  - 新增 `MergeReviewWorkItem` / v1 codec 与 `MergeReviewWorklistStore`，仅记录 `queued` / `deferred`，保存逻辑 identity、identity source、当前 actionable target 与 issue evidence snapshot；不调用 merge/split/override。
  - `upsertAll` 在同一 repository 对象上串行化并以单次 read-modify-write 原子提交；同批重复 identity 最后一项获胜，已有项保留 `createdAt`、刷新证据，并在系统时钟回拨时保持 `updatedAt` 单调不减。
  - 上限为 500 项和 1,048,576 UTF-8 bytes；容量/编码超限不部分写入。公开读取对坏数据 fail-open，但坏 envelope、坏 item、重复 identity、超容量或超字节载荷必须显式 `clear()` 后才能变更。
  - 冻结四类 issue type 与两类 status 的字面持久化 token；构造参数在 release 模式运行时校验。source-scoped issue 的 target 必须等于 identity source，canonical-level nutrient variance 允许独立 actionable target。
  - 当前边界：只是同 isolate、同 repository 对象内的持久待办快照；跨 wrapper/进程/direct `app_meta` 写入仍 last-writer-wins。数据层本身不提供后台同步、数据库 CAS、revision 重验或任何治理执行语义。
- MergeReview worklist 当前页 Operations UI：
  - 当前成功页选择可原子 Queue / Defer；Untrack 只删除被选且按 exact ID 已跟踪的项。成功只清除已提交选择，失败保留选择与旧状态 chip；同状态再次 Queue/Defer 可刷新保存的 issue snapshot。
  - worklist 以独立 generation/load/error/retry lane 初始化，saved-view 配置阻塞不妨碍 Operations/worklist 渲染；后续读取失败保留最近成功快照。逐卡 chip 使用 exact ID，`Review snapshot changed` 只比较保存字段，不等同于 live DB revision/stale 真值。
  - confirmed Clear 只删除 queued/deferred snapshot，可在损坏 envelope 拒绝变更后显式恢复；不删除 food/governance 数据。Queue/Defer/Untrack/Clear 均不执行 merge/split/override，也不写 governance/activity trace。
  - worklist 变更期间冻结 selection/filter/view/pager/refresh；manual governance 与 worklist 写入双向互斥，期间到达的陈旧 refresh callback 会合并为写入结束后的一次全量刷新。
  - 当前边界：动作输入仅为当前可见成功页；下一项的跨页 inventory 只提供浏览，不扩展选择/变更范围。仍无不可见/消失 identity 盘点或迁移、后台同步、revision/CAS 重验和批量治理执行。
- MergeReview 只读跨页 worklist inventory：
  - 默认折叠面板浏览完整已加载 worklist snapshot，严格沿用 store 顺序并在页面内每 20 条分页；可看到当前 review filter/page 之外的保存 identity。分页不触发 repository read/write、review query、governance 或 activity trace。
  - 每项展示 status/type、canonical/target source、subject、suggested canonical、reason/candidate、issue/saved/updated 时间与完整结构化 identity；没有 checkbox、details lookup、Untrack 或 merge/split/override 入口。
  - load/upsert/remove/clear 的成功快照统一校正末页 offset；首次读取失败不伪装空清单，后续 refresh 失败保留最近成功快照。展开状态由父页面显式控制，避免重建折叠和 PageStorage bool/double 冲突。
  - 当前边界：只声明 loaded stored snapshots；不把 live review page 中的缺席标记为 orphan/resolved/stale，不做 identity 迁移、实时存在性检查、revision/CAS 重验、后台同步或治理执行。本片当时尚无 All/Queued/Deferred 本地筛选，后续已由下一节完成。
- 最终验证证据：
  - `flutter analyze`：通过，零问题。
  - worklist model/store 26 项 + Operations widget 36 项：合计 62 项通过。
  - `flutter test`：全量 245 项通过。
  - `CI=true ./tool/ci_checks.sh`：严格全链通过，包含 analyze、全量 test、source importer 目标测试、compare draft/unit/accessibility/parser/trend/dashboard/prompt-funnel 门禁与 `flutter build web`。

- MergeReview worklist inventory 本地状态筛选：
  - 新增 `All` / `Queued` / `Deferred` choice chips；chip 数量基于完整 loaded snapshot，范围、页数与 pager 基于当前匹配子集，筛选不改变 store 顺序。
  - 筛选是页面私有临时状态，不写 `app_meta`；切换确定性回到首个匹配页，页面重建恢复 `All`。load/upsert/remove/clear 成功后按当前子集校正 offset。
  - 零匹配显示有界空状态并禁用前后翻页；worklist load/write 期间筛选与翻页均禁用，旧捕获 callback 也被 method guard 拒绝。后续读取失败时仍可筛选最近成功快照。
  - 仍只描述 loaded stored snapshots；不新增 repository/query/governance/trace 副作用，也不推断 orphan/resolved/stale/current 或执行治理。
  - Operations widget 39 项、`flutter analyze` 零问题、全量 248 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁和 Web build 均通过。
  - 后续闭环：有界本地文本搜索已由下一节完成，仍不扩展 live/revision 语义。

- MergeReview worklist inventory 有界本地搜索：
  - 新增临时搜索框与 Clear；只扫描 store 上限 500 条的 loaded snapshot，不触发 repository 或 live issue 查询。
  - 白名单严格限定为 canonical food ID、target source record ID、subject key、非空 suggested canonical ID、reason、candidate summary 与完整 issue identity；不搜索 status/type/timestamp/identity-source 重复值、UI 标签或占位词。
  - query 只去首尾空白并与每个字段分别转小写做 literal contains；不分词、不跨字段拼接、不用 regex/fuzzy/音调归一，也不把 identity decode 成实时判断。
  - 组合顺序为 store order -> status -> search -> 20 条分页；输入、Clear 与 status 切换回首个匹配页，load/upsert/remove/clear 成功后按组合子集校正 offset。
  - query/controller 只在页面内存，重建为空且不写 `app_meta`；后续读失败保留最近成功 snapshot/query。load/write 期间输入与 Clear 禁用，旧捕获 callback 也被 method guard 拒绝。
  - Operations widget 41 项、`flutter analyze` 零问题、全量 250 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁和 Web build 均通过；独立 diff 复审无 blocker。
  - 后续闭环：held worklist read 的 loading gate 与成功刷新末页校正已由下一节覆盖。

- MergeReview inventory held-read 回归硬化：
  - 仅新增测试用可控 worklist read repository；production 接口与行为未变。
  - 以 21 个匹配 queued + 1 deferred 的第二页状态启动，持有 toolbar refresh；确认 search/Clear/status/pager 禁用，旧捕获 callback 无法改变 query/controller/filter/page 或增加 operations/review read。
  - 持久快照缩为 20 queued + 1 deferred 后完成读取；active `Queued + needle` 保留，总数 22 -> 21，匹配页从第 2 页校正至第 1 页，控件重新启用。
  - Operations widget 42 项、`flutter analyze` 零问题、全量 251 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：exact-ID 的 loaded review page presence 已由下一节完成；本节仍只改变测试覆盖。

- MergeReview inventory loaded-review-page exact-ID presence：
  - 在完整 loaded worklist 上计算 `on this loaded review page` / `outside it` 汇总，并为当前 inventory 可见项显示同口径 chip；计数不受 inventory status/search/本地分页影响。
  - 可用条件为 selected filter/page 的最新请求已成功、当前不在 loading 且无 review error。首次未成功、同页 refresh pending、筛选/翻页 pending、保留旧页的失败态与 retry pending 均显示 unavailable；成功空页可合法得到 `0 on page`。
  - membership 仅使用完整 `issueId` 字符串相等，不回退到 canonical/source/type/subject 或 decoded identity。已覆盖相同 canonical/source/type 但 exact ID 不同，以及 review 翻页后 on/outside marker 互换。
  - `Outside loaded review page` 只表示另一 review 页或 active filter 排除，并改用中性 other-page 图标；不判断 orphan/resolved/stale/current/live existence，不表示治理安全性。本片没有 presence filter。
  - summary 使用 live region；item chip 非交互。该能力不新增 repository read/write、额外 review query、governance mutation、activity trace、identity migration、revision validation 或执行动作。
  - Operations widget 45 项、`flutter analyze` 零问题、全量 254 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过；独立 diff 复核无 blocker。
  - 后续闭环：availability-safe 的本地 presence 筛选已由下一节完成，不会把 unavailable 状态折算为 outside。

- MergeReview inventory availability-safe presence 本地筛选：
  - 新增页面临时 `All / On loaded page / Outside loaded page` chips；不写 `app_meta`，页面重建恢复 `All`。
  - 组合顺序保持 store order -> status -> bounded literal snapshot search -> exact full-string issue-ID presence -> 20 条本地分页。presence chip 计数覆盖完整 loaded worklist；结果范围描述 status/search/presence 三者交集。任一本地筛选切换回首匹配页，成功 worklist snapshot 按当前交集校正 offset。
  - `On`/`Outside` 只在当前 selected review filter/page 最新请求成功且非 loading/error 时开放。任何真实 review request 开始时，若当前为 `On`/`Outside`，会与 loading 同一状态提交原子重置为 `All` 且 offset=0；pending/failure/retry 均保持显式 unavailable，成功空页则提供真实 `On (0)`。
  - worklist read/write 是独立 lane：期间锁定所有本地 inventory callback 并拒绝旧捕获 callback，但不重置 presence。后续 read failure 保留最近成功 inventory 与 active presence；成功缩水 snapshot 保留筛选并校正分页。held-read 回归已升级为 active status + search + presence 的第二页收缩场景。
  - 三个 chips 组成带标签的 Semantics group；boundary 明确 chip counts 是完整 loaded snapshots，而 result counts 组合 status/search/presence。Outside 仍只表示另一 review 页或 active filter 排除，不推断 orphan/resolved/stale/current/live 或治理安全。
  - 不新增 repository read/write、额外 review query、governance mutation、activity trace、identity migration、revision validation 或执行动作。已覆盖两页组合、search 零结果、成功空 review 页、review pending/failure/retry、initial review failure、held worklist write/read、stale callback、snapshot 缩水与重建。
  - Operations widget 47 项、`flutter analyze` 零问题、全量 256 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过；独立复核无 blocker。
  - 后续闭环：overlapping successful response 的 ownership 回归已由下一节完成。

- MergeReview inventory stale-success presence ownership 回归硬化：
  - 仅新增 test-only 回归并复用 controlled review-query repository；production 接口与行为未变。
  - 两个 stored warning snapshots 分属 category-conflict 与 low-confidence-reuse。先挂起旧 `Warning` 请求（若应用会得到 2 on / 0 outside），再挂起新 `Warning + Low-confidence reuse` 请求（1 on / 1 outside）。
  - 新请求先成功后，断言 one-item review result、exact-ID 1/1 summary、outside/on markers，并激活本地 `On` 使 inventory 仅保留 reuse snapshot。
  - 旧宽请求随后成功仍不能回滚：latest review count、1/1 summary、active `On`、one-item range 与 reuse-only 可见性全部保留，loading 不会复活。
  - side-effect 锁证明除两次预期 review query 与 filter persistence 外，没有 operations reread、worklist rewrite、governance mutation 或 presence persistence。独立复核确认该 2/0 对 1/1 fixture 能实质捕获 counts/membership/filter 回滚且无 blocker。
  - Operations widget 48 项、`flutter analyze` 零问题、全量 257 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：newest failure 后 older stale success 的 ownership 已由下一节覆盖，并验证 current-context retry 恢复。

- MergeReview inventory newest-failure presence ownership 回归硬化：
  - 仅新增 test-only 镜像回归并复用 controlled review-query repository；production 接口与行为未变。
  - 初始 active `On`；依次挂起旧 `Warning` 与新 `Warning + Low-confidence reuse`。请求开始原子回到 `All`/unavailable，随后最新请求失败。
  - 最新失败后锁定 review error、unavailable summary/item marker、完整两项 inventory、selected All 与禁用 On/Outside；旧成功随后完成仍不得清 error、将 retained page 发布为 current 或重新启用 presence。
  - inline retry 明确查询最新 `Warning + Low-confidence reuse` context；只有该成功可恢复 1 on / 1 outside、category Outside/reuse On markers 与 chips。筛选保持 All，不复活请求前的 On。
  - no-settle review-filter helper 在 pending 布局回收目标 dropdown 时执行有界 lazy-list materialization；只影响测试定位，三条 latest-review race 回归共同通过。
  - 明确锁定 operations reads、worklist writes、meta/presence persistence、governance actions、query count 与 retry filter；独立复核无 blocker。
  - Operations widget 49 项、`flutter analyze` 零问题、全量 258 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：newest success + older stale failure 的 ownership 已由下一节覆盖。

- MergeReview inventory stale-failure presence ownership 回归硬化：
  - 仅新增 controlled review-query 的成功/失败镜像回归；production 接口与行为未变。
  - 旧 broad `Warning` 与新 `Warning + Low-confidence reuse` 同时 pending；新请求先成功，建立 one-item review page、exact-ID 1 on / 1 outside 与正确 markers。
  - 激活 `Outside` 后只显示 category snapshot。旧请求随后失败仍不得发布 error/retry、令 presence unavailable、回滚 latest review count/membership，或重置 active Outside；category-only range/item/marker 全部保持。
  - side-effect 锁证明只有两次预期 review query 与 filter writes；没有 operations reread、worklist rewrite、governance mutation、presence persistence 或残留 loading。独立复核无 blocker。
  - 至此核心双请求结果矩阵已覆盖 latest success + stale success、latest failure + stale success、latest success + stale failure，并保持 exact presence ownership。
  - Operations widget 50 项、`flutter analyze` 零问题、全量 259 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：可区分错误文本的双失败 ownership 已由下一节覆盖，older failure 不能覆盖 newest error，presence 始终保持 All/unavailable。

- MergeReview inventory 双失败 error ownership 回归硬化：
  - 仅新增 test-only 双失败回归，并为 controlled review-query fake 增加可选错误文本；production 接口、逻辑与行为未变。
  - 从 active `On` 开始，依次挂起旧 broad `Warning` 与新 `Warning + Low-confidence reuse`。最新请求以 `LATEST_REVIEW_FAILURE` 失败后，锁定唯一可见 error/retry owner、完整两项 inventory、unavailable summary/item marker、selected All 与禁用 On/Outside。
  - 旧请求随后以 `STALE_REVIEW_FAILURE` 失败，不能覆盖或重复最新错误、取得 retry ownership、改变 inventory membership、重新启用 presence 或改变 unavailable marker。
  - inline retry 只查询最新 filter；pending 清旧错误但 presence 保持 unavailable，current-context success 才恢复 exact-ID 1 on / 1 outside 与 enabled chips，并保持 local All。
  - `app_meta` 基线在 latest failure 与 stale failure 之间捕获，并在 stale completion 后立即比较、retry success 后再次比较；同时锁定 operations reads、review query count、worklist-key writes 与 governance actions。
  - 独立复核发现原先 late-baseline 覆盖盲点；移动断言后复核确认 gap 闭合且无 blocker。
  - Operations widget 51 项、`flutter analyze` 零问题、全量 260 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：out-of-bounds offset 内部 corrective second query 的发布 ownership 已由下一节覆盖。

- MergeReview corrective second-query 发布 ownership 回归硬化：
  - 仅新增 test-only 越界竞态回归、controlled custom-page completion 与长列表测试定位加固；production 接口和逻辑未变。
  - 初始 102 条中，tracked high 位于 offset 0，tracked warning-reuse 位于其外；active local On 只显示 high。held `All` offset 100 primary 收到真实缩水语义的 empty/matching 1 page，合法触发 `All` offset 0 corrective query。
  - corrective pending 时，更新 `Warning` offset 0 请求抢占并先成功，建立 warning-only review、exact-ID 1 on / 1 outside、high Outside/warning On markers 与 active On warning-only inventory。
  - 旧 corrective 随后完成仍不能发布 broad page、令 presence unavailable、反转 membership、重置 local On 或恢复 loading/error。
  - query topology 精确锁定 primary 100 -> corrective 0 -> latest Warning 0；operations reads 不变，仅允许一次 review-filter meta write，worklist-key writes 与 governance mutation 均不增长。
  - custom-page helper 校验 response offset/limit 与 held query 一致；`_expectReviewCount` 复用 lazy-list-aware locator，避免长列表回收 count widget 导致测试导航假失败。
  - 独立复核确认无 correctness/false-pass blocker。Operations widget 52 项、`flutter analyze` 零问题、全量 261 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：stale primary 的 corrective dispatch generation guard 已由下一节完成。

- MergeReview stale-primary corrective dispatch guard：
  - 私有 `_loadReviewPage` 接收 captured generation，并在可选 corrective repository query dispatch 前立即检查 mounted/current ownership。
  - primary 判定越界但已失权时，直接返回 first page 而不新增 read；外层既有 success guard 随即丢弃。ownership check 与 second dispatch 之间没有 `await`，不存在新的交错窗口。
  - failure-first 回归先复现：held `All@100`、newer `Warning@0` 成功、stale shrunken primary 返回后旧实现多发第三个 `All@0`。修复后精确 query suffix 只保留 `All@100`、`Warning@0`。
  - 与上一节形成互补：primary 仍拥有 generation 时允许合法 dispatch `All@0`；若 correction 在途时才失权，其迟到 success/error 继续由外层 guard 隔离，不能发布。
  - dispose 前后的额外 read/state publication 被阻止；primary error 与 owned corrective error 仍进入 outer catch。最新 Warning count/identity、loading/error、operations reads、唯一 filter meta write、worklist-key writes、query topology 与 governance=0 均锁定。
  - 独立复核无 correctness blocker。Operations widget 53 项、`flutter analyze` 零问题、全量 262 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：owned corrective failure 的 inline error/retry 与 distinct recovery 已由下一节覆盖。

- MergeReview owned corrective failure/retry ownership 回归硬化：
  - 仅新增 test-only controlled failure/retry 回归；production 接口与逻辑未变。
  - 102 条 structured fixture 中 tracked high 位于 page 0、tracked warning-reuse 位于其外。请求前先证明 active On selected 且只显示 high，排除后续 All 只是默认态的假通过。
  - owned request 精确走 `All@100 -> All@0`，corrective 以 `OWNED_CORRECTIVE_FAILURE` 失败；当前请求发布唯一 inline error/Retry、停止 loading、review unavailable、完整两项 inventory + selected All、禁用 On/Outside，并令两项 markers 均 unavailable。
  - Retry 必须从 requested offset 重走 `All@100 -> All@0`。第二个 correction 返回 distinct warning-only page，证明恢复来自新响应而非 retained old high page。
  - 恢复后 error/retry/loading 清除、review 为 1/1 total 1；exact membership 从 high On/warning Outside 交换为 high Outside/warning On；All 保持、chips 重启，随后 local On 仅显示 warning。
  - 锁定四次 query 完整 records；operations reads、全部 meta writes、worklist-key writes 与 governance 均不增长，并在 corrective failure 后捕获第二基线隔离 retry 副作用；所有 held pending 都已 settle。
  - 独立复核发现并闭合 final response 与 initial On 两个 false-pass gap，无 blocker。Operations widget 54 项、`flutter analyze` 零问题、全量 263 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：out-of-bounds primary held 期间页面 dispose 的 no-correction/no-exception 生命周期回归已由下一节覆盖。

- MergeReview disposed-primary corrective 生命周期 ownership 回归硬化：
  - 仅新增 test-only 生命周期回归，复用既有 mounted/generation guard；production 接口、逻辑与行为未变。
  - 正常加载 102 条 review 后挂起 `All@100`，再明确 dispose Operations 页面并断言 widget 已不存在；随后让 primary 返回 empty + `matchingCount=1` + offset/limit `100/100`，确保真实进入 corrective 判定。
  - unmounted guard 令精确 query suffix 只含 `All@100`，不派发 `All@0`；primary completer 从 pending 变为 completed，两个 pump 冲刷 continuation 后页面仍不存在，Flutter exception queue 前后均为空。
  - 锁定 operations reads、全部 meta writes、worklist-key writes 与 governance mutation 均不增长；所有正常路径 pending 均 settle。
  - 独立复核确认触发条件、dispose 证明、query topology、Future completion、异常捕获与副作用基线构成最小充分断言，无 blocker。
  - Operations widget 55 项、`flutter analyze` 零问题、全量 264 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：已派发 corrective 在 newer success 后迟到失败的 stale-error ownership 已由下一节覆盖。

- MergeReview stale-corrective-failure ownership 回归硬化：
  - 仅新增 test-only failure 镜像；production 接口、逻辑与行为未变。
  - structured 102 条 fixture 精确形成 `All@100 primary -> All@0 corrective -> Warning@0 newer`；primary 用真实越界 empty page 完成，并在 newer success 前证明 corrective 已派发且仍 pending。
  - newer Warning success 建立 distinct warning-only review、exact-ID 1 on / 1 outside、high Outside/warning On markers 与 active local On warning-only inventory；旧 corrective 失败前 completer 状态为 `[completed, pending, completed]`。
  - 旧 corrective 以唯一 `STALE_CORRECTIVE_FAILURE` 失败后，不得出现唯一文本或 generic error/Retry，不恢复 loading、不令 presence unavailable/disabled、不重置 On，也不改变 review/inventory identity；Flutter exception queue 为空。
  - 三个 held completer 最终均 settle，精确 query suffix 仍为 `All@100 -> All@0 -> Warning@0`。operations reads、worklist-key writes 与 governance 不增长；唯一 meta 增量是 Warning filter persistence，latest-success 后二次基线证明 stale failure 无新增。
  - 独立复核确认 index ownership、异步时序、latest-success 前置状态、active-filter 证据、settle、拓扑与副作用均无 blocker。
  - Operations widget 56 项、`flutter analyze` 零问题、全量 265 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：newer failure + stale corrective failure 的 error/retry ownership 与 current-context recovery 已由下一节完成。

- MergeReview latest-failure stale-corrective error/retry ownership 回归硬化：
  - 仅新增 test-only 四查询 failure/retry 回归；production 接口、逻辑与行为未变。
  - structured 102 条 fixture 精确形成 `All@100 primary -> All@0 corrective -> Warning@0 newer failure -> Warning@0 retry success`；primary 返回真实越界 empty page，并在 newer failure 前证明 corrective 已派发且仍 pending。
  - newer request 以 `LATEST_CORRECTIVE_RACE_FAILURE` 失败后，锁定唯一 error/Retry owner、selected All、完整 inventory、unavailable summary/markers 与禁用 On/Outside。旧 corrective 随后以 `STALE_CORRECTIVE_FAILURE` 失败，不得覆盖/重复 error、夺取 Retry、恢复 presence、重置 local state 或改变 review/inventory。
  - stale failure 前 completer 状态为 `[completed, pending, completed]`，之后三项全 settle 且无 Flutter exception。Retry 固定回到 `Warning@0`，loading 时清除旧 error；current-context success 发布 distinct warning-only page（1 matching/102 total、1 on/1 outside、high Outside/warning On），All 保持并可再选 On 显示 warning。
  - 精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、worklist-key writes、governance 均不增长，仅保留预期 Warning filter meta write。latest failure 后的 metadata baseline 用于捕获 stale failure 侧写。
  - 本地复核覆盖异步 ordering、error/retry ownership、retry context、completer settle、identity/membership markers、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 57 项、`flutter analyze` 零问题、全量 266 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：页面 dispose 后已派发 corrective failure 的生命周期回归已由下一节完成。

- MergeReview disposed corrective failure 生命周期 ownership 回归硬化：
  - 仅新增 test-only 生命周期回归；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 先正常加载，再挂起 `All@100`；primary 返回 empty + `matchingCount=1` + offset/limit `100/100`，真实派发 `All@0` corrective 并证明其仍 pending。
  - Operations page 在 corrective pending 时明确 dispose；随后注入 `DISPOSED_CORRECTIVE_FAILURE`。unmounted path 不发布 error/retry/loading/review state，Flutter exception queue 为空。
  - 两个 held completer 最终均 settle，query suffix 精确仅 `All@100 -> All@0`；operations reads、全部 metadata、worklist-key writes 与 governance mutation 均保持基线。
  - 本地复核确认 corrective 先 dispatch、后 dispose、再 failure 的真实时序与无副作用边界，未发现 blocker。
  - Operations widget 58 项、`flutter analyze` 零问题、全量 267 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：页面 dispose 后已派发 corrective success 的对称生命周期回归已由下一节完成。

- MergeReview disposed corrective success 生命周期 ownership 回归硬化：
  - 仅新增 test-only 生命周期镜像；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 先挂起 `All@100`；primary 返回 empty + `matchingCount=1` + offset/limit `100/100`，真实派发 `All@0` corrective 并证明其仍 pending。
  - Operations page 在 corrective pending 时明确 dispose；随后以正常 broad success 完成 corrective。迟到 success 不重建页面、不发布 review/presence state、不触发 setState exception，Flutter exception queue 为空。
  - 两个 held completer 最终均 settle，query suffix 精确仅 `All@100 -> All@0`；operations reads、全部 metadata、worklist-key writes 与 governance mutation 均保持基线。
  - 本地复核确认 success 在真实 post-dispose 时序执行且无副作用，未发现 blocker。
  - Operations widget 59 项、`flutter analyze` 零问题、全量 268 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending corrective 被 newer failure supersede 后再成功的 ownership 回归已由下一节完成。

- MergeReview stale corrective success after newer failure ownership 回归硬化：
  - 仅新增 test-only corrective-specific failure/success/retry 回归；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> stale All@0 success -> Warning@0 retry`；primary 返回真实越界 empty page，保证 corrective 在 newer failure 前已派发。
  - newer Warning 以 `LATEST_CORRECTIVE_RACE_FAILURE` 失败并取得唯一 error/Retry owner、unavailable review；旧 corrective 随后成功仍不得清 error、发布 broad page、恢复 loading 或改变 retry context。
  - Retry 固定 `Warning@0`；pending 时 count 为 loading 且旧 error 清除，只有 current-context success 发布 1 matching/102 total 的 one-warning page。四个 held completer 全 settle 且无 Flutter exception。
  - 精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、预期 Warning filter meta write 之外的 metadata、worklist-key writes 与 governance 均保持基线。
  - 本地复核确认 stale response 是 latest failure 后真实完成的 corrective success，ownership、retry、settle、identity 与 side-effect baselines 均锁定，未发现 blocker。
  - Operations widget 60 项、`flutter analyze` 零问题、全量 269 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：stale corrective success 在 newer retry 已启动后到达的 current-loading/retry-response ownership 回归已由下一节完成。

- MergeReview stale corrective success during active retry ownership 回归硬化：
  - 仅新增 test-only corrective-specific retry race；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry pending`；primary 返回真实越界 empty page，保证 corrective 在 newer request 前已派发并贯穿 retry 启动保持 pending。
  - current Warning retry 启动后清除旧 error 并显示 loading，旧 `All@0` corrective success 随后返回；它不能停止 current loading、发布 broad page、清/替换 retry context 或 settle current Warning Future，无 Flutter exception。
  - current Warning success 单独发布 1 matching/102 total 的 one-warning page；四个 held completer 全 settle，精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`。
  - operations reads、预期 Warning filter meta write 之外的 metadata、worklist-key writes 与 governance 基线保持不变。
  - 本地复核确认 stale completion 发生在 retry dispatch 之后、current success 之前，loading/Future/identity/topology/side-effect baselines 均锁定，未发现 blocker。
  - Operations widget 61 项、`flutter analyze` 零问题、全量 270 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：stale corrective failure 在 active retry 时到达的 current-loading/error ownership 回归已由下一节完成。

- MergeReview stale corrective failure during active retry ownership 回归硬化：
  - 仅新增 test-only corrective-specific retry race；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry pending`；primary 返回真实越界 empty page，保证 corrective 在 newer request 前已派发并贯穿 retry 启动保持 pending。
  - current Warning retry 启动后清除旧 error 并显示 loading，旧 `All@0` corrective 以 `STALE_CORRECTIVE_FAILURE` 失败；它不能冒泡 error、取得 Retry ownership、停止 current loading 或 settle current Warning Future，无 Flutter exception。
  - current Warning success 单独发布 1 matching/102 total 的 one-warning page；四个 held completer 全 settle，精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`。
  - operations reads、预期 Warning filter meta write 之外的 metadata、worklist-key writes 与 governance 基线保持不变。
  - 本地复核确认 stale failure 发生在 retry dispatch 之后、current success 之前，loading/Future/identity/topology/side-effect baselines 均锁定，未发现 blocker。
  - Operations widget 62 项、`flutter analyze` 零问题、全量 271 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：stale corrective failure 在 current retry success 之后到达的 late-error ownership 回归已由下一节完成。

- MergeReview stale corrective failure after retry success ownership 回归硬化：
  - 仅新增 test-only late-error 回归；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry success`；corrective 在 newer request 前真实派发并保持 pending 到 retry 发布后。
  - current Warning retry 先发布 1 matching/102 total 的 one-warning page 并清除 error/retry/loading；旧 `All@0` 随后以 `STALE_CORRECTIVE_FAILURE` 失败，不能冒泡 error、恢复 Retry/loading、替换页面或改变 selected Warning context，无 Flutter exception。
  - late failure 只 settle 最终 held corrective Future，不新增 query；one-warning page 保持可见，精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`。
  - operations reads、预期 Warning filter meta write 之外的 metadata、worklist-key writes 与 governance 基线保持不变。
  - 本地复核确认 current retry success 先于 stale failure 被观察，page/error/loading/Future/identity/topology/side-effect baselines 均锁定，未发现 blocker。
  - Operations widget 63 项、`flutter analyze` 零问题、全量 272 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：stale corrective success 在 current retry success 之后到达的对称 late-publication ownership 回归已由下一节完成。

- MergeReview stale corrective success after retry success ownership 回归硬化：
  - 仅新增 test-only late-publication 回归；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry success`；corrective 在 newer request 前真实派发并保持 pending 到 retry 发布后。
  - current Warning retry 先发布 1 matching/102 total 的 one-warning page 并清除 error/retry/loading；旧 `All@0` 随后成功，不能重新发布 broad page、改变 selected Warning context、恢复 loading 或改写已发布 identity，无 Flutter exception。
  - late success 只 settle 最终 held corrective Future，不新增 query；one-warning page 保持可见，精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`。
  - operations reads、预期 Warning filter meta write 之外的 metadata、worklist-key writes 与 governance 基线保持不变。
  - 本地复核确认 current retry success 先于 stale success 被观察，page/error/loading/Future/identity/topology/side-effect baselines 均锁定，未发现 blocker。
  - Operations widget 64 项、`flutter analyze` 零问题、全量 273 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：toolbar refresh 后 stale primary/corrective completion 的 ownership 回归已由下一节完成。

- MergeReview toolbar refresh stale corrective failure ownership 回归硬化：
  - 仅新增 test-only toolbar-refresh generation race；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 primary -> All@0 corrective pending -> toolbar Refresh -> All@100 newer request`；primary 返回真实越界 empty，保证 corrective 在 refresh 前真实派发。
  - toolbar refresh newer All@100 发布 `Showing 101-102 of 102 matching review issues (102 total)` 与 `BACKLOG_TARGET`；旧 corrective 以 `STALE_TOOLBAR_CORRECTIVE_FAILURE` 失败，不能冒泡 review error/retry/loading、替换页面或改写当前 offset/identity，无 Flutter exception。
  - late failure 只 settle old corrective Future，不新增 query；精确 query suffix 为 `All@100 -> All@0 -> All@100`，toolbar operations reads 为预期刷新增量且 stale completion 后保持不变。
  - review-filter metadata、worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 corrective 真实派发、refresh generation supersession、newer page publication、stale failure ordering 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 65 项、`flutter analyze` 零问题、全量 274 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：in-flight 越界 primary/corrective 时 Clear review filters/reset 的 ownership 回归已由下一节完成。

- MergeReview Clear review filters stale corrective success ownership 回归硬化：
  - 仅新增 test-only filter-clear generation race；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `High@0 -> High@100 -> High@0 corrective pending -> Clear review filters -> All@0 newer request`；High primary 返回真实越界 empty，保证 corrective 在 Clear 前真实派发。
  - Clear review filters newer All@0 发布 `Showing 1-100 of 102 matching review issues (102 total)` 与 `All severities`；旧 High corrective 随后成功，不能重新发布 High page、恢复 High filter、改写 count/page identity 或冒泡 review error/retry/loading，无 Flutter exception。
  - stale success 只 settle old corrective Future，不新增 query；精确 query suffix 为 `High@0 -> High@100 -> High@0 -> All@0`，operations reads 与 metadata writes 在 stale completion 后保持不变。
  - worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 corrective 真实派发、Clear generation supersession、newer All-page publication、stale success ordering、Future settlement 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 66 项、`flutter analyze` 零问题、全量 275 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：in-flight 越界 primary/corrective 时 saved-view apply 的 ownership 回归已由下一节完成。

- MergeReview saved-view stale corrective failure ownership 回归硬化：
  - 仅新增 test-only saved-view generation race；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `All@100 -> All@0 corrective pending -> saved Warning@0 newer request`；All primary 返回真实越界 empty，保证 corrective 在 saved-view apply 前真实派发。
  - apply `Warning saved` 发布 `Showing 1 of 1 matching review issues (102 total)` 与 `BACKLOG_TARGET`，saved-view chip 保持选中；旧 broad corrective 以 `STALE_SAVED_VIEW_CORRECTIVE_FAILURE` 失败，不能冒泡 review error/retry/loading、替换 Warning page 或清除 saved-view selection，无 Flutter exception。
  - stale failure 只 settle old corrective Future，不新增 query；精确 query suffix 为 `All@100 -> All@0 -> Warning@0`，operations reads 与 filter metadata 在 stale completion 后保持不变。
  - worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 corrective 真实派发、saved-view generation supersession、newer Warning-page publication、stale failure ordering、selection identity 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 67 项、`flutter analyze` 零问题、全量 276 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view re-apply 后 stale corrective failure 的 ownership 回归已由下一条完成。

- MergeReview saved-view re-apply stale corrective failure ownership 回归硬化：
  - 仅新增 test-only saved-view re-apply generation race；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `High@0 -> High@100 -> High@0 corrective pending -> re-apply High saved view@0 newer request`；High primary 返回真实越界 empty，保证 corrective 在 re-apply 前真实派发。
  - re-apply active `High saved` reset offset 并发布 `Showing 1-100 of 101 matching review issues (102 total)`，saved-view chip 保持选中；旧 corrective 以 `STALE_SAVED_VIEW_REAPPLY_CORRECTIVE_FAILURE` 失败，不能冒泡 review error/retry/loading、替换页面或清除 saved-view selection，无 Flutter exception。
  - stale failure 只 settle old corrective Future，不新增 query；精确 query suffix 为 `High@0 -> High@100 -> High@0 -> High@0`，operations reads 与两次预期 filter metadata writes 在 stale completion 后保持不变。
  - worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 corrective 真实派发、re-apply generation supersession、newer High-page publication、stale failure ordering、saved-view identity、Future settlement 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 68 项、`flutter analyze` 零问题、全量 277 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view delete 后 current-context corrective ownership 的回归已由下一条完成。

- MergeReview saved-view delete current corrective ownership 回归硬化：
  - 仅新增 test-only saved-view deletion lifecycle regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `High@0 -> High@100 -> High@0 corrective pending`，随后在 corrective in-flight 时删除 selected `High delete` view；删除只改变 saved-view metadata，不改变 active High filter 或 review generation。
  - selected chip 与 saved-view payload 被移除，High filter 保持 active，且不新增 review query；仍被当前 generation 拥有的 corrective 随后以 `OWNED_SAVED_VIEW_DELETE_CORRECTIVE_FAILURE` 失败，正确显示 review error/Retry 与 unavailable count，而非被当作 stale，无 Flutter exception。
  - owned failure settle 三个 held query Future；精确 query suffix 为 `High@0 -> High@100 -> High@0`，operations reads 保持不变，post-baseline 仅有预期 High filter write 与 saved-view deletion write。
  - worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 saved-view identity removal、active-filter preservation、current-generation ownership、owned failure publication、Future settlement 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 69 项、`flutter analyze` 零问题、全量 278 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view deletion failure 下 identity 保持与 current corrective ownership 的回归已由下一条完成。

- MergeReview saved-view deletion failure current corrective ownership 回归硬化：
  - 仅新增 test-only saved-view deletion failure regression 与 controlled metadata-write failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `High@0 -> High@100 -> High@0 corrective pending`，随后让 selected `High delete failure` view 的删除写入失败；失败不改变 active High filter、saved-view payload、selected chip 或 review generation。
  - deletion failure 以 operation-status message 暴露，不新增 review query，corrective 保持 loading；仍被当前 generation 拥有的 corrective 随后以 `OWNED_SAVED_VIEW_DELETE_FAILURE_CORRECTIVE_FAILURE` 失败，正确显示 review error/Retry 与 unavailable count，saved-view chip 保持 selected，无 Flutter exception。
  - owned failure settle 三个 held query Future；精确 query suffix 为 `High@0 -> High@100 -> High@0`，operations reads 保持不变，成功的 post-baseline metadata write 仅为预期 High filter write。
  - worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 deletion failure attempt、metadata/selection preservation、active-filter identity、current-generation ownership、owned failure publication、Future settlement 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 70 项、`flutter analyze` 零问题、全量 279 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view metadata read failure 下 identity 保持与 current corrective ownership 的回归已由下一条完成。

- MergeReview saved-view metadata read failure current corrective ownership 回归硬化：
  - 仅新增 test-only saved-view metadata read failure regression 与 controlled read-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 精确形成 `High@0 -> High@100 -> High@0 corrective pending`，随后让 selected `High read failure` view 的删除 metadata read 失败；失败不改变 active High filter、saved-view payload、selected chip 或 review generation。
  - deletion read failure 以 operation-status message 暴露，不新增 review query，corrective 保持 loading；仍被当前 generation 拥有的 corrective 随后以 `OWNED_SAVED_VIEW_READ_FAILURE_CORRECTIVE_FAILURE` 失败，正确显示 review error/Retry 与 unavailable count，saved-view chip 保持 selected，无 Flutter exception。
  - owned failure settle 三个 held query Future；精确 query suffix 为 `High@0 -> High@100 -> High@0`，operations reads 保持不变，post-baseline metadata write 仅为预期 High filter write。
  - worklist-key writes 与 governance mutations 均保持不变。
  - 本地复核确认 failed read attempt、metadata/selection preservation、active-filter identity、current-generation ownership、owned failure publication、Future settlement 与 query/side-effect baselines，未发现 blocker。
  - Operations widget 71 项、`flutter analyze` 零问题、全量 280 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view initial metadata read failure 的 fail-open 与 review lane 独立性回归已由下一条完成。

- MergeReview saved-view initial metadata read fail-open 回归硬化：
  - 仅新增 test-only initial saved-view metadata read failure regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High initial read failure` named view，初始化时让 saved-view metadata read 失败；失败仅隔离 saved-view configuration，persisted High filter 仍加载并发布单个 `High@0` page。
  - initialization fail-open 显示 `Could not load saved review views`；不伪造 saved-view chip、不显示 review error，页面发布 `Showing 1-100 of 101 matching review issues (102 total)`，无额外 query 或 metadata write。
  - operations reads 保持初始 tuple `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)`，无 Flutter exception，saved-view read failure 精确观察一次。
  - 本地复核确认 fail-open isolation、persisted-filter identity、saved-view selection absence、single-query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 72 项、`flutter analyze` 零问题、全量 281 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：transient initial saved-view metadata read failure 的 reconstruction recovery 回归已由下一条完成。

- MergeReview transient initial saved-view read recovery 回归硬化：
  - 仅新增 test-only transient initial saved-view metadata read recovery regression 与 controlled fixture 的 read-call counter；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High transient recovery` named view；首个 page instance 的 saved-view metadata read 失败并 fail-open，persisted High filter 仍发布 `High@0` page，且不伪造 chip。
  - 使用同一 repository 重建 page 后，第二次 saved-view read 成功，named saved-view chip 恢复，High filter identity 保持，页面再次发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - failure counter 确认两次 saved-view read 中恰有一次失败；两次 review query 均为 `High@0`，恢复后无 review error、无 Flutter exception、无额外 metadata write。
  - operations reads 仅因预期 page reconstruction 从 `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 变为 `(jobs:2, artifacts:4, logs:2, exports:2, governance:2)`；worklist 与 governance side effects 保持不变。
  - 本地复核确认 fail-open recovery、saved-view identity restoration、persisted-filter continuity、query topology、read-call counts 与 side-effect baselines，未发现 blocker。
  - Operations widget 73 项、`flutter analyze` 零问题、全量 282 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：transient saved-view recovery 隔离 disposed in-flight review request 的 reconstruction race 回归已由下一条完成。

- MergeReview transient saved-view recovery with disposed in-flight request 回归硬化：
  - 仅新增 test-only reconstruction race regression 与 spinner-safe loading assertion helper；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High in-flight recovery` view；首个 page 先启动 held `High@100` request 后被 dispose，replacement page 的 saved-view metadata read 失败并启动 held `High@0` request。
  - dispose 的首个 request 完成后不能改写 replacement page；再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复 saved-view chip 并启动 current `High@0` request。
  - disposed replacement request 随后 settle 但不改变 current page/loading；仅最终 current request 发布 `Showing 1-100 of 101 matching review issues (102 total)`，saved-view identity 恢复。
  - 精确 query topology 为 `[High@0, High@100, High@0, High@0]`；三个 held Future 均 settle，三次 saved-view read 中恰一次失败，无 Flutter exception、无 metadata write；两次预期 reconstruction 使 operations reads 从 `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 变为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`。
  - shared loading helper 在 review spinner active 时避免 `pumpAndSettle`，稳定既有 held saved-view initialization regression，同时保留 loading 断言。
  - 本地复核确认 disposed-request isolation、transient read recovery、saved-view identity restoration、current-generation page ownership、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 74 项、`flutter analyze` 零问题、全量 283 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter mutation recovery 隔离 disposed request 且 saved-view metadata failure 后恢复的 reconstruction race 已由下一条完成。

- MergeReview saved-view read recovery with disposed filter-mutation request 回归硬化：
  - 仅新增 test-only filter-mutation reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High filter 与 `High filter recovery` view；首个 page 将 review filter 改为 Warning、持久化并 hold resulting Warning@0 request 后 dispose。
  - replacement page 的 saved-view metadata read 失败并 hold Warning@0 request；disposed filter-mutation request 完成不能改写 replacement page 或伪造 saved-view chip。
  - 再次 reconstruction 在 replacement request pending 时成功 read saved-view metadata，恢复 saved-view chip 但保持 unselected（persisted active filter 仍为 Warning）；disposed replacement request settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0]`；三个 held Future settle，三次 saved-view read 恰一次失败；post-baseline 仅 filter metadata write，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 filter-mutation persistence、disposed-request isolation、saved-view identity/selection semantics、current-generation ownership、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 75 项、`flutter analyze` 零问题、全量 284 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter mutation recovery 在 saved-view metadata failure 后跨 pending filter write 完成并由 reconstruction 读取 committed filter 的 race 已由下一条完成。

- MergeReview saved-view read recovery with a disposed filter mutation and pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High filter write recovery` view；首个 page 将 review filter 改为 Warning、排队 filter metadata write、hold resulting Warning@0 request 后 dispose。
  - replacement page 在 filter write 仍 pending 时 saved-view metadata read 失败，因此读取 committed High filter 并启动 held High@0 request；disposed Warning@0 request 完成不能改写 replacement page 或伪造 saved-view chip。
  - pending filter write 完成是唯一 post-baseline metadata write 并提交 Warning；再次 reconstruction 在 High@0 仍 pending 时成功读取 committed Warning filter 与 saved-view metadata，恢复 saved-view chip 但保持 unselected，并启动 current Warning@0 request。
  - disposed High@0 request settle 仍不改变 current loading/page；最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0]`；三个 held review-query Future 与 held filter-write Future 均 settle，三次 saved-view read 恰一次失败，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 pending-write persistence、disposed-request isolation、committed-filter continuity、saved-view identity/selection semantics、current-generation ownership、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 76 项、`flutter analyze` 零问题、全量 285 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view read recovery 隔离 failed filter mutation 后 disposed current retry request 的 reconstruction race 已由下一条完成。

- MergeReview saved-view read recovery with a disposed filter retry request 回归硬化：
  - 仅新增 test-only filter-retry reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High filter retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败后启动 held inline retry，再 dispose page。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry request 完成不能改写 replacement page、重新展示旧 failure 或伪造 saved-view chip。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复 saved-view chip 但保持 unselected，并启动 current Warning@0 request；disposed replacement request settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），三次 saved-view read 恰一次失败；post-baseline 仅 filter metadata write，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 failed-filter retry ownership、disposed-request isolation、saved-view identity/selection semantics、current-generation ownership、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 77 项、`flutter analyze` 零问题、全量 286 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：toolbar refresh 在 saved-view read recovery 期间接管 page，隔离 disposed retry 与 stale pre-toolbar request，随后恢复 metadata identity 的 race 已由下一条完成。

- MergeReview toolbar refresh ownership across saved-view read recovery and disposed retry 回归硬化：
  - 仅新增 test-only toolbar/retry/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High toolbar retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 inline retry 后 dispose。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；toolbar Refresh 启动 current Warning@0 request 与完整 operations refresh；disposed retry 与 stale pre-toolbar Warning@0 完成均不能改写 toolbar-owned page。
  - toolbar-owned request 在 saved-view metadata fail-open 下发布 `Showing 1 of 1 matching review issues (102 total)`；后续 reconstruction 成功读取 saved-view metadata，恢复 chip 但保持 unselected，并发布相同 current Warning 结果。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 均 settle（首个为预期 filter failure），三次 saved-view read 恰一次失败；post-baseline 仅 filter metadata write，无 review error/exception；两次 reconstruction 加一次 toolbar refresh 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+3, artifacts:+6, logs:+3, exports:+3, governance:+3)` 增加。
  - 本地复核确认 toolbar generation ownership、failed-filter retry isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 78 项、`flutter analyze` 零问题、全量 287 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view deletion mutation failure 的语义已由下一条完成。

- MergeReview saved-view deletion failure across retry recovery 回归硬化：
  - 仅新增 test-only saved-view deletion/retry reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High delete retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时尝试删除 saved-view。
  - saved-view deletion write 恰失败一次；既有 unselected chip 与 active retry/loading 保持，未记录 deletion write，随后 dispose page。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复 chip 但保持 unselected（persisted view 从未删除），并启动 current Warning@0；disposed replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（deletion mutation 自身先读一次），filter metadata write 是唯一 post-baseline metadata write，saved-view write 恰失败一次且无 persisted write，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 deletion-failure identity preservation、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 79 项、`flutter analyze` 零问题、全量 288 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view deletion success 的语义已由下一条完成。

- MergeReview saved-view deletion success across retry recovery 回归硬化：
  - 仅新增 test-only saved-view deletion/retry reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High delete success retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时删除 saved-view。
  - deletion 恰成功一次：saved-view metadata 持久化为空列表，chip 消失，active retry/loading 保持，随后 dispose page。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry 完成不能复活已删除 chip 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取空的 saved-view metadata；deleted view 保持 absent，current Warning@0 继续拥有 page。disposed replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（successful deletion mutation 自身先读一次），filter metadata write 与 empty saved-view write 是唯一 post-baseline metadata writes，无 saved-view write failure、无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 deletion-success persistence、absence identity、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 80 项、`flutter analyze` 零问题、全量 289 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view apply success 的语义已由下一条完成。

- MergeReview saved-view apply success across retry recovery 回归硬化：
  - 仅新增 test-only saved-view apply/retry reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High apply success retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时应用 saved High view。
  - apply saved view 持久化 High、启动新的 High@0 request 并选中 chip；active Warning retry 仍 held，随后 dispose page。
  - replacement page 的 saved-view metadata read 失败并启动 held High@0 request；disposed Warning retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复 chip 但保持 present/unselected，并启动 current High@0；disposed apply request 与旧 replacement request settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle（首个为预期 filter failure），三次 saved-view read 恰一次失败；两次 filter metadata write 是唯一 post-baseline metadata writes，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 apply-success generation ownership、selection identity、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 81 项、`flutter analyze` 零问题、全量 290 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view apply failure 的语义已由下一条完成。

- MergeReview saved-view apply failure across retry recovery 回归硬化：
  - 仅新增 test-only saved-view apply/filter-write/reconstruction race regression 与 controlled filter-write failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High apply failure retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时应用 saved High view。
  - in-memory apply 启动 High@0 并选中 saved-view chip，但 filter metadata write 恰失败一次；仅 earlier Warning filter write 保持 committed，active page 持续 loading 后 dispose。
  - replacement page 的 saved-view metadata read 失败，按 committed Warning filter 恢复并启动 held Warning@0；disposed Warning retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复 chip 但保持 present/unselected（当前 committed filter 仍为 Warning），并启动 current Warning@0；disposed High apply request 与旧 replacement request settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, Warning@0, Warning@0]`；五个 held review-query Future 均 settle（首个为预期 filter failure），三次 saved-view read 恰一次失败；一次 filter metadata write 成功、一次 apply write 失败，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 apply-failure persistence boundary、in-memory selection identity、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 82 项、`flutter analyze` 零问题、全量 291 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view save success 的语义已由下一条完成。

- MergeReview saved-view save success across retry recovery 回归硬化：
  - 仅新增 test-only saved-view save/retry reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High save success retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时保存新的 `Warning saved during retry` view。
  - save 恰成功一次，将新 Warning view 与既有 High view 一并持久化；active retry/loading 保持，新 chip present 但 unselected，随后 dispose page。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复新 chip 为 present/unselected，并启动 current Warning@0；disposed replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（save mutation 自身先读一次），Warning filter write 与 saved-view write 是唯一 post-baseline metadata writes，无 mutation failure、无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 save-success persistence、新 view identity、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 83 项、`flutter analyze` 零问题、全量 292 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view save failure 的语义已由下一条完成。

- MergeReview saved-view save failure across retry recovery 回归硬化：
  - 仅新增 test-only saved-view save/retry reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High save failure retry recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时尝试保存新 view。
  - saved-view write 恰失败一次；无新 chip 或 saved-view metadata write，既有 High view 保持 present/unselected，committed Warning filter 与 active retry/loading 保持。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，恢复既有 High view 为 present/unselected，并启动 current Warning@0；disposed replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（failed save mutation 自身先读一次），Warning filter write 是唯一 post-baseline metadata write，saved-view write 恰失败一次且无 persistence，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 save-failure identity preservation、committed-filter continuity、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 84 项、`flutter analyze` 零问题、全量 293 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：save failure 后 metadata-read success 在 active retry/reconstruction recovery 中的语义已由下一条完成。

- MergeReview save failure with immediate successful reconstruction read 回归硬化：
  - 仅新增 test-only post-save-failure reconstruction regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High save failure success read` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时尝试保存新 view。
  - saved-view write 在 metadata read 后恰失败一次；无新 view persistence 或 chip，既有 High view 保持 present/unselected，committed Warning filter 与 active retry/loading 保持。
  - reconstruction 立即成功读取 saved-view metadata 并启动 held Warning@0；disposed retry 完成不能重新展示旧 failure 或改写 reconstructed page，既有 view 保持 present/unselected。
  - 仅 current Warning request 发布 `Showing 1 of 1 matching review issues (102 total)`，无 review error 或 Flutter exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0]`；三个 held review-query Future 均 settle（首个为预期 filter failure），三次 saved-view read 无 read failure；Warning filter write 是唯一 post-baseline metadata write，saved-view write 恰失败一次且无 persistence；一次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+1, artifacts:+2, logs:+1, exports:+1, governance:+1)` 增加。
  - 本地复核确认 failed-save identity preservation、immediate read recovery、committed-filter continuity、active retry ownership、disposed-request isolation、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 85 项、`flutter analyze` 零问题、全量 294 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：disposed in-flight saved-view save 在 read recovery 前完成并持久化新 view 的语义已由下一条完成。

- MergeReview disposed saved-view save completion before read recovery 回归硬化：
  - 仅新增 test-only pending saved-view-write/disposal/reconstruction race regression 与 controlled saved-view-write fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High disposed save recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时开始保存 `Warning disposed save recovery`。
  - saved-view write 在 page dispose 时仍 pending；dispose 后完成该 Future 是唯一 saved-view mutation completion，持久化新 Warning view，disposed save callback 不能更新 UI。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取已持久化的新 view，恢复 chip 为 present/unselected，并启动 current Warning@0；disposed replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（pending save mutation 自身先读一次），Warning filter write 与 completed saved-view write 是唯一 post-baseline metadata writes，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 pending-write settlement、disposed-save callback isolation、新 view persistence、active retry ownership、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 86 项、`flutter analyze` 零问题、全量 295 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：disposed in-flight saved-view save 在 read recovery 前完成并持久化新 view 的语义已由下一条完成。

- MergeReview disposed saved-view save completion before read recovery 回归硬化：
  - 仅新增 test-only pending saved-view-write/disposal/reconstruction race regression 与 controlled saved-view-write fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High disposed save recovery` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时开始保存 `Warning disposed save recovery`。
  - saved-view write 在 page dispose 时仍 pending；dispose 后完成该 Future 是唯一 saved-view mutation completion，持久化新 Warning view，disposed save callback 不能更新 UI。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0 request；disposed retry 完成不能重新展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取已持久化的新 view，恢复 chip 为 present/unselected，并启动 current Warning@0；disposed replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（pending save mutation 自身先读一次），Warning filter write 与 completed saved-view write 是唯一 post-baseline metadata writes，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 pending-write settlement、disposed-save callback isolation、新 view persistence、active retry ownership、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 86 项、`flutter analyze` 零问题、全量 295 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending saved-view deletion 在 save completion 前 gate，完成 save 后再删除旧 view，并在 reconstruction 中保留新 view 的语义已由下一条完成。

- MergeReview pending saved-view save with deletion gate and recovery 回归硬化：
  - 仅新增 test-only pending saved-view-write/deletion/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending save delete` view；首个 page 将 review filter 改为 Warning，Warning@0 request 失败、启动 held inline retry，并在 retry active 时开始保存 `Warning pending save then delete`。
  - saved-view write pending 期间，既有 view 的 delete control absent/blocked，且没有 deletion metadata write；完成 save 后持久化新 Warning view，随后才在 active retry 期间删除旧 High view。
  - deletion 后 persisted list 仅含新 Warning view，旧 chip 消失、新 chip 保留；replacement page 的 saved-view metadata read 失败并启动 held Warning@0，disposed retry 完成不能展示旧 failure 或改写 replacement page。
  - 再次 reconstruction 在 replacement request 仍 pending 时成功读取 saved-view metadata，仅恢复新 view 为 present/unselected，并启动 current Warning@0；stale replacement settle 仍不改变 current loading/page，最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），五次 saved-view read 恰一次失败；Warning filter write、一次 save 与一次 delete 是唯一 post-baseline metadata writes，无 review error/exception；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认 deletion gate、save/delete sequencing、新 view persistence、旧 view removal、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 87 项、`flutter analyze` 零问题、全量 296 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter metadata write pending 时 saved-view deletion 独立完成，随后 reconstruction 保持 deletion identity 的语义已由下一条完成。

- MergeReview saved-view deletion independent from pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/saved-view-deletion/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter delete` view；首个 page 将 review filter 改为 Warning，挂起 filter metadata write，Warning@0 request 失败并启动 held inline retry。
  - filter metadata write 仍 pending 时，saved-view deletion 独立完成：saved-view metadata write 先完成、chip 消失、current page retry/loading 保持；随后完成 held filter write，持久化 Warning 且不覆盖 empty saved-view list。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0；disposed retry 完成不能恢复已删除 view 或改写 replacement page。再次 reconstruction 成功 read 后仍保持 deleted view absent，current Warning@0 负责最终发布。
  - stale replacement settle 仍不改变 current loading/page；最终仅 current request 发布 `Showing 1 of 1 matching review issues (102 total)`，无 review error 或 Flutter exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败；post-baseline metadata writes 依次为一次 saved-view delete 与一次 Warning filter write；两次 intentional reconstruction 使 operations reads 从 baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 按 `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)` 增加。
  - 本地复核确认独立 metadata-key sequencing、deletion persistence、filter-write settlement、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 88 项、`flutter analyze` 零问题、全量 297 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter metadata write pending 时 saved-view apply 排队并由当前 query 接管，reconstruction 保持 view 存在但不伪造选中状态的语义已由下一条完成。

- MergeReview saved-view apply queued behind pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/saved-view-apply/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High filter 与 High/Warning saved views；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held retry；随后 apply High saved view，排队 High filter write 并启动 current High query。
  - stale Warning retry failure 在 High saved-view apply 接管后被忽略；释放 filter-write queue 后依次持久化 Warning、High，最终 High filter 不被覆盖，current page High chip selected，并发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - replacement page 的 saved-view metadata read 失败并启动 held High@0；成功 reconstruction 恢复两个 saved view 为 present/unselected（selection 为 page-local），stale replacement settle 不能改写 current page，最终仅 current High@0 发布。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle（首个 filter request 与 retry 为预期 stale failure），三次 saved-view read 恰一次失败；两次 post-baseline metadata writes 依次为 Warning、High filter payload。
  - 本地复核确认 filter-write queue ordering、apply ownership、stale failure isolation、最终 filter persistence、reconstruction presence/selection 语义、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 89 项、`flutter analyze` 零问题、全量 298 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter metadata write pending 时 saved-view save 独立完成，随后 reconstruction 保持两个 view 与 committed filter 的语义已由下一条完成。

- MergeReview saved-view save independent from pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/saved-view-save/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter save` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning pending filter save` 独立完成：saved-view read/write 持久化新 Warning view、新 chip 出现、current retry/loading ownership 不变；释放 filter write 后持久化 Warning，两个 view 均不被覆盖。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0；disposed retry 完成不能移除或改写两个 view。成功 reconstruction 恢复两个 view 为 present/unselected（selection page-local），仅 current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（save mutation 自身先读一次）；post-baseline metadata writes 依次为一次 saved-view save 与一次 Warning filter write。
  - 本地复核确认独立 metadata-key sequencing、saved-view persistence、filter-write settlement、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 90 项、`flutter analyze` 零问题、全量 299 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter metadata write pending 时 saved-view save failure 不污染既有 view，filter write 仍可 settle，reconstruction 保持 identity 的语义已由下一条完成。

- MergeReview saved-view save failure with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/saved-view-save-failure/reconstruction race regression 与 controlled mutation-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter save failure` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - 新 Warning saved-view save 在 metadata read 后恰失败一次，且 filter write 仍 pending：无新 chip 或 saved-view write，既有 view 保持 present/unselected，current retry/loading ownership 不变；释放 filter write 后独立持久化 Warning。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0；disposed retry 完成不能展示 failed save 或改写 replacement page。成功 reconstruction 仅恢复既有 view 为 present/unselected，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（failed save mutation 自身先读一次）；唯一 post-baseline metadata write 为 Warning filter payload，saved-view write 恰失败一次且无 persistence。
  - 本地复核确认 mutation-failure isolation、pending filter-write settlement、既有 view identity、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 91 项、`flutter analyze` 零问题、全量 300 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter metadata write pending 时 saved-view deletion failure 不污染既有 view，filter write 仍可 settle，reconstruction 保持 identity 的语义已由下一条完成。

- MergeReview saved-view deletion failure with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/saved-view-deletion-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter delete failure` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - saved-view deletion 在 metadata read 后恰失败一次且 filter write 仍 pending：无 saved-view write，既有 chip 保持 present/unselected，current retry/loading ownership 不变；释放 filter write 后独立持久化 Warning。
  - replacement page 的 saved-view metadata read 失败并启动 held Warning@0；disposed retry 完成不能展示 deletion failure 或改写 replacement page。成功 reconstruction 恢复既有 view 为 present/unselected，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），四次 saved-view read 恰一次失败（failed deletion 自身先读一次）；唯一 post-baseline metadata write 为 Warning filter payload，saved-view delete 恰尝试一次且无 persistence。
  - 本地复核确认 mutation-failure isolation、pending filter-write settlement、既有 view identity、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、current-page publication、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 92 项、`flutter analyze` 零问题、全量 301 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending filter write 时 save→delete 两个 saved-view mutation 按 store 顺序完成，最终仅新 view 保留并在 reconstruction 中恢复的语义已由下一条完成。

- MergeReview saved-view save then deletion with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/two-saved-view-mutations/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter save delete` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning pending filter save delete` 完成，随后 serialized saved-view store 删除旧 High view；旧 chip 消失、新 chip 保留，current retry/loading ownership 不变。
  - 释放 filter write 后独立持久化 Warning；最终 saved-view payload 仅含新 Warning view。replacement page 的 saved-view read 失败后，成功 reconstruction 仅恢复新 view 为 present/unselected。
  - disposed retry 完成不能复活旧 view 或改写 replacement page；仅 current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`，无 review error 或 Flutter exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），五次 saved-view read 恰一次失败；三次 post-baseline metadata writes 依次为 saved-view save、saved-view delete、Warning filter。
  - 本地复核确认 saved-view serialization、独立 filter-write ordering、最终 persistence identity、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 93 项、`flutter analyze` 零问题、全量 302 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending filter write 时 save 成功、delete 失败仍保留 prior save，filter write 可 settle，reconstruction 保持两个 view identity 的语义已由下一条完成。

- MergeReview saved-view deletion failure after prior save with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/save-success/delete-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter save delete failure` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning pending filter save delete failure` 成功；随后旧 High view deletion 在 metadata read 后恰失败一次。旧/新 view 均保持 present/unselected，无 failed deletion write，current retry/loading ownership 不变。
  - 释放 filter write 后独立持久化 Warning；replacement page 的 saved-view read 失败并启动 held Warning@0；成功 reconstruction 恢复两个 view 为 present/unselected，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - disposed retry 完成不能展示 deletion failure 或改写 reconstructed page，无 review error 或 Flutter exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），五次 saved-view read 恰一次失败；两次 post-baseline writes 为成功 saved-view save 与 Warning filter，failed deletion 恰尝试一次且无 persistence。
  - 本地复核确认 prior-save retention、deletion-failure isolation、独立 filter-write settlement、active retry ownership、disposed-request isolation、saved-view fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 94 项、`flutter analyze` 零问题、全量 303 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending filter write 时 first saved-view save failure 不阻塞 following delete，最终 empty list 在 reconstruction 中保持的语义已由下一条完成。

- MergeReview failed saved-view save followed by deletion with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/save-failure/delete-success/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter failed save delete` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - 首次 Warning saved-view save 在 metadata read 后恰失败一次且 filter write 仍 pending，无新 view persistence；随后 saved-view store delete 成功清空旧 view，current retry/loading ownership 不变。
  - 释放 filter write 后独立持久化 Warning；replacement page 的 saved-view read 失败并启动 held Warning@0；成功 reconstruction 保持 saved-view list empty，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - disposed retry 完成不能复活已删除 view 或改写 replacement page，无 review error 或 Flutter exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），五次 saved-view read 恰一次失败；post-baseline metadata writes 为一次成功 saved-view delete 后一次 Warning filter，failed save 恰尝试一次且无 persistence。
  - 本地复核确认 failed-first-mutation recovery、saved-view queue drainage、独立 filter-write settlement、deleted identity、active retry ownership、disposed-request isolation、fail-open/recovery identity、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 95 项、`flutter analyze` 零问题、全量 304 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending filter write 时 delete 成功后 save 失败仍 drain saved-view queue，最终 empty list 在 reconstruction 中保持的语义已由下一条完成。

- MergeReview deletion followed by failed save with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/delete-success/save-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter delete save failure` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时删除旧 High view 成功，随后 Warning saved-view save 在 metadata read 后恰失败一次；list 保持 empty，无 failed save persistence，current retry/loading ownership 不变。
  - 释放 filter write 后独立持久化 Warning；replacement page 的 saved-view read 失败并启动 held Warning@0；成功 reconstruction 保持 empty list，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - disposed retry 完成不能复活已删除 view 或改写 replacement page，无 review error 或 Flutter exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），五次 saved-view read 恰一次失败；post-baseline metadata writes 为一次成功 saved-view delete 后一次 Warning filter，failed save 恰尝试一次且无 persistence。
  - 本地复核确认 first-mutation 后 queue drainage、second-mutation failure isolation、独立 filter-write settlement、empty-list identity、active retry ownership、disposed-request isolation、fail-open/recovery identity、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 96 项、`flutter analyze` 零问题、全量 305 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending filter write 时 first save 成功、同名 second save 失败仍保留 first view，filter write 可独立 settle，reconstruction 保持两个 view identity 的语义已由下一条完成。

- MergeReview 同名 second saved-view save failure with pending filter write 回归硬化：
  - 仅新增 test-only pending filter-write/double-save/reconstruction race regression 与 controlled mutation-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter double save` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning pending filter double save` 成功；同名第二次 save 在 metadata read 后恰失败一次。第一次 saved view 保持 persisted/present，无第二次 saved-view write，current retry/loading ownership 不变。
  - 释放 filter write 后独立持久化 Warning；replacement page 的 saved-view read 失败并启动 held Warning@0；成功 reconstruction 恢复两个 view 为 present/unselected（selection page-local）。disposed retry/replacement request 完成不能展示 second-save failure 或改写 current page，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 均 settle（首个为预期 filter failure），五次 saved-view read 恰一次失败；post-baseline metadata writes 依次为一次成功 saved-view save 与一次 Warning filter，second save 恰尝试一次且无 persistence。
  - 本地复核确认 first-save retention、同名 second-save failure isolation、独立 filter-write settlement、active retry ownership、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 97 项、`flutter analyze` 零问题、全量 306 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：pending filter write 在 successful saved-view save 后释放并失败时，不回滚 saved-view persistence，保留旧 persisted filter authority，filter-write failure 可见且 reconstruction 保持两个 view identity 的语义已由下一条完成。

- MergeReview saved-view save 后 pending filter write failure 回归硬化：
  - 仅新增 test-only pending filter-write/release-failure/reconstruction race regression 与 controlled post-release filter-write-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High pending filter write failure after save` view；首个 page 改为 Warning，挂起 Warning filter metadata write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning pending filter write failure after save` 成功；释放该 write 后恰失败一次，Operation status 显示 filter persistence failure，无 filter payload 落盘；persisted filter 仍为 High，两个 saved view 均 present，current retry/loading ownership 不变。
  - replacement page 的 saved-view read 失败并因旧 High filter 启动 held High@0；成功 reconstruction 恢复两个 view 为 present/unselected（selection page-local）。disposed retry/replacement completion 不能展示 filter failure 或改写 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0]`；四个 held review-query Future 均 settle，四次 saved-view read 恰一次失败；post-baseline 仅一次成功 saved-view write，failed filter write 恰尝试一次且无 persistence。
  - 本地复核确认 filter-write failure visibility、saved-view persistence retention、独立 queue settlement、active retry ownership、disposed-request isolation、persisted-filter authority、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 98 项、`flutter analyze` 零问题、全量 307 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：首个 filter write 失败后，queued 后续 filter write 仍成功，saved-view mutation 仍保持 queued 并最终持久化，cross-queue ownership 与 reconstruction identity 的语义已由下一条完成。

- MergeReview filter-write failure recovery with queued saved-view mutation 回归硬化：
  - 仅新增 test-only cross-queue pending filter-write/failure-recovery/queued-saved-view/reconstruction race regression 与 controlled failure-then-success fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High filter failure queued save` view；首个 page 改为 Warning，挂起首个 Warning filter metadata write，Warning@0 失败并启动 held retry。
  - `Warning filter failure queued save` saved-view save 在 serialized store 中保持 pending；随后 filter 改回 High，第二个 High filter write queued。释放首个 write 后恰失败一次，queued High write 仍成功，而 saved-view write 继续 pending。
  - filter failure 显示于 Operation status，persisted filter 为 High，retry/loading ownership 不变；释放 saved-view write 后在成功 High filter write 之后持久化两个 view。
  - replacement page 的 saved-view read 失败并启动 held High@0；成功 reconstruction 恢复两个 view 为 present/unselected（selection page-local）。disposed Warning/High request 与 stale replacement request 不能覆盖 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle，四次 saved-view read 恰一次失败；post-baseline metadata writes 依次为成功 High filter 与 saved-view payload。
  - 本地复核确认 first-filter failure isolation、later-filter recovery、cross-queue independence、saved-view persistence retention、active retry ownership、disposed-request isolation、persisted-filter authority、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 99 项、`flutter analyze` 零问题、全量 308 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter-write failure recovery 期间 queued saved-view deletion 保持 pending，后续 High filter write 成功后 deletion 再独立 drain，最终 empty list 与 reconstruction identity 的语义已由下一条完成。

- MergeReview filter-write failure recovery with queued saved-view deletion 回归硬化：
  - 仅新增 test-only cross-queue pending filter-write/queued-deletion/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High filter failure queued delete` view；saved-view deletion 在 metadata read 后保持 pending，chip 仍 present、payload 不变。
  - deletion pending 时 page 改为 Warning，Warning@0 失败并 retry，再改回 High；释放首个 filter write 后恰失败一次，queued High write 仍成功，saved-view deletion 继续 pending，current retry/loading ownership 不变。
  - filter failure 显示于 Operation status；释放 deletion 后在成功 High filter write 之后持久化 empty saved-view payload，chip 消失且 persisted filter authority 保持 High。
  - replacement page 的 saved-view read 失败并启动 held High@0；成功 reconstruction 保持 saved-view list empty。disposed Warning/High request 与 stale replacement request 不能覆盖 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle，四次 saved-view read 恰一次失败；post-baseline metadata writes 依次为成功 High filter 与 saved-view delete payload。
  - 本地复核确认 first-filter failure isolation、later-filter recovery、queued deletion retention/drainage、cross-queue independence、persisted-filter authority、active retry ownership、disposed-request isolation、fail-open/recovery identity、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 100 项、`flutter analyze` 零问题、全量 309 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter-write failure recovery 期间 queued saved-view apply 保留 current-page selected ownership，后续 High write 成功，reconstruction 清除 page-local selection 的语义已由下一条完成。

- MergeReview queued saved-view apply after filter-write failure 回归硬化：
  - 仅新增 test-only queued saved-view-apply/filter-write-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High/Warning saved views 与 High persisted filter；首个 page 改为 Warning，挂起首个 Warning filter metadata write，Warning@0 失败并启动 held retry。
  - 应用 High saved view 后 queued High filter write 排在 pending Warning write 之后，current High@0 启动且 High chip 在当前 page selected；释放首个 write 恰失败一次，queued High write 成功，selected ownership 与 current retry 状态保持一致。
  - filter failure 显示于 Operation status；replacement page 的 saved-view read 失败并启动 held High@0；成功 reconstruction 恢复两个 view 为 present/unselected（selection page-local）。disposed Warning/High request 不能覆盖 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle，三次 saved-view read 恰一次失败；post-baseline 仅成功 High filter write，首个 Warning write 恰失败一次且无 persistence。
  - 本地复核确认 queued apply ownership、first-filter failure isolation、later-filter recovery、selected-page semantics、persisted-filter authority、disposed-request isolation、fail-open/recovery identity、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 101 项、`flutter analyze` 零问题、全量 310 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：queued saved-view apply 在 deletion pending 与首个 filter write failure 期间保持 current-page ownership，后续 High write 与 deletion 依序完成，reconstruction 仅保留 High identity 的语义已由下一条完成。

- MergeReview queued apply with pending deletion during filter failure 回归硬化：
  - 仅新增 test-only queued apply/pending deletion/filter-write-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High/Warning saved views 与 High persisted filter；Warning view deletion 在 metadata read 后保持 pending，两个 chip present、saved-view payload 不变。
  - deletion pending 时 page 改为 Warning，Warning@0 失败并 retry，再应用 High saved view；High write 排在失败的 Warning write 之后，释放首个 write 恰失败一次，High 成功持久化且 current High chip selected。
  - 释放 deletion 后仅 High view 持久化，Warning chip 消失；replacement page 的 saved-view read 失败后，成功 reconstruction 仅恢复 High 为 present/unselected（selection page-local）。disposed Warning/High request 与 stale replacement request 不能覆盖 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle，四次 saved-view read 恰一次失败；post-baseline metadata writes 依次为成功 High filter 与 saved-view delete payload。
  - 本地复核确认 queued apply ownership、pending deletion retention/drainage、first-filter failure isolation、later-filter recovery、persisted-filter authority、page-local selection、disposed-request isolation、fail-open/recovery identity、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 102 项、`flutter analyze` 零问题、全量 311 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter failure 后 repeated queued apply 仍按序完成，pending deletion 最终 drain 且仅移除目标 view，reconstruction 保持最终 identity 与 page-local selection 语义已由下一条完成。

- MergeReview repeated queued applies with pending deletion after filter failure 回归硬化：
  - 仅新增 test-only repeated-apply/pending-deletion/multi-filter-write/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High/Warning/Info saved views 与 High persisted filter；Info deletion 在 metadata read 后保持 pending，三个 chip present、saved-view payload 不变。
  - deletion pending 时 page 改为 Warning，Warning@0 失败并 retry，再依次应用 High、Warning saved view；两个 queued filter write 在首个 Warning write failure 后仍按序持久化，current Warning chip selected，deletion 继续 pending。
  - 释放 deletion 后仅 High/Warning views 持久化；replacement page 的 saved-view read 失败并启动 held Warning@0，成功 reconstruction 恢复 High/Warning 为 present/unselected，Info 缺失（selection page-local）。disposed request 不能覆盖 current page，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；六个 held review-query Future 均 settle，四次 saved-view read 恰一次失败；post-baseline metadata writes 依次为 High filter、Warning filter 与 saved-view delete payload。
  - 本地复核确认 repeated apply ordering、pending deletion retention/drainage、first-filter failure isolation、later-filter recovery、persisted-filter authority、current-page selection、page-local reconstruction semantics、disposed-request isolation、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 103 项、`flutter analyze` 零问题、全量 312 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter write failure 后 successful saved-view save 与 subsequent delete 仍保持 queue ownership，reconstruction 仅保留原 High identity 的语义已由下一条完成。

- MergeReview saved-view mutations recover after filter-write failure 回归硬化：
  - 仅新增 test-only pending filter-write/save-success/delete-after-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High mutations after filter failure` view；首个 page 改为 Warning，挂起 Warning filter write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning mutations after filter failure` view 成功；释放 filter write 后恰失败一次且无 filter payload 落盘，saved view 保持 present，persisted filter 仍为 High。
  - filter failure 后删除新 Warning view 成功，最终仅原 High view；replacement saved-view read 失败并启动 held High@0，successful reconstruction 恢复 High present/unselected（selection page-local）。
  - disposed/replacement request 完成不能复活已删除 view 或改写 current page；仅 current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0]`；四个 held review-query Future 均 settle，五次 saved-view read 恰一次失败；post-baseline writes 依次为 saved-view save 与 saved-view delete，failed filter write 恰尝试一次且无 persistence。
  - 本地复核确认 saved-view mutation recovery、filter-write failure isolation、persisted-filter authority、active retry ownership、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 104 项、`flutter analyze` 零问题、全量 313 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：filter-write failure 后 repeated saved-view save/delete attempts 仍按序 drain，最终 persisted identity 与 reconstruction 语义已由下一条完成。

- MergeReview repeated saved-view mutations survive filter-write failure 回归硬化：
  - 仅新增 test-only repeated saved-view save/delete/filter-failure/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High repeated mutations after filter failure` view；首个 page 改为 Warning，挂起 Warning filter write，Warning@0 失败并启动 held inline retry。
  - filter write pending 时保存 `Warning before filter failure repeated` 成功；释放 filter write 后恰失败一次且无 filter payload 落盘，persisted filter 仍为 High，failure status 可见。
  - filter failure 后依次 save/delete 第一个 Warning view，再 save/delete 第二个 Warning view；每次 mutation 按序 drain，最终 persisted list 仅保留原 High 与 pre-failure Warning view。
  - replacement saved-view read 失败并启动 held High@0；successful reconstruction 恢复两个 view 为 present/unselected（selection page-local）。disposed/replacement request 不能复活已删除 view 或改写 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0]`；四个 held review-query Future 均 settle，八次 saved-view read 恰一次失败；post-baseline writes 为 pre-failure save、save/delete/save/delete，failed filter write 恰尝试一次且无 persistence。
  - 本地复核确认 repeated mutation ordering、post-failure queue ownership、filter-write failure isolation、persisted-filter authority、saved-view identity retention、active retry ownership、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 105 项、`flutter analyze` 零问题、全量 314 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：saved-view save 在 filter failure/recovery 期间保持 pending，随后 delete 仍按序 drain 且 persisted filter authority 不变的语义已由下一条完成。

- MergeReview saved-view save/delete queue survives filter-write failure recovery 回归硬化：
  - 仅新增 test-only saved-view save/delete + queued filter-failure/recovery/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High save delete filter recovery` view；首个 page 改为 Warning，挂起 Warning filter write，Warning@0 失败并启动 held inline retry。
  - 新 Warning saved-view write 在 page 改回 High 并 queued 第二个 filter write 时保持 pending；释放首个 filter write 恰失败一次，queued High filter write 成功，而 saved-view write 仍 pending。
  - 完成 saved-view write 后两个 view 持久化；随后删除旧 High view，下一次 serialized saved-view mutation 成功 drain，最终仅保留新 Warning view。failed filter write 无 payload，persisted filter authority 仍为 High。
  - replacement saved-view read 失败并启动 held High@0；successful reconstruction 仅恢复新 Warning 为 present/unselected（selection page-local）。disposed/replacement request 不能复活旧 High view 或改写 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 均 settle，五次 saved-view read 恰一次失败；post-baseline writes 依次为成功 High filter 与 saved-view save/delete，failed filter write 恰尝试一次且无 persistence。
  - 本地复核确认 cross-queue failure/recovery ordering、saved-view save/delete serialization、persisted-filter authority、saved-view identity retention、active retry ownership、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 106 项、`flutter analyze` 零问题、全量 315 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：recovery 后再次 filter failure 时第二个 saved-view mutation 保持 pending，最终成功并保留两项 Warning identity 的语义已由下一条完成。

- MergeReview later filter failure isolates a queued saved-view mutation 回归硬化：
  - 仅新增 test-only repeated cross-queue filter-failure/saved-view-mutation/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与 `High later filter failure` view；首轮 Warning filter write 失败，held Warning retry 保持 active，首个 Warning saved-view write pending 时 queued High filter write 成功 recovery。
  - 完成首个 saved-view write 并删除旧 High view 后仅剩一个 Warning view；随后再次触发 Warning filter write failure，第二个 Warning saved-view write 保持 pending，完成后两个 Warning view 均持久化，第二次 failed filter write 无 payload。
  - persisted filter authority 保持 High，第二次 filter failure 可见；replacement saved-view read 失败并启动 held High@0，successful reconstruction 恢复两个 Warning 为 present/unselected（selection page-local）。disposed/replacement request 不能复活旧 High 或改写 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, Warning@0, High@0, Warning@0, High@0, High@0]`；六个 held review-query Future 均 settle，六次 saved-view read 恰一次失败；post-baseline writes 依次为 High filter、saved-view save、saved-view delete、saved-view save，两次 failed filter write 均无 persistence。
  - 本地复核确认 repeated cross-queue failure isolation、later saved-view queue ownership、saved-view identity retention、persisted-filter authority、active retry ownership、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 107 项、`flutter analyze` 零问题、全量 316 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：later filter failure 后 saved-view deletion 与第三次 filter recovery 保持独立，deleted identity 不会复活的语义已由下一条完成。

- MergeReview saved-view deletion survives third filter recovery after later failure 回归硬化：
  - 仅新增 test-only later-filter-failure/queued-deletion/third-filter-recovery/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与两个 Warning saved view；首个 Warning filter write 成功，随后 later High filter write 恰失败一次，persisted authority 保持 Warning，failure status 可见。
  - 第三次 Warning filter write 保持 pending 时删除第二个 Warning view；deletion 先持久化，随后第三次 filter write 成功，deleted view 保持 absent，最终仅第一项 Warning view。
  - replacement saved-view read 失败并启动 held Warning@0；successful reconstruction 仅恢复第一项 Warning 为 present/unselected（selection page-local）。disposed/replacement request 不能复活 deleted view 或改写 current page，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 均 settle，四次 saved-view read 恰一次失败；post-baseline writes 依次为 Warning filter、saved-view delete、Warning filter，failed High filter 恰尝试一次且无 persistence。
  - 本地复核确认 later filter-failure isolation、third-filter recovery、concurrent deletion ordering、saved-view identity retention、persisted-filter authority、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 108 项、`flutter analyze` 零问题、全量 317 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：subsequent filter recovery 期间 saved-view deletion failure 保持 identity，第三次 write 成功后 retry deletion 正常 drain 的语义已由下一条完成。

- MergeReview saved-view deletion failure preserves identity across filter recovery 回归硬化：
  - 仅新增 test-only deletion-failure/third-filter-recovery/retry/reconstruction race regression 与 controlled saved-view mutation-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与两个 Warning saved view；首个 Warning filter write 成功，later High filter write 恰失败一次，persisted authority 保持 Warning，failure status 可见。
  - 第三次 Warning filter write pending 时删除第二个 Warning view 恰失败一次；failed deletion 保留两个 view 且无 saved-view payload，第三次 filter write 随后成功且不改写 identity。
  - filter recovery 后 retry deletion 成功，最终仅第一项 Warning view；replacement saved-view read 失败并启动 held Warning@0，successful reconstruction 仅恢复剩余 view 为 present/unselected（selection page-local）。disposed/replacement request 不能复活 deleted view 或改写 current page，current Warning@0 发布 `Showing 1 of 1 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 均 settle，五次 saved-view read 恰一次失败；post-baseline writes 依次为 Warning filter、Warning filter、saved-view delete，failed High filter 与 failed deletion 均无 persistence。
  - 本地复核确认 deletion-failure identity retention、third-filter recovery ordering、retry ownership、persisted-filter authority、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 109 项、`flutter analyze` 零问题、全量 318 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：failed deletion 后再次 saved-view save 与 retry delete 在第四次 filter recovery 期间保持隔离，最终 identity 与 High authority 正确收敛的语义已由下一条完成。

- MergeReview failed deletion survives later saved-view mutation and filter recovery 回归硬化：
  - 仅新增 test-only failed-deletion/later-save/retry-delete/fourth-filter-recovery/reconstruction race regression 与 controlled saved-view mutation-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与两个 Warning saved view；首个 Warning filter write 成功，later High filter write 恰失败一次，persisted authority 保持 Warning，failure status 可见。
  - 第三次 Warning filter write pending 时删除第二个 Warning view 恰失败一次，两个 identity 保持；recovery 后第四次 High filter write pending，同时保存新 High view 并成功 retry deletion。
  - 最终 persisted list 仅第一项 Warning 与新 High；failed High filter 与 failed deletion 均无额外 payload，第四次 High write 恢复 High authority。
  - replacement saved-view read 失败并启动 held High@0；successful reconstruction 恢复两个剩余 view 为 present/unselected（selection page-local）。disposed/replacement request 不能复活 deleted view 或改写 current page，current High@0 发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 均 settle，六次 saved-view read 恰一次失败；post-baseline writes 依次为 Warning filter、Warning filter、saved-view save、saved-view delete、High filter，failed High filter 与 failed deletion 均无 persistence。
  - 本地复核确认 failed-deletion identity retention、later saved-view mutation ordering、fourth-filter recovery、persisted-filter authority、retry ownership、disposed-request isolation、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 110 项、`flutter analyze` 零问题、全量 319 项、`git diff --check`、严格 CI、14 项 importer、compare 全门禁与 Web build 均通过。
  - 后续闭环：retry-delete 后 failed later saved-view save 与第四次 filter recovery 的隔离、retry save 后 identity 正确收敛已由下一条完成。

- MergeReview failed save recovers after deletion retry and filter recovery 回归硬化：
  - 仅新增 test-only failed-deletion/retry-delete/later-save-failure/fourth-filter-recovery/reconstruction race regression，并复用 controlled saved-view mutation-failure fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与两个 Warning saved view；首个 Warning filter write 成功，later High filter write 恰失败一次，persisted authority 保持 Warning，failure status 可见。
  - 第三次 Warning filter write pending 时删除第二个 Warning view 恰失败一次；第三次 write recovery 后 retry deletion 成功，最终仅第一项 Warning view。
  - 第四次 High filter write pending 时保存 replacement High view 恰失败一次；释放第四次 write 恢复 High authority，retry save 后最终仅第一项 Warning 与 replacement High。failed filter、failed deletion、failed save 均无 payload，且最终 app-meta write-key 顺序有显式断言。
  - replacement saved-view read 失败后恢复；current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，disposed/replacement request 不能改写 current page，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 均 settle，七次 saved-view read 恰一次失败；成功 post-baseline writes 依次为 Warning filter、Warning filter、saved-view delete、High filter、saved-view save。
  - 本地复核确认 failed-save isolation、retry-delete ordering、fourth-filter recovery、saved-view identity retention、persisted-filter authority、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 111 项、`flutter analyze` 零问题、全量 320 项、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）均通过。
  - 后续闭环：retry-delete 后 saved-view deletion 与后续 filter write 的独立性已由下一条完成，转入 empty-list 后 save 的队列核验。

- MergeReview post-retry saved-view deletion survives a later filter write 回归硬化：
  - 仅新增 test-only failed-deletion/retry-delete/post-retry-deletion/later-filter-write/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与两个 Warning saved view；Warning filter metadata pending 时第二个 Warning deletion 恰失败一次，释放 filter 后 retry deletion 成功，最终仅第一项 Warning。
  - 随后 held High filter write 期间删除剩余第一项 Warning；deletion 独立成功并先持久化 empty saved-view list，pending High filter Future 直到显式 release 前保持 unsettled。
  - release 后 High filter authority 持久化；failed deletion 无 payload，成功 writes 严格为 Warning filter、saved-view delete、saved-view delete、High filter，并显式断言最终 app-meta write-key 顺序。
  - replacement saved-view read 失败后恢复；current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，disposed/replacement request 不能改写 current page，两个 deleted identity 均不复活，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, High@0, High@0]`；四个 held review-query Future 均 settle，六次 saved-view read 恰一次失败。
  - 本地复核确认 retry-delete ordering、post-retry deletion independence、later filter-write ownership、saved-view identity absence、persisted-filter authority、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 112 项、`flutter analyze` 零问题、全量 321 项、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）均通过。
  - 后续闭环：empty saved-view list 后再次 save 与另一轮 filter recovery 的独立性已由下一条完成，转入 post-empty save failure 的 deletion/filter 核验。

- MergeReview empty saved-view list accepts a later save during filter recovery 回归硬化：
  - 仅新增 test-only failed-deletion/retry-delete/empty-list/later-save/filter-recovery/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与一项 Warning saved view；Warning filter metadata pending 时唯一 deletion 恰失败一次，释放 filter 后 retry deletion 成功并持久化 empty saved-view list。
  - 列表为空后 held High filter write 期间保存 replacement High view；save 独立成功并先持久化唯一新 identity，pending High filter Future 在显式 release 前保持 unsettled，persisted filter 仍为 Warning。
  - release 后 High authority 恢复；failed deletion 无 payload，成功 writes 严格为 Warning filter、saved-view delete、saved-view save、High filter，并显式断言最终 app-meta write-key 顺序。
  - replacement saved-view read 失败后恢复；current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，deleted identity 不复活，replacement present/unselected，disposed/replacement request 不能改写 current page，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, High@0, High@0]`；四个 held review-query Future 均 settle，六次 saved-view read 恰一次失败。
  - 本地复核确认 empty-list transition、post-empty save independence、later filter-write ownership、retry-delete ordering、saved-view identity replacement、persisted-filter authority、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 113 项、`flutter analyze` 零问题、全量 322 项、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）均通过。
  - 后续闭环：post-empty save failure 后 retry save 与后续 deletion/filter recovery 的隔离已由下一条完成，转入 retry-save 后 apply 的队列核验。

- MergeReview post-empty saved-view save failure recovers before later deletion 回归硬化：
  - 仅新增 test-only failed-deletion/retry-delete/empty-list/save-failure/retry-save/later-deletion/filter-recovery/reconstruction race regression；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与一项 Warning saved view；Warning filter metadata pending 时唯一 deletion 恰失败一次，释放 filter 后 retry deletion 成功并持久化 empty list。
  - 后续 held High filter write 期间首次 replacement save 恰失败一次，empty list 保持且无 payload；释放 High write 恢复 authority，retry save 后仅 replacement High 持久化。
  - 再次 held Warning filter write 期间删除 replacement，deletion 独立成功并先持久化 empty list；release 后 Warning authority 恢复，最终两个 deleted identity 均 absent。
  - replacement saved-view read 失败后恢复；current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`，disposed/replacement request 不能改写 current page，无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 均 settle，八次 saved-view read 恰一次失败；成功 post-baseline writes 依次为 Warning filter、saved-view delete、High filter、saved-view save、saved-view delete、Warning filter，并显式断言 write-key 顺序。
  - 本地复核确认 post-empty save-failure isolation、retry-save ordering、later deletion independence、filter-write ownership、saved-view identity absence、persisted-filter authority、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 114 项、`flutter analyze` 零问题、全量 323 项、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）均通过。
  - 下一小步：检查 post-empty retry-save 与后续 saved-view apply 在 filter recovery 期间的竞态；若仍有 distinct gap，再补 bounded regression。

- MergeReview post-empty retry-save survives a queued saved-view apply 回归硬化：
  - 仅新增 test-only failed-deletion/retry-delete/empty-list/save-failure/retry-save/queued-apply/third-filter-recovery/reconstruction race regression，并复用 controlled saved-view mutation fixture；production 接口、逻辑与行为未变。
  - 102 条 backlog fixture 预存 High review filter 与一项 Warning saved view；Warning filter metadata pending 时首次 deletion 恰失败一次，释放 write 后成功，retry deletion 持久化 empty saved-view list，failed deletion 无 payload。
  - 后续 held High filter write 期间首次 replacement save 恰失败一次，empty list 保持且无 payload；释放 High write 恢复 High authority，retry save 后仅 replacement High 持久化。
  - 再次 held Warning filter write 期间 apply replacement High；apply 排在 active Warning filter write 后，释放该 write 时恰失败一次，queued High apply filter write 随后成功并持久化 High authority，replacement chip 在排队与 recovery 后均保持 selected。
  - replacement saved-view read 失败后恢复；current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，disposed/replacement request 不能改写 current page；replacement present/unselected（selection page-local），无 review error/exception。
  - 精确 query topology 为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 均 settle，七次 saved-view read 恰一次失败；成功 post-baseline writes 依次为 Warning filter、saved-view delete、High filter、saved-view save、High filter，并显式断言 write-key 顺序。
  - 本地复核确认 post-empty retry-save isolation、queued saved-view apply ordering、active filter-failure ownership、persisted-filter authority、saved-view identity retention、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 115 项、`flutter analyze` 零问题、全量 324 项、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）均通过。
  - 下一小步：检查 recovered retry-save 后 repeated queued saved-view apply 是否遗留 stale chip selection 或多余 filter write；若仍有 distinct gap，再补 bounded regression。

- MergeReview recovered retry-save drains repeated queued saved-view applies 回归硬化：
  - 仅新增 test-only recovered-retry-save/repeated-queued-apply/third-filter-recovery/reconstruction race regression；通过 controlled saved-view store 预置 failed deletion 与 failed High save 的 retry 后状态，再加入第二项 Warning view；production 接口、逻辑与行为未变。
  - 预置最终经历 empty-list transition 后恢复一项 High 与第二项 Warning。held Warning filter write 期间依次 apply High、Warning、High；仅 active Warning write 首次失败，三个 queued filter write 严格按 High、Warning、High 顺序 drain。
  - persisted filter authority 最终收敛为 High，High chip 在 active failure 与 queued recovery 期间保持 selected，failed filter 无 payload；预置阶段恰有两次 failed saved-view write，页面阶段无 saved-view mutation。
  - replacement saved-view read 失败后恢复；current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，disposed/replacement request 不能改写 current page；两个 view 均恢复为 present/unselected（selection page-local），无 review error/exception。
  - 页面 query topology 精确为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 均 settle，页面生命周期新增三次 saved-view read 恰一次失败；页面成功 writes 依次为 High filter、Warning filter、High filter，并显式断言 write-key/value 顺序。
  - 本地复核确认 recovered retry-save preconditioning、repeated queued apply ordering、active filter-failure ownership、persisted-filter authority、selection convergence、fail-open/recovery identity、page-local selection、Future settlement、query topology 与 side-effect baselines，未发现 blocker。
  - Operations widget 117 项、`flutter analyze` 零问题、全量 326 项、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）均通过。
  - 下一小步：检查 repeated apply 后 queued saved-view deletion 或 save 是否会在最终 filter authority 之后提交并遗留 obsolete identity；若仍有 distinct gap，再补 bounded regression。

- Canonical release adoption 与旧版本 local ref 清理（Slice88）：
  - 只读盘点未发现 workspace 内重复 release 文件、archive/package artifact、backup/copy 文件或同内容 source/document pair；标准平台生成资源重复属于框架预期文件，未触碰。
  - 采纳最新版 local ref `codex/public-github-launch@534ffdf`；删除四个已验证为其 strict ancestor 的 local refs：`main@0405fcd`、`codex/initial-import@6f8fb87`、`automation/importer-de-20260525@6f8fb87`、`automation/importer-fi-20260525@6f8fb87`。
  - 未删除源码、测试、构建产物或远端 branch；`origin/codex/initial-import` 保留，因 upstream branch 删除需要单独 remote authority。精确 inventory、hash 与 local ref 回滚命令记录于 `docs/timeline/2026-08-31-slice88-release-prune-audit.md`。
  - 已在既有 `docs/release_packaging.md` 增加 canonical version retention 规则，后续只改 canonical 文件，并以唯一增量 timeline MD 记录每次版本修改，禁止 full-content copy。
  - 验证继承 Slice87/cleanup baseline：Operations widget 117 项、全量 326 项、`flutter analyze` 零问题、`git diff --check`、严格 CI（含 14 项 importer、compare 全门禁与 Web build）；本 Slice 仅变更 release 文档、timeline 元数据与 local refs。
  - 回滚点：按 timeline 记录的 hash 重建被删 local ref，不 reset 或覆盖其他 working-tree 修改。
    - 下一小步：转向非重复 artifact 的 production release readiness（可复现版本元数据与 clean release preflight），继续遵守增量文件与 timeline 规则。

- 可复现 release metadata 与 clean preflight（Slice89）：
  - 新增增量脚本 `tool/check_release_metadata.dart`：校验 `pubspec.yaml` 唯一顶层 SemVer + 正 build number、已生成且含 SDK 约束的 `pubspec.lock`，以及 Android/iOS/macOS 对 Flutter version name/number 的原生传递占位符。
  - 脚本默认只读；`--require-clean` 与 `--canonical-ref <ref>` 仅用于有意的 release cut。GitHub Actions 在 clean checkout 上启用 clean gate，本地 `tool/ci_checks.sh` 保留可在 dirty 工作树运行的 metadata gate。
  - 已接入既有 `tool/ci_checks.sh` 与 `.github/workflows/flutter-ci.yml`，并在既有 `test/domain/ci_workflow_test.dart` 增加当前元数据、坏 SemVer 与 wiring 回归；输出只含确定性 JSON，不含时间戳或机器路径。
  - 遵守新存储规则：只增量编辑 canonical 文件，唯一新文件为 `docs/timeline/2026-08-31-slice89-release-metadata-preflight.md`，没有建立完整内容副本。
  - 验证：focused CI workflow test `+25`、`flutter analyze` 零问题、全量测试 `+329`、`git diff --check` 与严格 CI（14 项 importer、compare 全门禁、deterministic release metadata、Web build）均通过。
  - 下一小步：检查另一个 bounded production-readiness gap（artifact provenance 或 release configuration drift），继续禁止重复 canonical 内容。

- Deterministic Web artifact provenance（Slice90）：
  - 新增增量脚本 `tool/build_release_provenance.dart`：对 Web artifact 不跟随 symlink，按相对路径排序，记录 byte count + SHA-256，并将 manifest 写在 artifact 目录之外；内置 hash 实现不依赖自定义 CI package config 的缓存路径。
  - 已接入既有 `tool/ci_checks.sh` 与 GitHub Actions；CI 以 `GITHUB_SHA` 作为可选 source revision，并将 `build/datahookclaws-web.provenance.json` 与 `build/web` 一起上传。
  - 既有 `test/domain/ci_workflow_test.dart` 新增确定性重复生成、known digest、manifest 边界与 upload wiring 回归；不改变运行时代码，不创建完整内容副本。
  - 遵守存储规则：只增量编辑 canonical 文件，唯一新文件为 `docs/timeline/2026-08-31-slice90-release-provenance.md`。
  - 验证：focused `ci_workflow_test.dart` `+27`、`flutter analyze` 零问题、全量 `+331`、`git diff --check`、严格 CI（14 项 importer、compare gates、Web build、provenance）均通过；39 个 Web 文件 digest 与系统 `shasum` 交叉一致。
  - 下一小步：检查一个 bounded release configuration drift 或 artifact consumption gap，继续禁止重复 canonical 内容。

- Web artifact provenance verification（Slice91）：
  - 扩展既有 `tool/build_release_provenance.dart` 的只读 `--verify` 模式；重新计算 artifact snapshot，并拒绝 manifest schema、metadata、排序、bytes、SHA-256 或 source revision 不一致。
  - 已接入本地 wrapper 与 GitHub Actions 的 build→generate→verify→upload 顺序；CI 在上传前强制验证，未引入运行时改动或完整 manifest 副本。
  - 既有 `test/domain/ci_workflow_test.dart` 覆盖成功 verify 与 tampered artifact failure，并在既有 release notes 增加 verify 命令；唯一新迭代日志为 `docs/timeline/2026-08-31-slice91-provenance-verification.md`。
  - 验证：focused `ci_workflow_test.dart` `+27`、`flutter analyze` 零问题、全量 `+331`、`git diff --check`、严格 CI（14 项 importer、compare gates、Web build、provenance generate/verify）均通过。
  - 下一小步：检查一个 bounded release configuration drift 或 artifact consumption gap，继续禁止重复 canonical 内容。

- Android release signing gate（Slice92）：
  - 扩展既有 `tool/check_release_metadata.dart`，新增显式 `--require-release-signing`；解析 Android `release` build type，要求 `signingConfig`，并拒绝 debug signing 与模板 TODO。
  - 默认本地/远端 CI 仍只做可运行的 metadata preflight；正式 release-cut 命令在既有 `docs/release_packaging.md` 显式启用该闸门，当前开发配置会安全地 fail-fast，直到注入受管 release signing config。
  - 既有 `test/domain/ci_workflow_test.dart` 增加当前 debug 配置拒绝回归与 release command wiring；不修改运行时、不创建完整内容副本，唯一新迭代日志为 `docs/timeline/2026-08-31-slice92-release-signing-gate.md`。
  - 验证：focused `ci_workflow_test.dart` `+28`、全量测试 `+332`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify，且 production signing gate 对当前 debug 配置稳定返回 exit 1。
  - 下一小步：检查一个 bounded iOS/macOS release-signing 或 artifact consumption contract，继续禁止重复 canonical 内容。

- Apple release signing gate（Slice93）：
  - 扩展既有 `tool/check_release_metadata.dart`，新增显式 `--require-apple-signing`；检查 iOS/macOS 所有 Xcode `Release` 配置，拒绝 development/placeholder identity，并要求 `DEVELOPMENT_TEAM` 或 distribution `CODE_SIGN_IDENTITY`。
  - Apple credentials、provisioning profile 与 notarization 仍由 signing environment 管理；既有 release-cut 命令显式同时启用 Android/Apple 闸门，普通 local/GitHub CI 不受影响。
  - 既有 `test/domain/ci_workflow_test.dart` 增加当前 iOS/macOS 模板拒绝回归与 release command wiring；不修改运行时、不创建完整内容副本，唯一新迭代日志为 `docs/timeline/2026-08-31-slice93-apple-signing-gate.md`。
  - 验证：focused `ci_workflow_test.dart` `+29`、全量测试 `+333`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify，且 Apple gate 对当前配置返回 exit 1 并分别报告 iOS/macOS identity 诊断。
  - 下一小步：检查一个 bounded release artifact consumption 或 platform packaging contract，继续禁止重复 canonical 内容。

- Web artifact upload contract（Slice94）：
  - 收紧既有 GitHub Actions `datahookclaws-web` upload：`if-no-files-found: error` 确保 Web build 或 provenance manifest 缺失时 job fail，`retention-days: 14` 明确 CI artifact 生命周期。
  - artifact 内容仍严格限定为 `build/web` 与同级 `datahookclaws-web.provenance.json`，未新增 source copy 或第二打包路径；既有 workflow test 锁定 options，release notes 记录解包/保留契约。
  - 不修改运行时；只增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice94-web-artifact-upload-contract.md`。
  - 验证：focused `ci_workflow_test.dart` `+29`、全量测试 `+333`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Hidden Web build metadata parity（Slice95）：
  - 盘点发现 Flutter Web 会生成 `build/web/.last_build_id`；provenance generator 会哈希该隐藏文件，但 `actions/upload-artifact@v4` 默认不上传 hidden files，存在下载 artifact 与 manifest 漂移风险。
  - 在既有 upload 增量加入 `include-hidden-files: true`，并在既有 workflow test 锁定；release notes 明确 hidden build metadata 纳入 archive，未新增 source copy 或第二 artifact 路径。
  - 唯一新迭代日志为 `docs/timeline/2026-08-31-slice95-hidden-artifact-parity.md`；不修改运行时。
  - 验证：focused `ci_workflow_test.dart` `+29`、全量测试 `+333`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Production platform identifiers（Slice96）：
  - 扩展既有 `tool/check_release_metadata.dart`，新增显式 `--require-production-identifiers`；拒绝 Android 模板/未解析 `applicationId` 与 iOS/macOS Release `PRODUCT_BUNDLE_IDENTIFIER`，忽略 test-only bundle ID。
  - 正式 release-cut 命令显式启用该闸门，并将当前 `com.example...` 记录为 fail-fast blocker；默认 local/GitHub CI 不受影响，不修改运行时、不创建完整内容副本。
  - 既有 `test/domain/ci_workflow_test.dart` 增加三平台拒绝回归与 command wiring；唯一新迭代日志为 `docs/timeline/2026-08-31-slice96-production-identifiers.md`。
  - 验证：focused `ci_workflow_test.dart` `+30`、全量测试 `+334`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web version provenance contract（Slice97）：
  - 扩展既有 `tool/build_release_provenance.dart`，新增显式 `--require-web-version`；解析 Flutter 生成的 `version.json`，要求 `app_name`、`package_name`、semantic version 与 build number 对齐 canonical `pubspec.yaml`。
  - local/GitHub Web provenance generate 与 verify 均启用该 flag，stale/手改 build version 在 upload 前 fail-fast；仍只有既有 provenance manifest，无 source copy 或第二 artifact 路径。
  - 既有 `test/domain/ci_workflow_test.dart` 增加 version-file 正向、verify tamper failure 与 local/workflow wiring；唯一新迭代日志为 `docs/timeline/2026-08-31-slice97-web-version-provenance.md`。
  - 验证：focused `ci_workflow_test.dart` `+31`、full test `+335`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify（含 Web version gate）。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- CI release-evidence read-only permissions（Slice98）：
  - 在既有 GitHub Actions workflow 声明顶层 `permissions: contents: read`，限制 release-evidence job 只读仓库内容；不授予 repository write 或 deployment 权限。
  - 在既有 `test/domain/ci_workflow_test.dart` 增加权限契约回归，并在 `docs/release_packaging.md` 记录未来部署必须使用单独审查过的权限授予；唯一新迭代日志为 `docs/timeline/2026-09-01-slice98-ci-read-only-permissions.md`。
  - 验证：focused workflow test `+32`、full test `+336`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- CI release-evidence concurrency contract（Slice99）：
  - 在既有 workflow 声明按 workflow/ref 分组的 `concurrency`，并对被新 commit supersede 的运行启用 `cancel-in-progress: true`，避免旧 release evidence 与当前 ref 竞争；不删除已上传 artifact。
  - 在既有 `test/domain/ci_workflow_test.dart` 增加 concurrency 回归，并在 `docs/release_packaging.md` 记录取消边界；唯一新迭代日志为 `docs/timeline/2026-09-01-slice99-ci-concurrency.md`。
  - 验证：focused workflow test `+33`、full test `+337`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- CI release-evidence timeout contract（Slice100）：
  - 在既有 `analyze-test-web` job 声明 `timeout-minutes: 30`，避免 stalled dependency/Web build 无限占用 CI；不改变 artifact、权限或部署行为。
  - 在既有 workflow test 增加 timeout 回归，并在 `docs/release_packaging.md` 记录资源边界；唯一新迭代日志为 `docs/timeline/2026-09-01-slice100-ci-timeout.md`。
  - 验证：focused workflow test `+34`、full test `+338`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Release-evidence lockfile reproducibility（Slice101）：
  - 将 GitHub Actions 与本地 `tool/ci_checks.sh` 的依赖解析统一为 `flutter pub get --enforce-lockfile`，锁定 checked-in `pubspec.lock`，避免 release evidence 因隐式依赖漂移而不可复现。
  - 在既有 workflow test 增加 workflow/script wiring 回归，在 `docs/release_packaging.md` 记录 fail-fast 边界；唯一新迭代日志为 `docs/timeline/2026-09-01-slice101-lockfile-reproducibility.md`。
  - 验证：focused workflow test `+35`、full test `+339`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Explicit Web release-mode packaging（Slice102）：
  - 将 GitHub Actions 与本地 CI Web build 显式固定为 `flutter build web --release`，避免 release evidence 依赖默认 build mode；不新增 artifact path 或内容副本。
  - 在既有 workflow test 增加 workflow/script wiring 回归，并更新既有 Web packaging command；唯一新迭代日志为 `docs/timeline/2026-09-01-slice102-web-release-mode.md`。
  - 验证：focused workflow test `+36`、full test `+340`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Checkout credential isolation（Slice103）：
  - 在既有 `actions/checkout@v4` 设置 `persist-credentials: false`，避免 release-evidence job 在 source retrieval 后将 GitHub token 留在 workspace；不新增权限、artifact 或 deployment path。
  - 在既有 workflow test 增加 checkout wiring 回归，并在 `docs/release_packaging.md` 记录凭据边界；唯一新迭代日志为 `docs/timeline/2026-09-01-slice103-checkout-credential-isolation.md`。
  - 验证：focused workflow test `+37`、full test `+341`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Core Web shell provenance contract（Slice104）：
  - 扩展既有 provenance CLI 的显式 `--require-web-shell`，要求 generated Web artifact 至少包含 `index.html`、`flutter_bootstrap.js`、`main.dart.js` 与 `manifest.json` 四个 regular files；与 `--require-web-version` 一起在 local/GitHub generate 与 verify 使用。
  - 在既有 workflow test 增加正向与缺失入口回归，并更新既有 release packaging command；唯一新迭代日志为 `docs/timeline/2026-09-01-slice104-web-shell-provenance.md`。
  - 验证：focused workflow test `+38`、full test `+342`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web manifest identity provenance（Slice105）：
  - 扩展既有 provenance CLI 的显式 `--require-web-manifest`，要求 generated `manifest.json` 的 `name` 与 `short_name` 对齐 canonical package name；local/GitHub generate 与 verify 均启用。
  - 在既有 workflow test 增加正向与 tampered identity 回归，并更新既有 release packaging command；唯一新迭代日志为 `docs/timeline/2026-09-01-slice105-web-manifest-identity.md`。
  - 验证：focused workflow test `+39`、full test `+343`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web shell product metadata（Slice106）：
  - 将既有 `web/manifest.json` 与 `web/index.html` 的默认 Flutter 模板描述替换为 README 已验证的产品描述；不新增 artifact、source copy 或运行时逻辑。
  - 在既有 workflow test 增加两个 Web shell source metadata 回归，并更新既有 release packaging 说明；唯一新迭代日志为 `docs/timeline/2026-09-01-slice106-web-shell-metadata.md`。
  - 验证：focused workflow test `+40`、full test `+344`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Source revision provenance gate（Slice107）：
  - 扩展既有 provenance CLI 的显式 `--require-revision`，在 hash 前拒绝缺失或空白 `--revision`，确保发布证据绑定源码提交。
  - GitHub Actions 两个 provenance 命令均传入 `$GITHUB_SHA`；本地 wrapper 优先使用 `DHC_SOURCE_REVISION`，否则解析当前 checkout 的 `git rev-parse --verify HEAD`；唯一新迭代日志为 `docs/timeline/2026-09-01-slice107-source-revision-provenance.md`。
  - 在既有 workflow test 增加缺失/成功回归与 wiring 断言；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+41`、full test `+345`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest gate、source-revision provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web manifest icon asset provenance（Slice108）：
  - 扩展既有 provenance CLI 的显式 `--require-web-manifest-assets`，要求非空 `icons` 数组中的每个 `icons[].src` 都是 artifact 内安全相对路径并解析为 regular file；绝对路径、路径穿越、外部 URL 与缺失文件均 fail-fast。
  - local/GitHub provenance generate 与 verify 均启用该门禁；唯一新迭代日志为 `docs/timeline/2026-09-01-slice108-web-manifest-assets.md`。
  - 在既有 workflow test 增加正向、缺图与不安全路径回归；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+42`、full test `+346`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web shell reference integrity（Slice109）：
  - 扩展既有 provenance CLI 的显式 `--require-web-shell-references`，要求 `index.html` 实际引用 bootstrap script、manifest、favicon 与 Apple touch icon，且每个目标都是 artifact 内 regular file。
  - local/GitHub provenance generate 与 verify 均启用该门禁；唯一新迭代日志为 `docs/timeline/2026-09-01-slice109-web-shell-references.md`。
  - 在既有 workflow test 增加正向、缺少目标文件与缺少引用回归；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+43`、full test `+347`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web metadata parity provenance（Slice110）：
  - 扩展既有 provenance CLI 的显式 `--require-web-metadata-parity`，从 canonical `web/index.html` 与 `web/manifest.json` 读取唯一非空 description，并要求 generated Web 两个文件保持同值。
  - local/GitHub provenance generate 与 verify 均启用该门禁；唯一新迭代日志为 `docs/timeline/2026-09-01-slice110-web-metadata-parity.md`。
  - 在既有 workflow test 增加正向及 index/manifest 篡改回归；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+44`、full test `+348`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web PWA startup/display contract（Slice111）：
  - 扩展既有 provenance CLI 的显式 `--require-web-pwa-contract`，要求 generated manifest 的 `start_url` 为安全相对入口、`display` 为已知模式，且 `background_color`/`theme_color` 非空。
  - local/GitHub provenance generate 与 verify 均启用该门禁；唯一新迭代日志为 `docs/timeline/2026-09-01-slice111-web-pwa-contract.md`。
  - 在既有 workflow test 增加有效、外部 start URL、未知 display 与缺色值回归；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+45`、full test `+349`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web manifest icon metadata contract（Slice112）：
  - 扩展既有 provenance CLI 的显式 `--require-web-manifest-icon-metadata`，校验每个 icon 的 `sizes`（正数 `WIDTHxHEIGHT` 或 `any`）、受支持 image MIME `type` 及合法 `purpose` token。
  - local/GitHub provenance generate 与 verify 均启用该门禁；唯一新迭代日志为 `docs/timeline/2026-09-01-slice112-web-manifest-icon-metadata.md`。
  - 在既有 workflow test 增加有效、缺文件、非法尺寸、非法类型与非法 purpose 回归；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+46`、full test `+350`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/icon/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web theme-color parity contract（Slice113）：
  - 在既有 `web/index.html` 增加 canonical theme-color meta，并扩展 provenance CLI 的显式 `--require-web-theme-color-parity`，要求 source index/manifest 与 generated index/manifest 四处 theme color 完全一致且非空。
  - local/GitHub provenance generate 与 verify 均启用该门禁；唯一新迭代日志为 `docs/timeline/2026-09-01-slice113-web-theme-color-parity.md`。
  - 在既有 workflow test 增加有效及 generated index/manifest 篡改回归；不新增 artifact、source copy 或 runtime 行为。
  - 验证：focused workflow test `+47`、full test `+351`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/icon/theme/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web service-worker cleanup contract（Slice114）：
  - 扩展既有 provenance CLI 的显式 `--require-web-service-worker-contract`，要求 generated `flutter_bootstrap.js` 含唯一安全非空 `serviceWorkerVersion`，并要求 `flutter_service_worker.js` 具备 install/activate 生命周期、`skipWaiting` 与 self-unregister。
  - worker 采用 cleanup-only 策略：禁止 CacheStorage 访问与 fetch 拦截，避免 Flutter 弃用 worker 在发布后遗留陈旧缓存；local/GitHub provenance generate 与 verify 均启用该门禁。
  - 在既有 workflow test 增加有效 worker、缓存/拦截篡改与 unsafe version 回归；不新增 artifact、source copy 或 runtime 行为，唯一新迭代日志为 `docs/timeline/2026-09-01-slice114-web-service-worker-contract.md`。
  - 验证：focused workflow test `+48`、full test `+352`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web root base-href contract（Slice115）：
  - 扩展既有 provenance CLI 的显式 `--require-web-root-base-href`，要求 generated `index.html` 只含一个 `<base href="/">`，拒绝未替换 `$FLUTTER_BASE_HREF` 与 subpath drift。
  - local/GitHub provenance generate 与 verify 均启用该根路径部署门禁；在既有 workflow test 增加有效、占位符与重复 base tag 回归。
  - 不新增 artifact、source copy 或 runtime 行为，唯一新迭代日志为 `docs/timeline/2026-09-01-slice115-web-root-base-href.md`。
  - 验证：focused workflow test `+49`、full test `+353`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Root PWA identity contract（Slice116）：
  - 在既有 `web/manifest.json` 增加 canonical `id: "/"` 与 `scope: "/"`，并扩展 provenance CLI 的显式 `--require-web-pwa-identity`，要求 source/generated manifest 两处 root identity 完全一致。
  - local/GitHub provenance generate 与 verify 均启用该安装身份门禁；在既有 workflow test 增加有效及 generated id/scope 篡改回归。
  - 不新增 artifact、source copy 或 runtime 行为，唯一新迭代日志为 `docs/timeline/2026-09-01-slice116-web-pwa-identity.md`。
  - 验证：focused workflow test `+50`、full test `+354`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Responsive Web viewport contract（Slice117）：
  - 在既有 `web/index.html` 增加 canonical `viewport` meta，并扩展 provenance CLI 的显式 `--require-web-viewport`，要求 source/generated index 均只有一个 `width=device-width, initial-scale=1.0`。
  - local/GitHub provenance generate 与 verify 均启用该移动端 shell 门禁；在既有 workflow test 增加有效、值篡改与重复 meta 回归。
  - 不新增 artifact、source copy 或 runtime 行为，唯一新迭代日志为 `docs/timeline/2026-09-01-slice117-web-viewport.md`。
  - 验证：focused workflow test `+51`、full test `+355`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/viewport/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- English Web language contract（Slice118）：
  - 在既有 `web/index.html` 增加 canonical `<html lang="en">`，并扩展 provenance CLI 的显式 `--require-web-language`，要求 source/generated shell 各只有一个英文 lang 属性。
  - local/GitHub provenance generate 与 verify 均启用该可访问性门禁；在既有 workflow test 增加有效、外语值与缺失属性回归。
  - 不新增 artifact、source copy 或 runtime 行为，唯一新迭代日志为 `docs/timeline/2026-09-01-slice118-web-language.md`。
  - 验证：focused workflow test `+52`、full test `+356`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/viewport/language/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Web title parity contract（Slice119）：
  - 扩展 provenance CLI 的显式 `--require-web-title-parity`，要求 canonical/generated `index.html` 各只有一个非空 `<title>`，且文本保持一致，阻断构建转换后的浏览器标题漂移。
  - local/GitHub provenance generate 与 verify 均启用该门禁；在既有 workflow test 增加有效、篡改、重复与空 title 回归。
  - 不新增 artifact、source copy 或 runtime 行为，唯一新迭代日志为 `docs/timeline/2026-09-01-slice119-web-title-parity.md`。
  - 验证：focused workflow test `+53`、full test `+357`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/viewport/language/title/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 下一小步：检查一个 bounded platform packaging 或 release-evidence contract，继续禁止重复 canonical 内容。

- Activity trace UTF-8 byte budget（Slice120）：
  - 将 `ActivityTraceStore` 的 `activity_trace_v1` payload cap 统一改为 UTF-8 byte 计算，覆盖已有 payload 读取上限与 append fitting，避免多语言/emoji 的 Dart 字符长度低估实际持久化体积。
  - 在既有 `test/domain/activity_trace_store_test.dart` 增加 multibyte 超限回归，保持串行队列、fail-open 解码和 item limit 语义不变。
  - 不新增 artifact、source copy 或 runtime 功能，唯一新迭代日志为 `docs/timeline/2026-09-01-slice120-activity-trace-utf8.md`。
  - 验证：focused ActivityTraceStore test `+12`、full test `+358`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Saved review view UTF-8 byte budget（Slice121）：
  - 将 `MergeReviewSavedViewStore` 的 `merge_review_saved_views_v1` payload cap 统一改为 UTF-8 byte 计算，覆盖 load rejection 与 save fitting，避免多语言 view name/filter payload 的实际存储体积被低估。
  - 在既有 `test/domain/merge_review_saved_view_store_test.dart` 增加 multibyte load/save 超限回归，保持 schema、name normalization、串行队列、no-write-on-rejection 与 item limit 语义不变。
  - 不新增 artifact、source copy 或 runtime 功能，唯一新迭代日志为 `docs/timeline/2026-09-01-slice121-saved-view-utf8.md`。
  - 验证：focused saved-view store test `+11`、full test `+359`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Persistence store runtime bounds（Slice122）：
  - 将 `ActivityTraceStore` 与 `MergeReviewSavedViewStore` 构造器中仅在 debug 生效的 `assert` 边界改为运行时 `ArgumentError`，对正数 item limit 与最小 UTF-8 payload budget 在 release build 中同样拒绝无效配置。
  - 在既有两个 store 测试增加 zero/negative item limit 与低于最小 byte budget 的构造回归，保留已有 multibyte payload 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice122-runtime-bounds.md`。
  - 不新增 artifact、source copy 或 runtime 功能，保留有效配置下的 UTF-8 容量计量、串行队列、fail-open 读取与 item limit 语义。
  - 验证：combined focused store tests `+27`、full test `+361`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence schema 或 release-evidence contract，继续禁止重复 canonical 内容。

- Saved-view strict root schema（Slice123）：
  - 将 `MergeReviewSavedViewCodec.decode` 收紧为只接受精确根字段 `schemaVersion` 与 `views`；未知根字段 fail-open，避免未验证的未来字段静默进入 store canonicalizer。
  - 在既有 saved-view codec 测试增加“有效 view + unknown root field”回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice123-saved-view-root-schema.md`。
  - 不新增 artifact、source copy 或 runtime 功能，保留 schema version 校验、坏 entry 过滤、UTF-8 容量边界与串行 store 语义。
  - 验证：focused saved-view codec/store tests 18 cases、full test `+362`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- HomePage app_meta UTF-8 byte budget（Slice124）：
  - 新增小型 canonical `AppMetaPayloadBudget` helper，并将 HomePage 的 prompt config、recent replay、recent recall、favorite filters/templates/foods 所有 `app_meta` 读取上限与写入/压缩判断统一改为 UTF-8 bytes，避免多语言/emoji payload 被 Dart 字符数低估。
  - 在既有 helper test 增加 ASCII 与 multibyte byte-count 回归，并保持现有首页 widget suite；唯一新迭代日志为 `docs/timeline/2026-09-01-slice124-home-app-meta-utf8.md`。
  - 不新增 artifact、source copy 或用户流程，保留 metadata key、trim、dedupe、compaction 与 fallback 语义。
  - 验证：focused helper + HomePage widget tests 7 cases、full test `+363`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Saved-filter strict root schema（Slice125）：
  - 将 `MergeReviewFilter.tryFromJson` 收紧为拒绝未知 JSON 字段，同时保留可选 `severity`/`type` 与 schema-version、enum 严格校验；未来形状或非法字段 fail-closed，外层 `decode` 继续回退到 `All`。
  - 在既有 filter strict parser 测试增加 unknown-field 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice125-filter-root-schema.md`。
  - 不新增 artifact、source copy 或 runtime 功能，保留现有 filter 语义、saved-view 行为与 fail-open compatibility boundary。
  - 验证：focused filter + saved-view codec tests 10 cases、full test `+363`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- HomePage app_meta per-key write queue（Slice126）：
  - 新增 `AppMetaWriteQueue`，按 `app_meta` key 串行化 HomePage 写入；同一 key 的旧写入完成后才允许新写入，独立 key 仍可并发，且失败不会污染后续队列，避免慢速 repository 下 stale payload 后写覆盖 newer state。
  - 在既有 queue 与 HomePage widget 测试中覆盖调用顺序、独立 key 进度及失败恢复；唯一新迭代日志为 `docs/timeline/2026-09-01-slice126-home-app-meta-write-queue.md`。
  - 不新增 artifact、source copy 或用户流程，保留 metadata key、UTF-8 byte budget、trim/dedupe/compaction 与 fallback 语义。
  - 验证：focused queue + HomePage widget tests 8 cases、full test `+365`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence schema 或 release-evidence contract，继续禁止重复 canonical 内容。

- Saved-view item strict schema（Slice127）：
  - 将 `MergeReviewSavedView.tryFromJson` 收紧为只接受 `id`、`name`、`filter`、`createdAt`、`updatedAt` 五个条目字段；未知 item field fail-closed，与既有精确 root schema 共同阻断未来字段未经验证进入 store。
  - 在既有 saved-view codec/store 测试中增加 direct parser 与 codec filtering 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice127-saved-view-item-schema.md`。
  - 不新增 artifact、source copy 或用户流程，保留 root schema、filter 校验、坏 entry 过滤、UTF-8 budget 与 store queue 语义。
  - 验证：focused saved-view codec + store tests 19 cases、full test `+366`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Provenance manifest strict schema（Slice128）：
  - 将 `tool/build_release_provenance.dart` 的 verify 收紧为精确 root fields（含可选 `sourceRevision`）及精确 file-entry fields，extra field fail-closed，避免 release evidence 被未审计字段污染。
  - 在既有 ci workflow test 增加 root/file-entry unknown-field 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice128-provenance-schema.md`。
  - 不新增 artifact、source copy 或 runtime 用户流程，保留 hashing、revision、Web contracts 与发布输出 schema。
  - 验证：focused ci workflow 54 cases、full test `+367`、analyze zero、diff check；严格 CI 在临时 environment-only sqlite system hook 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify；临时 pubspec block 已移除。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Saved-view monotonic timestamps（Slice129）：
  - 让 `MergeReviewSavedView` 拒绝 `updatedAt < createdAt`；store 遇到系统/注入时钟回拨时保留既有 view 的较晚 `updatedAt`，但仍写入新的 name/filter snapshot，避免排序与新鲜度倒退。
  - 在既有 saved-view model/store 测试增加逆序时间与 clock rollback 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice129-saved-view-monotonic-time.md`。
  - 不新增 artifact、source copy 或用户流程，保留 schema guards、UTF-8 budget、串行写入与 filter 语义。
  - 验证：focused saved-view model/store 21 cases、full test `+369`、analyze zero、diff check；严格 CI 在临时 environment-only sqlite system hook 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify；临时 pubspec block 已移除。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Favorite persistence entry isolation（Slice130）：
  - 将 HomePage `favorite_foods_v1` 读取收紧为逐条安全解析：错误类型、空标识或空名称只跳过该条，不再让单条坏记录中止整份收藏；重复 `foodId` 只保留首个有效 snapshot。
  - 在既有 widget suite 增加 malformed/duplicate/valid persisted favorite 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice130-favorite-entry-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 metadata key、UTF-8 budget、write queue 与有效数据 UI 语义。
  - 验证：focused widget 8 cases、full test `+370`、analyze zero、diff check；严格 CI 在临时 environment-only sqlite system hook 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify；临时 pubspec block 已移除。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Favorite template entry isolation（Slice131）：
  - 将 HomePage `favorite_templates_v1` 读取改为逐条 fail-closed parser；错误类型、空标识/名称或显式坏时间戳只跳过该模板，不再丢弃整份列表；缺失 legacy 时间戳继续使用既有兼容 fallback。
  - 在既有 widget suite 增加 malformed-before-valid template 回归；唯一新迭代日志为 `docs/timeline/2026-09-01-slice131-favorite-template-entry-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 metadata key、有效模板行为、UTF-8 budget 与 write queue。
  - 验证：focused widget 9 cases、full test `+371`、analyze zero、diff check；严格 CI 在临时 environment-only sqlite system hook 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify；临时 pubspec block 已移除。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Favorite filter persistence ordering（Slice132）：
  - 将 `favorite_filters_v1` 的错误 `sortMode` 解析为安全 `recent` fallback，并将 favorite foods、filters、templates 改为有序且每个 loader 独立隔离异常；过滤条件只在收藏列表完成后 pruning，消除启动竞态导致的有效过滤丢失。
  - 在既有 widget suite 增加 malformed sort mode + 跨国家收藏回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice132-favorite-filter-ordering.md`。
  - 不新增 artifact、source copy 或用户流程，保留 metadata key、有效 filter 语义、UTF-8 budget 与 write queue。
  - 验证：focused widget 10 cases、full test `+372`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Recent export recall scope validation（Slice133）：
  - 将 `recent_export_recalls_v1` scope 解码收紧为按类型校验：规范化首尾空白，保留 search/favorites 的 `all-local-foods` 兼容语义，拒绝空或保留 sentinel 的 country/favorites/compare 项，避免误导性回读 chip。
  - 在既有 widget suite 增加 malformed scopes 先于合法 country/search/favorites/compare 回读的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice133-recent-export-recall-validation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 metadata key、有效 export replay 行为、UTF-8 budget 与 write queue。
  - 验证：focused widget 11 cases、full test `+373`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Compare replay draft integer timestamps（Slice134）：
  - 将 `recent_export_replay_drafts_v1` 的时间戳解码收紧为整数或整数字符串；小数、非有限值及其他类型直接跳过，交由既有 archive path 标记 `manual rebuild required`，不再静默截断为伪合法 epoch milliseconds。
  - 在既有 widget suite 增加 future fractional timestamp + compare draft status 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice134-compare-replay-draft-integer-time.md`。
  - 不新增 artifact、source copy 或用户流程，保留合法 draft retention/status/archive 语义、metadata key、UTF-8 budget 与 write queue。
  - 验证：focused widget 12 cases、full test `+374`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Recent-search metadata read isolation（Slice135）：
  - 将 HomePage 启动时 `recent_searches_v1` repository read 单独隔离；存储异常只让 recent searches 暂不可用，不阻断 shell 或其他独立 persistence loader，既有 malformed JSON 语义保持不变。
  - 在既有 widget suite 增加仅 recent-search metadata read 失败的 repository 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice135-recent-search-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 recent-search parser、metadata key、其他启动 loader 与 write queue 行为。
  - 验证：focused widget 13 cases、full test `+375`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Compare prompt-config read isolation（Slice136）：
  - 将 `compare_replay_draft_prompt_config_v1` repository read 与 export-recall restoration 解耦；配置存储异常保留内存默认值，并继续加载合法 export recall，不再中止整个 loader。
  - 在既有 widget suite 增加仅 prompt-config metadata read 失败且 country recall 仍恢复的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice136-prompt-config-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留默认 config 语义、export recall restoration、metadata key 与 write queue 行为。
  - 验证：focused widget 14 cases、full test `+376`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Recent export recall history fallback（Slice137）：
  - 将 `recent_export_recalls_v1` metadata read 与已有 export-history fallback 解耦；回读缓存不可用时，仍从历史记录重建合法 recall chip，不再中止 loader。
  - 在既有 widget suite 增加仅 recall-cache read 失败且 country export-history 仍可恢复的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice137-recent-export-history-fallback.md`。
  - 不新增 artifact、source copy 或用户流程，保留 history fallback、有效 replay 行为、metadata key 与 write queue。
  - 验证：focused widget 15 cases、full test `+377`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Replay-status read isolation（Slice138）：
  - 将 `recent_export_replay_statuses_v1` metadata read 作为可选状态层隔离；状态缓存异常时保留合法 compare recall chip（无 status suffix），其余 replay restoration 与 archive handling 继续执行。
  - 在既有 widget suite 增加仅 replay-status metadata read 失败且 compare recall 仍可见的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice138-replay-status-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留合法 recall chip、status 语义、metadata key 与 write queue 行为。
  - 验证：focused widget 16 cases、full test `+378`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Replay-draft timestamp read isolation（Slice139）
  - 将 `recent_export_replay_drafts_v1` metadata read 作为可选 timestamp 层隔离；读取异常只清除 timestamp 状态，仍允许 replay status 恢复，并将缺失 timestamp 的 Draft 归档为明确 manual-rebuild requirement。
  - 在既有 widget suite 增加仅 draft-timestamp metadata read 失败且 Draft status 仍被归档的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice139-replay-draft-timestamp-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 status restoration、archive 语义、metadata key 与 write queue 行为。
  - 验证：focused widget 17 cases、full test `+379`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export-history read isolation（Slice140）
  - 将 HomePage 的 export-history fallback read 隔离为可选层；recent-recall cache 与 `getExportHistory` 均不可用时仍保持 shell 健康，recall list 为空，不产生未处理 startup 异常。
  - 在既有 widget suite 增加仅 export-history read 失败且 HomePage shell 保持可用的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice140-export-history-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 recall-cache 行为、空 recall 语义、metadata key 与 write queue 行为。
  - 验证：focused widget 18 cases、full test `+380`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Compare-detail read isolation（Slice141）
  - 将 HomePage compare replay 的 `getFoodDetails` hydration 改为逐 ID 隔离；单个详情读取失败只跳过该 ID，后续详情继续加载，并保留 truthful partial restoration 状态。
  - 在既有 widget suite 增加首个 compare detail read 失败、第二个详情仍可恢复的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice141-compare-detail-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 partial-restoration status 语义、compare IDs、metadata key 与 write queue 行为。
  - 验证：focused widget 19 cases、full test `+381`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Import-log read isolation（Slice142）
  - 将 HomePage refresh、standard search、advanced search 的 `getImportLogs` 读取集中到安全 supplemental loader；读取失败保留上次 log state，同时继续提交结果与 count 更新。
  - 在既有 widget suite 增加 seeded results 且仅 import-log read 失败的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice142-import-log-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 result/count reads、prior log state、metadata key 与 write queue 行为。
  - 验证：focused widget 20 cases、full test `+382`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Food-count read isolation（Slice143）
  - 将 HomePage refresh、standard search、advanced search 的 `countFoods` 读取集中到安全 supplemental loader；读取失败保留上次 count，同时继续提交结果更新。
  - 在既有 widget suite 增加 seeded results 且仅 food-count read 失败的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice143-food-count-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 result/log reads、prior count state、metadata key 与 write queue 行为。
  - 验证：focused widget 21 cases、full test `+383`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Initial results read recovery（Slice144）
  - 将 HomePage 首次 refresh 的主 `searchFoods` 读取包在安全边界内；失败时不再留下无限 loading 或未处理异步错误，而是展示明确的 local-results-unavailable 状态和重试入口。
  - 在既有 widget suite 增加 transient primary-read failure → retry recovery 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice144-initial-results-read-recovery.md`。
  - 不新增 artifact、source copy 或用户流程，保留 standard/advanced search、result/log/count reads、metadata key 与 write queue 行为。
  - 验证：focused widget 22 cases、full test `+384`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Recent-search persistence isolation（Slice145）
  - 将 `_runSearch` 前置的 `recent_searches_v1` 写入降级为 best-effort；持久化失败不再阻断实际搜索，当前会话仍保留内存 recent-search state。
  - 在既有 widget suite 增加 seeded results 且仅 recent-search write 失败的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice145-recent-search-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 search execution、in-memory recent-search state、metadata key 与其他 write queue 行为。
  - 验证：focused widget 23 cases、full test `+385`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Recent-search management persistence isolation（Slice146）
  - 将 recent-search remove/clear-all 操作统一经过 best-effort persistence boundary；`recent_searches_v1` 写入失败不再产生未处理 Future，内存列表仍即时更新。
  - 在既有 widget suite 增加 populated recent-search list 在 persistence failure 下 clear-all 的回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice146-recent-search-management-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 search recording、in-memory state、metadata key 与其他 write queue 行为。
  - 验证：focused widget 24 cases、full test `+386`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Favorite persistence isolation（Slice147）
  - 将 HomePage favorite toggle、remove、clear-all 变更统一经过安全 persistence helper；`favorite_foods_v1` 写入失败保留内存 favorite state，不产生未处理 Future。
  - 在既有 widget suite 增加 seeded results 且仅 favorite write 失败的 toggle 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice147-favorite-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 favorite in-memory state、metadata key 与其他 write queue 行为。
  - 验证：focused widget 25 cases、full test `+387`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Favorite-filter persistence isolation（Slice148）
  - 将 favorite country/source/category/sort metadata 写入包在 best-effort boundary；`favorite_filters_v1` 写失败时筛选内存状态仍即时可用，不产生未处理 Future。
  - 在既有 widget suite 增加 seeded favorite 且仅 favorite-filter write 失败的 ChoiceChip 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice148-favorite-filter-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 in-memory selections、metadata key 与其他 write queue 行为。
  - 验证：focused widget 26 cases、full test `+388`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Favorite-template persistence isolation（Slice149）
  - 将 favorite template save/delete 的 `favorite_templates_v1` 写入包在 best-effort boundary；写入失败保留内存 template list，不产生未处理 Future。
  - 在既有 widget suite 增加 seeded favorite 且仅 favorite-template write 失败的保存回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice149-favorite-template-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 in-memory template state、metadata key 与其他 write queue 行为。
  - 验证：focused widget 27 cases、full test `+389`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Replay-status persistence isolation（Slice150）
  - 将 `recent_export_replay_statuses_v1` 写入包在 best-effort boundary；compare replay/archival 状态写入失败时保留 live status，不产生未处理 Future。
  - 在既有 widget suite 增加 short-ID compare recall 且仅 replay-status write 失败的可见性回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice150-replay-status-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 compare replay state、metadata key 与其他 write queue 行为。
  - 验证：focused widget 28 cases、full test `+390`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Replay-draft timestamp persistence isolation（Slice151）
  - 将 `recent_export_replay_drafts_v1` 时间戳写入包在 best-effort boundary；draft timestamp 写入失败时保留 live compare replay 状态，不产生未处理 Future。
  - 在既有 widget suite 增加 short-ID compare recall 且仅 replay-draft timestamp write 失败的可见性回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice151-replay-draft-timestamp-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 compare replay state、metadata key 与其他 write queue 行为。
  - 验证：focused widget 29 cases、full test `+391`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export-recall persistence isolation（Slice152）
  - 将 `recent_export_recalls_v1` 列表写入包在 best-effort boundary；export recall 清空/变更时写入失败仍保留 live recall list，不产生未处理 Future。
  - 在既有 widget suite 增加 seeded search recall 且仅 export-recall write 失败的清空回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice152-export-recall-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 live recall list、metadata key 与其他 write queue 行为。
  - 验证：focused widget 30 cases、full test `+392`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Provenance symlink containment（Slice153）
  - 将 release provenance output/verify containment 改为先解析 existing path components，再与 artifact 真实路径比较；symlink redirect 不再能把 artifact 内目标伪装为外部路径。
  - 在既有 `ci_workflow_test.dart` 增加 symlinked artifact-directory redirect 回归并锁定稳定诊断；唯一新迭代日志为 `docs/timeline/2026-09-02-slice153-provenance-symlink-containment.md`。
  - 不新增 artifact、source copy 或用户流程，保留 deterministic manifest hashing、output/verify semantics 与 Web contract checks。
  - 验证：focused CI workflow 55 cases、full test `+393`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Provenance artifact-root symlink rejection（Slice154）
  - 要求 release provenance 的 artifact input 本身为 regular directory；root symlink fail-closed，避免外部目录被静默纳入 hashed artifact。
  - 在既有 provenance path-safety regression 扩展 symlinked artifact-root case；唯一新迭代日志为 `docs/timeline/2026-09-02-slice154-provenance-artifact-root-symlink.md`。
  - 不新增 artifact、source copy 或用户流程，保留 destination containment、deterministic hashing 与 Web contract checks。
  - 验证：focused CI workflow 55 cases、full test `+393`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Provenance dangling-path resolution（Slice155）
  - 将 release provenance input/output/verify 的 containment path resolution 包在 fail-closed 诊断中；悬空或无法解析的 symlink 在 hashing/writing 前稳定失败，不泄漏未处理 filesystem stack。
  - 在既有 deterministic path-safety regression 增加 dangling output、verify、input symlink cases；唯一新迭代日志为 `docs/timeline/2026-09-02-slice155-provenance-dangling-path-resolution.md`。
  - 不新增 artifact、source copy 或用户流程，保留 regular artifact-root validation、destination containment、deterministic hashing 与 Web contract checks。
  - 验证：focused CI workflow 55 cases、full test `+393`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Settings startup persistence isolation（Slice156）
  - 将 `SettingsService.load()` 的 `app_settings` read failure 回退到 in-memory defaults；malformed settings 的 repair write 变为 best-effort，避免启动阶段二次失败。
  - 在既有 settings service suite 增加 unavailable-read 与 repair-write failure 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice156-settings-startup-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 settings sanitization、显式 save semantics 与 runtime wiring。
  - 验证：focused settings 7 cases、full test `+393`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Settings page persistence recovery（Slice157）
  - 将 `SettingsPage` 的 settings/storage-path load failure 显示为可恢复状态；表单保留 defaults/available values，save failure 留在页面状态消息中，不从按钮 action 冒泡。
  - 新增 focused SettingsPage widget suite 覆盖 unavailable storage paths 与 failed settings writes；唯一新迭代日志为 `docs/timeline/2026-09-02-slice157-settings-page-persistence-recovery.md`。
  - 不新增 artifact、source copy 或用户流程，保留 settings service fallback、表单字段与 runtime wiring。
  - 验证：focused SettingsPage 2 cases、full test `+396`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export history persistence isolation（Slice158）
  - 将 `FoodCatalogExportService` 的 `addExportHistory` write 视为 supplemental；文件写入成功后 history failure 不再使 artifact 返回失败或伪报导出失败。
  - 在既有 export service suite 增加 history-only write failure 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice158-export-history-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 export formats、deterministic paths、AI summary behavior 与 recall persistence。
  - 验证：focused export-service 9 cases、full test `+397`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- AI suggestion persistence isolation（Slice159）
  - 将 `AiAssistServiceBase.runSuggestion` 的模型请求与 supplemental suggestion-log write 解耦；成功模型输出在日志写入失败时仍可用，模型/预算降级在 fallback 日志失败时仍保持确定性。
  - 在既有 settings/AI suite 增加 successful output 与 deterministic routing fallback 的 failing-persistor 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice159-ai-suggestion-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 model budget、public persist semantics、deterministic fallback 与 export/search routing 行为。
  - 验证：focused settings/AI 9 cases、full test `+399`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查 `QueryExpansionService` 的 analogous bounded persistence boundary，继续禁止重复 canonical 内容。

- Query expansion persistence isolation（Slice160）
  - 将 `QueryExpansionService.expand` 的模型/JSON 解析与 supplemental suggestion-log write 解耦；有效 expansion 在日志写入失败时仍可用，请求或预算降级在 fallback 日志失败时仍保持确定性。
  - 在既有 query-expansion/budget suite 增加 successful output、request fallback 与 budget fallback 的 failing-persistor 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice160-query-expansion-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 model budget、expansion parsing、public persistor semantics 与 deterministic search fallback 行为。
  - 验证：focused query-expansion/budget 9 cases、full test `+402`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Import log persistence isolation（Slice161）
  - 将 `SyncFoodCatalogUseCase` 的 success/failure import log 视为 supplemental diagnostics；成功导入在日志写入失败时仍返回 normalized foods，导入失败时即使 failure-log write 失败也保留原始错误。
  - 在既有 source-importer suite 增加 success-log failure 与 original failure preservation 的 failing-log-repository 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice161-import-log-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 ingestion、normalization、artifact persistence、original error semantics 与 importer routing。
  - 验证：focused source-importer 17 cases、full test `+404`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Fetch-job persistence isolation（Slice162）
  - 将 `ForegroundFetchRunner` 与 `BackgroundEnrichmentQueue` 的 queued/running/success/failure/cancelled 状态写入视为 supplemental diagnostics；fetch-job storage failure 不再阻断来源导入、把成功来源伪报为失败，或停止后续 enrichment source。
  - 在 focused fetch-runner/queue suite 增加成功/失败前台来源及成功后台 enrichment 的 failing-job-persistor 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice162-fetch-job-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 importer execution、queue cancellation/state transitions、fetch-job schema 与 SearchOrchestrator wiring。
  - 验证：focused fetch-runner/queue/orchestrator 8 cases、full test `+407`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Operations retry persistence isolation（Slice163）
  - 将 Operations 手动 Retry 的 fetch-job running/success/failure 状态写入视为 supplemental diagnostics；状态存储不可用时仍执行来源重试，成功重试不再被伪报为失败，来源错误文案保持原始内容。
  - 在既有 Operations widget suite 增加 failing fetch-job persistor 回归，验证来源执行与 failure→running→success 状态尝试序列；唯一新迭代日志为 `docs/timeline/2026-09-02-slice163-operations-retry-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 source retry semantics、activity tracing、refresh behavior、fetch-job schema 与现有审核竞态矩阵。
  - 验证：focused retry regression、Operations widget 118 cases、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Dataset artifact persistence isolation（Slice164）
  - 将 `SyncFoodCatalogUseCase` 的 dataset-artifact inventory metadata 视为已提交 normalized import 之后的 supplemental metadata；artifact write 失败时仍返回 normalized foods 与 success log，不改变 ingestion/normalization error semantics。
  - 在既有 `it_crea`/source-importer suite 增加 failing artifact repository 回归，验证 artifact write 不可用时 normalized food 仍可搜索且导入结果保持成功；唯一新迭代日志为 `docs/timeline/2026-09-02-slice164-dataset-artifact-persistence-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 normalized ingestion、success/failure import-log boundaries、artifact schema 与 importer routing。
  - 验证：focused `it_crea`/source-importer 18 cases、full test `+409`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Recent fetch-history read isolation（Slice165）
  - 将 `SearchOrchestrator` 的 recent failed fetch-job history 读取视为来源排序的 routing metadata；读取失败时以空 failure set fail open，主搜索与后台 enrichment 继续运行，local results、source execution 与 queue outcomes 保持既有语义。
  - 在既有 SearchOrchestrator search/enrichment suite 增加 failing recent-history repository 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice165-recent-fetch-history-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 source routing rules、budget limits、local-search states 与 enrichment queue semantics。
  - 验证：focused SearchOrchestrator 9 cases、full test `+411`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Post-fetch reconciliation read isolation（Slice166）
  - 将 `SearchOrchestrator` 的 post-fetch local-search reconciliation read 视为 foreground runner result 之外的 supplemental read；读取失败时使用 runner 已返回的 normalized imported foods，成功来源不再被伪报失败，正常重读路径保留 canonical de-duplication。
  - 在既有 SearchOrchestrator suite 增加仅 post-fetch read failure 的 repository 回归，验证 fetched food 与 archived state 仍返回；唯一新迭代日志为 `docs/timeline/2026-09-02-slice166-post-fetch-reconciliation-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 canonical result merging、source outcome semantics、routing 与 enrichment queue behavior。
  - 验证：focused SearchOrchestrator 9 cases、full test `+412`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export summary provider isolation（Slice167）
  - 将 `FoodCatalogExportService` 的 export file 视为 primary artifact，AI summary provider 视为 supplemental；provider 异常时回退到确定性摘要并仍写入 export history，不把成功导出伪报为失败。
  - 在既有 export-service suite 增加 throwing summary provider 回归，验证 JSON artifact 存在、history 保留且 fallback summary 稳定；唯一新迭代日志为 `docs/timeline/2026-09-02-slice167-export-summary-provider-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 export formats、deterministic paths、history schema 与成功 provider 的 AI summary behavior。
  - 验证：focused export-service 11 cases、full test `+413`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export directory resolution read isolation（Slice168）
  - 将 `SettingsService.effectiveExportDirectory` 的 storage-path metadata read 视为导出动作的 supplemental input；读取异常或空 exports path 时回退到确定性的本地 `exports` 目录，显式用户目录仍优先，不阻断用户请求的 export。
  - 在既有 settings/AI suite 增加 storage-path read failure 回归，验证 fallback 路径稳定且只读取一次；唯一新迭代日志为 `docs/timeline/2026-09-02-slice168-export-directory-resolution-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 explicit export-directory precedence、settings sanitization 与 export formats。
  - 验证：focused Settings/AI 10 cases、full test `+414`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Storage budget metadata read isolation（Slice169）
  - 将 `StorageBudgetManager.snapshot` 的 storage paths 与 dataset-artifact inventory 作为独立 supplemental reads；任一读取异常时保留另一侧 filesystem metrics，并在 warnings 显式标记 unavailable，避免 Operations budget card 整体失败或把未知伪报为零。
  - 在既有 storage-budget suite 增加 paths read failure 与 artifact inventory read failure 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice169-storage-budget-metadata-read-isolation.md`。
  - 不新增 artifact、source copy 或用户流程，保留 filesystem sizing、budget thresholds 与 unavailable-data warning semantics。
  - 验证：focused StorageBudgetManager 4 cases、full test `+416`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Settings numeric bounds（Slice170）
  - 将 `SettingsService` 的 persisted/explicit numeric settings 统一安全化：负 model-call limit 回退默认但保留 `0` 作为显式 AI disable；timeout、token 与四类 storage budget 只接受正数，否则回退默认，避免无效 runtime limits。
  - 在既有 settings/AI suite 增加 malformed read 与 unsafe save 回归，并验证写入 payload 已规范化；唯一新迭代日志为 `docs/timeline/2026-09-02-slice170-settings-numeric-bounds.md`。
  - 不新增 artifact、source copy 或用户流程，保留 source enablement sanitization、zero-call disable semantics 与 settings persistence。
  - 验证：focused Settings/AI 12 cases、full test `+417`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Settings save canonical snapshot（Slice171）
  - 将 `SettingsService.save` 改为返回实际写入的 sanitized `AppSettings`，并让 `SettingsPage` 在成功保存后用该快照同步内存状态与表单控制器，避免不安全输入在当前会话中与持久化值分叉。
  - 在既有 settings/AI 与 settings-page suite 增加 canonical-return 与 unsafe-form-save 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice171-settings-save-canonical-snapshot.md`。
  - 不新增 artifact、source copy 或用户流程，保留 numeric sanitization、显式 zero-call AI disable、source enablement 与 settings persistence。
  - 验证：focused Settings/AI 12 cases、settings-page 3 cases、full test `+418`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Storage measurement completeness（Slice172）
  - 为 `StorageBudgetManager` 引入可注入的 filesystem adapter，并让 database/artifact/export/cache 测量同时返回 bytes 与 completeness；非法路径或部分扫描失败时保留可得指标并加入明确 warning，不将未知当作零。
  - 在既有 storage-budget suite 增加 database measurement failure 与 mixed artifact inventory 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice172-storage-measurement-completeness.md`。
  - 不新增 artifact、source copy 或用户流程，保留 repository-read isolation、budget thresholds、empty-path semantics 与 Operations budget card wiring。
  - 验证：focused StorageBudgetManager 6 cases、full test `+420`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、14 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Home search failure recovery（Slice173）
  - 为 HomePage 提交搜索增加 request-generation guard 与显式 failure/retry 状态；搜索流、advanced search、取消或 supplemental read 异常会停止 loading、保留上次可见结果并显示稳定恢复卡，旧请求不能覆盖新请求或清空后的输入。
  - 在既有 widget suite 增加瞬时 search read failure→retry 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice173-home-search-failure-recovery.md`。
  - 不新增 artifact、source copy 或用户流程，保留 SearchOrchestrator、initial-results recovery、enrichment cancellation 与现有结果合并语义。
  - 验证：focused HomePage widget 30 cases、full test `+421`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Fetch budget input bounds（Slice174）
  - 为 `FetchBudgetPlanner` 的 importer 数量、单来源 limit 与 local-hit threshold 增加构造期边界收敛：负 importer budget/threshold 回退安全默认，非正 per-importer limit 回退默认，`maxImporters:0` 保留显式禁用；跳过 fetch 的 plan 使用 sanitized limit。`SourceRoutingService` 直接收到负 route budget 时返回空路由。
  - 在既有 planner/routing suite 增加非法 budget、显式零禁用、跳过计划 limit 与负 route budget 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice174-fetch-budget-input-bounds.md`。
  - 不新增 artifact、source copy 或用户流程，保留 source ordering、routing failure prioritization 与 import request semantics。
  - 验证：focused planner/routing 11 cases、full test `+425`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Source route identity deduplication（Slice175）
  - 为 capability-aware 与 legacy source routing 去重重复 importer IDs：default order/source hints 按首次出现保留优先级，recent-failure deprioritization 与 route budget 保持不变，避免 malformed configuration 在一次搜索或 enrichment 中重复执行同一来源。
  - 在既有 planner/routing suite 增加 duplicate prioritized importer 与 duplicate source hint 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice175-source-route-identity-deduplication.md`。
  - 不新增 artifact、source copy 或用户流程，保留 budget sanitization、source ordering、failure prioritization 与 import request semantics。
  - 验证：focused planner/routing 13 cases、full test `+427`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Model budget runtime bounds（Slice176）
  - 为 `ModelBudgetController` 构造期 runtime 参数增加 release-safe 收敛：负 max calls、非正 timeout/token/failure cooldown 回退安全默认，`maxCallsPerMinute:0` 保留显式模型禁用语义，避免非法 Duration 或 token limit 进入 Ollama/AI 路径。
  - 在既有 model-budget suite 增加 invalid runtime values 与 zero-call disable 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice176-model-budget-runtime-bounds.md`。
  - 不新增 artifact、source copy 或用户流程，保留 budget evaluation、cooldown、AI fallback 与 model-call semantics。
  - 验证：focused model-budget 4 cases、full test `+428`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Non-finite nutrient normalization（Slice177）
  - 为 `FoodRecordNormalizer` 增加 raw 与 converted nutrient amount 的 finite guard；`NaN`、`Infinity` 与单位换算溢出值在进入 canonical `Nutrient`、SQLite 或 JSON 前丢弃，同一记录中的有效营养素继续保留。
  - 在既有 normalization-toolkit suite 增加非有限原始值、换算溢出与相邻有效值回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice177-non-finite-nutrient-normalization.md`。
  - 不新增 artifact、source copy 或用户流程，保留 nutrient alias、unit conversion 与有效记录规范化语义。
  - 验证：focused normalization-toolkit 6 cases、full test `+429`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Import request limit boundary（Slice178）
  - 将 `ImportRequest` 构造期的负 limit 统一收敛为 `0`（`const` 与 `copyWith` 路径一致），阻止 malformed caller 把负数传入 importer `.take()` 或 count-based early-exit，同时保留 `0` 作为显式空请求。
  - 在既有 official-dataset grabber suite 增加 direct/copy negative-limit 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice178-import-request-limit-boundary.md`。
  - 不新增 artifact、source copy 或用户流程，保留 valid limit、explicit zero-limit 与 dataset preparation semantics。
  - 验证：focused official-dataset 6 cases、full test `+430`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Repository read limit normalization（Slice179）
  - 为 Memory/SQLite `FoodRepository` 引入共享 read-limit normalizer；负 limit 在高级搜索、summary/country paging、MergeReview 与 diagnostics history 进入 `.take()`、early-exit 或 SQLite `LIMIT` 前统一变为空页，`0` 保留显式空页语义。
  - 在既有 advanced-search 与 SQLite migration suite 增加 Memory/SQLite negative-limit 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice179-repository-read-limit-normalization.md`。
  - 不新增 artifact、source copy 或用户流程，保留 valid paging、sorting 与 SQLite query semantics。
  - 验证：focused repository 10 cases、full test `+432`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export food-id limit boundary（Slice180）
  - 将 `FoodCatalogExportService.exportFoodIds` 的负 limit 在 ID 去重后、`.take()` 前收敛为 `0`，malformed caller 现在得到确定性的空 JSON artifact 与零记录，不改变正数 limit、trim/dedup 或 history 行为。
  - 在既有 export-service suite 增加 negative-limit empty-artifact 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice180-export-food-id-limit-boundary.md`。
  - 不新增 artifact、source copy 或用户流程，保留 export format、identifier scope 与 history semantics。
  - 验证：focused export-service 11 cases、full test `+433`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Export scope filename containment（Slice181）
  - 将 `FoodCatalogExportService` 的公开 `scopeType` 在文件名组件中收敛为安全 slug，阻断 path separator/traversal 片段逃逸 configured export directory；JSON payload 与 history label 继续保留原始 scope value，正向文件名保持不变。
  - 在既有 export-service suite 增加 traversal-shaped scope type 的 parent-directory containment 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice181-export-scope-filename-containment.md`。
  - 不新增 artifact、source copy 或用户流程，保留 scope payload/history、export directory resolution 与 format semantics。
  - 验证：focused export-service 12 cases、full test `+434`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web release build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Official ZIP extraction containment（Slice182）
  - 将 `DatasetPackagePreparer` 的 ZIP entry 路径判断改为 segment-aware containment；规范化后落在 `extracted-evil` 等兄弟前缀目录的 traversal entry 会被跳过，合法嵌套文件与 sentinel 语义保持不变。
  - 在既有 official-dataset grabber suite 增加恶意 archive entry 回归，验证越界文件不落盘且安全文件仍解包；唯一新迭代日志为 `docs/timeline/2026-09-02-slice182-official-zip-extraction-containment.md`。
  - 不新增 artifact、source copy 或用户流程，保留下载、manifest、valid ZIP extraction 与 dataset path semantics。
  - 验证：focused official-dataset 7 cases、full test `+435`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Official dataset download filename containment（Slice183）
  - 将 `HttpDatasetTransport.download` 的 `suggestedFileName` 在 HTTP 请求和文件写入前收敛为 segment-aware path contract；absolute/traversal-shaped filename 现在 fail closed，合法 manifest filename 路径保持不变，并与 ZIP 解包共用 guard。
  - 在既有 official-dataset grabber suite 增加 transport regression，验证越界 filename 在 network use 前失败且 sibling file 不落盘；唯一新迭代日志为 `docs/timeline/2026-09-02-slice183-official-download-filename-containment.md`。
  - 不新增 artifact、source copy 或用户流程，保留 download、manifest、valid extraction 与 sentinel semantics。
  - 验证：focused official-dataset 8 cases、full test `+436`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Official dataset importer-id containment（Slice184）
  - 将 `HttpDatasetTransport.datasetRoot` 与 `DatasetPackagePreparer` 的 `importerId` 收敛为单一非空路径组件；absolute、`..` 与双平台 separator 形式在 root resolver 前 fail closed，valid manifest ID 的目录布局不变。
  - 在既有 official-dataset grabber suite 增加 transport/preparer 回归，验证 unsafe ID 不触发 root resolution；唯一新迭代日志为 `docs/timeline/2026-09-02-slice184-official-importer-id-containment.md`。
  - 不新增 artifact、source copy 或用户流程，保留 valid directory resolution、download、ZIP extraction 与 sentinel semantics。
  - 验证：focused official-dataset 10 cases、full test `+438`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Home refresh generation ownership（Slice185）
  - 为 HomePage 的 initial/import/enrichment supplemental refresh 引入 search-generation snapshot，并在 repository、import-log、count 等 await 前后检查 ownership，避免旧查询完成后覆盖较新的搜索结果或 compare selection。
  - 在既有 widget suite 增加 blocked salmon enrichment refresh → oats 新搜索 → release salmon 的竞态回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice185-home-refresh-generation-ownership.md`。
  - 不新增 artifact、source copy 或用户流程，保留 search、import、enrichment 与 supplemental-read semantics。
  - 验证：focused widget regression、full test `+439`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- App metadata write-tail cleanup（Slice186）
  - 为 `AppMetaWriteQueue` 增加 identity-checked settled-tail cleanup；每个 key 的完成或失败 Future 在不再是最新尾部后释放，仍保持同 key 串行与 error propagation，避免动态 key 长期累积。
  - 在既有 queue suite 增加 active/completed 与 failed-tail cleanup 回归；唯一新迭代日志为 `docs/timeline/2026-09-02-slice186-app-meta-write-tail-cleanup.md`。
  - 不新增 artifact、source copy 或用户流程，保留 per-key ordering、failure recovery 与 metadata persistence semantics。
  - 验证：focused queue 4 cases、full test `+441`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 下一小步：检查一个 bounded persistence 或 release-evidence contract，继续禁止重复 canonical 内容。

- Search expansion cache bound（Slice187）
  - 为 `SearchOrchestrator` 的 query expansion cache 增加默认 32-entry 的运行时上限；cache hit 会刷新 recency，超限时淘汰 least-recently-used entry，enrichment 对被淘汰 query 重新展开，近期 query 仍复用。
  - 在既有 orchestrator suite 增加三 query eviction/re-expansion 回归，并保留正数 cache-size constructor contract；唯一新迭代日志为 `docs/timeline/2026-09-02-slice187-search-expansion-cache-bound.md`。
  - 不新增 artifact、source copy 或用户流程，保留 expansion、enrichment routing 与既有 failure-isolation semantics。
  - 验证：focused orchestrator 11 cases、full test `+442`、analyze zero、diff check；严格 CI 在 canonical dependency file 下通过，含 lockfile、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 下一小步：用户已要求推送后暂停更新，待后续明确指令再继续 bounded persistence 或 release-evidence contract。

## Upgrade queue

- Introduced `docs/upgrade_queue.md` as a durable, prioritized queue for future capability growth.
- Core near-term targets now include:
  - search workflow enhancements (favorites/comparison/quick recall)
  - data version refresh and change-summary work
  - batch review and governance quality workspace (current-page selection foundation completed)
- Mid-term targets include search templates, operation queue UX, and lightweight background persistence.
- All future upgrades are linked to legal/attribution boundary checks before source or export enhancement.
