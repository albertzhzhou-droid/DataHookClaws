# Compare accessibility CI trend guide

Purpose:

- Support run-count and time-window trend review for compare replay accessibility quality signals.
- Build a low-friction governance path before hard gate breaches become user-visible regressions.

Inputs:

- One or more log files containing `COMPARE_REPLAY_A11Y_PARSED_JSON=<json>` lines.
- Each log line can optionally include an ISO-8601 timestamp (for example:
  `2026-08-17T10:00:00Z ... COMPARE_REPLAY_A11Y_PARSED_JSON=...`).
- If a timestamp is missing, script falls back to file-modified time (for files) or current
  time for stdin input.
- Output from `tool/parse_compare_accessibility_report.dart`.

Commands:

```bash
export DART_BIN="/path/to/your/flutter/bin/cache/dart-sdk/bin/dart"

"$DART_BIN" tool/analyze_compare_accessibility_trends.dart \
  run1.log run2.log run3.log \
  --window-runs 7

"$DART_BIN" tool/analyze_compare_accessibility_trends.dart \
  run1.log run2.log \
  --window-days 7

"$DART_BIN" tool/analyze_compare_accessibility_trends.dart \
  run1.log run2.log run3.log \
  --window-runs 7 \
  --trend-noise-window 2 \
  --recurrence-window 2 \
  --max-recurrence-count 0 \
  --max-absence-runs 999 \
  --output-json

# Or via env/CLI mix (equivalent gating posture):
export DHC_A11Y_TREND_MAX_RECURRENCE_COUNT=0
export DHC_A11Y_TREND_MAX_ABSENCE_RUNS=999
export DHC_A11Y_TREND_FAIL_ON_ALERTS=true
export DHC_A11Y_TREND_MAX_SCHEMA_MISMATCH=0
export DHC_A11Y_TREND_MAX_UNKNOWN_SEVERITY=0
export DHC_A11Y_TREND_MIN_PASS_RATE=0.98
export DHC_A11Y_TREND_MIN_PHRASE_SUCCESS_RATE=0.98
export DHC_A11Y_TREND_MIN_SEMANTICS_RATE=0.98
export DHC_A11Y_TREND_MIN_LIVEREGION_RATE=0.98
export DHC_A11Y_TREND_MAX_PASS_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_PHRASE_SUCCESS_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_SEMANTICS_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_LIVEREGION_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS=3

"$DART_BIN" tool/analyze_compare_accessibility_trends.dart \
  run1.log run2.log \
  --window-runs 7 \
  --output-json
```

Outputs:

- `COMPARE_REPLAY_A11Y_TREND_SUMMARY mode=<runs|days> value=<n>`
- `COMPARE_REPLAY_A11Y_TREND_SUMMARY_JSON=<json>`

Window mode notes:

- `--window-runs N` selects last `N` parsed runs after sorting by timestamp.
- `--window-days N` selects runs that occur in the last `N` days (based on parsed timestamps / fallback timestamps).
- If no run falls into the `--window-days` range, it falls back to last-`N` runs to keep
  review output stable.

Outputs (human summary includes):

- `COMPARE_REPLAY_A11Y_TREND_SUMMARY mode=<runs|days> value=<n>`
- `alerts=<json-array>` (present when risk thresholds are hit)
- `COMPARE_REPLAY_A11Y_TREND_SUMMARY_JSON=<json>`
- `rateTrend=<json>` with first/last/delta/direction for pass、phraseSuccess、semantics、liveRegion
- `rateTrend.*` now also includes `maxConsecutiveDownRuns` and `maxDrop` (largest single-step drop in selected window).
- `recurrenceWindow=<n>` (window used for recurrence detection)
- `recurrenceCandidates=<json-array>`
- `recurrenceThresholds=<json-object>` with `maxRecurrenceCount` / `maxAbsenceRuns`

Recommended interpretation:

- `schemaMismatchCount > 0` indicates contract drift risk.
- Rising `unknownSeverity` should trigger contract-key review.
- `phraseSuccessRate` / `semanticsRate` / `liveRegionRate` moving down over window should be investigated.

Suggested next upgrades:

- Consume `rateTrend` in threshold checks:
  - Alert when `rateTrend.<metric>.maxDrop` exceeds `DHC_A11Y_TREND_MAX_*_RATE_DROP`.
  - Alert when `rateTrend.<metric>.maxConsecutiveDownRuns` exceeds `DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS`.
- Consume recurrence candidates in escalation rules:
  - Alert when `recurrenceCount > DHC_A11Y_TREND_MAX_RECURRENCE_COUNT`.
  - Alert when `maxAbsenceRuns > DHC_A11Y_TREND_MAX_ABSENCE_RUNS` (persistent gaps).
  - Keep recurrence alerts isolated from raw trend alerts by setting `maxRecurrenceCount` and
    `maxConsecutiveDownRuns` (`DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS`) as separate budgets.
- Feed alerts into CI or external log sink for paging thresholds. CI strict mode is activated when `CI=true` or `DHC_A11Y_TREND_FAIL_ON_ALERTS=true`.
- Keep alert fields aligned with `docs/compare_replay_accessibility_ci_contract.md`.

Suggested practical upgrade path:

- Start each local trend run with a local history file (`--history-file`) to compare across PR runs and sessions.
- Set `--trend-noise-window` to `2` or `3` so a newly introduced warning must repeat for multiple windows before CI blocks.
- Add recurrence controls: `--recurrence-window`, `DHC_A11Y_TREND_MAX_RECURRENCE_COUNT`,
  `DHC_A11Y_TREND_MAX_ABSENCE_RUNS`.
- 建议对 `recurrenceCandidates` 做 `7 / 14 / 30` 天抽样复发校验：
  - `recurrenceCount=0` 重点归为持续噪声，适合回归到单点收敛策略。
  - `recurrenceCount>=1 && maxAbsenceRuns>=recurrenceWindow` 重点归类为抖动后复发，建议提升观察优先级。
  - `recurrenceCount>=1 && maxAbsenceRuns<recurrenceWindow` 侧重验证时间戳对齐与去重边界。
- Export history snapshots to a trend dashboard (e.g. `compare_replay_accessibility_trend_history.jsonl`) when doing longer-running stability studies.

Dashboard command for 日报/周报：

```bash
"$DART_BIN" tool/build_compare_accessibility_trend_digest.dart \
  /tmp/compare_replay_accessibility_trend_history.jsonl \
  --scope compare_replay_accessibility \
  --daily-limit 14 \
  --weekly-limit 8 \
  --regression-window 2 \
  --recurrence-window 2
```

Dashboard env alias (same defaults as CLI)：

```bash
export DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT=14
export DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT=8
export DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW=2
export DHC_A11Y_TREND_RECURRENCE_WINDOW=2
export DHC_A11Y_TREND_MAX_RECURRENCE_COUNT=0
export DHC_A11Y_TREND_MAX_ABSENCE_RUNS=999
```

This command outputs:

- daily/weekly aggregate rates and cumulative severity counters,
- alert frequency by severity and top alert IDs,
- stable blocking alerts that appear in `N` consecutive runs (`--regression-window`).

`COMPARE_REPLAY_A11Y_TREND_DASHBOARD_SUMMARY_JSON` includes:

- `alertSummary.total`, `alertSummary.byLevel`, `alertSummary.topAlertIds`.
- `stableAlertCandidates` list with:
  - `id`
  - `consecutiveBlockingRuns`
  - `requiredConsecutiveRuns`
- `dashboardMeta` with env variable names for regression/daily/weekly thresholds.
- `dashboardMeta.recurrenceWindowEnv` with recurrence-detection window env alias.

`stableAlertCandidates` 补充 `抖动窗口外复发` 指标（用于科研/治理队列跟踪）：

- `recurrenceWindow`: 用于判断复发的窗口阈值（默认 `2`）。
- `recurrenceCount`: 是否出现“至少一次间隔>=recurrenceWindow后再次出现”的复发次数。
- `maxAbsenceRuns`: 复发段间最大空窗长度（按历史采样点计）。
- `episodeCount`: 告警在历史中的连续块数量。
- `longestEpisodeRuns`: 最大连续告警块长度。
- `lastEpisodeRuns`: 近期最后一段连续告警长度。

示例解读：

- `recurrenceCount=0` 优先归入“持续高频收敛问题”，更像回归尚未消退。
- `recurrenceCount>=1 && maxAbsenceRuns>=recurrenceWindow` 更像“抖动后复发”，建议同时对照 `7/14/30` 日区间做复核。
- `episodeCount` 大且 `lastEpisodeRuns` 小，通常对应短促反复，适合延后严格阻断但保留观察。

Optional trend gating:

```bash
export DHC_A11Y_TREND_MAX_SCHEMA_MISMATCH=0
export DHC_A11Y_TREND_MAX_UNKNOWN_SEVERITY=0
export DHC_A11Y_TREND_MIN_PASS_RATE=0.98
export DHC_A11Y_TREND_MIN_PHRASE_SUCCESS_RATE=0.98
export DHC_A11Y_TREND_MIN_SEMANTICS_RATE=0.98
export DHC_A11Y_TREND_MIN_LIVEREGION_RATE=0.98
export DHC_A11Y_TREND_MAX_PASS_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_PHRASE_SUCCESS_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_SEMANTICS_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_LIVEREGION_RATE_DROP=0.02
export DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS=3
export DHC_A11Y_TREND_RECURRENCE_WINDOW=2
export DHC_A11Y_TREND_MAX_RECURRENCE_COUNT=0
export DHC_A11Y_TREND_MAX_ABSENCE_RUNS=999
export DHC_A11Y_TREND_HISTORY_FILE=/tmp/compare_replay_accessibility_trend_history.jsonl
export DHC_A11Y_TREND_HISTORY_MAX_ENTRIES=50
export DHC_A11Y_TREND_TREND_NOISE_WINDOW=2
export DHC_A11Y_TREND_FAIL_ON_ALERTS=true
```

Future upgrade hooks (in priority order):

- 已接入：`DHC_A11Y_TREND_DASHBOARD_*` env alias 与 dashboard `stableAlertCandidates` 输出。
- 进行中：补充“抖动窗口外回归”验证（连续告警是否在外部 `7/14/30` 天窗口中稳定复发）并评估误报率对阈值设计的影响。
- 已完成：`stableAlertCandidates` 增补复发指标输出（`recurrenceCount`、`maxAbsenceRuns`、`episodeCount`）。
  - 下一个动作：将 `recurrenceCandidates` 与 `recurrenceThresholds` 写入升级队列观察模板，并在 `7/14/30` 天窗口做复发/误报率抽样。
- 进行中：建设轻量看板服务入口，消费 `*trend_history.jsonl` 形成可归档日报/周报与告警衰减观察。
