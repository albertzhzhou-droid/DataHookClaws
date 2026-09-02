# Compare replay accessibility CI contract (v1.0.1)

This contract defines the machine-readable artifact contract for
`tool/check_compare_accessibility.dart` and
`tool/parse_compare_accessibility_report.dart`.

## Scope

- Inputs: compare replay snapshot template + source code snapshot content scanned by
  `tool/check_compare_accessibility.dart`.
- Output channel: CI log lines that can be parsed from local or GitHub Actions runs.
- Version: `schemaVersion` in `docs/compare_replay_accessibility_snapshot_template.json`.

## Emitted blocks

`check_compare_accessibility.dart` must emit these blocks in each successful run:

- `COMPARE_REPLAY_A11Y_TEMPLATE_REPORT_START`
- one human-readable summary line:
  - `compare replay accessibility template checks: ...`
- `COMPARE_REPLAY_A11Y_TEMPLATE_SEVERITY: <comma-separated buckets>`
- `COMPARE_REPLAY_A11Y_TEMPLATE_SUMMARY_JSON=<json>`
- one line per failed case/phrase:
  - `COMPARE_REPLAY_A11Y_CASE ...`
  - `COMPARE_REPLAY_A11Y_PHRASE ...`
- `COMPARE_REPLAY_A11Y_TEMPLATE_REPORT_END`

If the marker block is missing or order is invalid, parser emits an integrity warning.

## JSON summary payload schema

`COMPARE_REPLAY_A11Y_TEMPLATE_SUMMARY_JSON` must be a JSON object containing:

- `schemaVersion` (string)
- `snapshotScope` (string)
- `caseCount` (int)
- `casesPassed` (int)
- `casesFailed` (int)
- `phraseCount` (int)
- `phraseFoundCount` (int)
- `phraseMissingCount` (int)
- `phraseSemanticsPassCount` (int)
- `phraseSemanticsFailCount` (int)
- `liveRegionCheckedCount` (int)
- `liveRegionPassCount` (int)
- `liveRegionFailCount` (int)
- `severityBuckets` (object map string → int, required, keys from:
  `critical|high|medium|low|info|warning`, plus `missing|invalid` when needed)

`COMPARE_REPLAY_A11Y_PARSED_JSON` additionally carries parser execution timestamp:

- `runTimestampUtc` (string, optional, ISO-8601 UTC)

This is a convenience field for trend tooling when no explicit timestamp exists on log lines.

String length hard limit: `1048576`.

## Parser outputs

`tool/parse_compare_accessibility_report.dart` extracts this line and emits:

- `COMPARE_REPLAY_A11Y_CI_METRICS ...`
  - `schemaVersion`, `snapshotScope`
  - `caseCount`, `casesPassed`, `casesFailed`
  - `phraseCount`, `phraseMissing`, `phraseFound`, `phraseSemanticsPass`, `phraseSemanticsFail`
  - `liveRegionChecked`, `liveRegionPass`, `liveRegionFail`
  - `severityBuckets=<json>`
  - payload length check (exceeding 1,048,576 emits `COMPARE_REPLAY_A11Y_CI_REPORT_JSON_LENGTH_EXCEEDED`)
  - `passRate`
- `COMPARE_REPLAY_A11Y_PARSED_JSON=<json>`
- Optional budget checks:
  - `COMPARE_REPLAY_A11Y_CI_REPORT_BUDGET_VIOLATION`
- Optional marker checks:
  - `COMPARE_REPLAY_A11Y_CI_REPORT_INTEGRITY_WARNING`
  - `COMPARE_REPLAY_A11Y_CI_REPORT_JSON_LENGTH_EXCEEDED`

Any parse error uses `COMPARE_REPLAY_A11Y_REPORT_PARSE_ERROR`.

## Trend governance script (tool/analyze_compare_accessibility_trends.dart)

`tool/analyze_compare_accessibility_trends.dart` consumes one or more files/logs that
contain `COMPARE_REPLAY_A11Y_PARSED_JSON=<json>` lines and emits:

- `COMPARE_REPLAY_A11Y_TREND_SUMMARY ...`
- `COMPARE_REPLAY_A11Y_TREND_SUMMARY_JSON=<json>`
- optional `alerts=<json-array>` in human output
- optional `recurrenceCandidates=<json-array>` in human output

`tool/build_compare_accessibility_trend_digest.dart` consumes trend history JSONL (from
`--history-file`) and emits dashboard summary markers:

- `COMPARE_REPLAY_A11Y_TREND_DASHBOARD_DAILY=<json>`
- `COMPARE_REPLAY_A11Y_TREND_DASHBOARD_WEEKLY=<json>`
- `COMPARE_REPLAY_A11Y_TREND_DASHBOARD_ALERTS=<json>`
- `COMPARE_REPLAY_A11Y_TREND_DASHBOARD_STABLE_ALERTS=<json>` (optional)
- `COMPARE_REPLAY_A11Y_TREND_DASHBOARD_SUMMARY_JSON=<json>`

`COMPARE_REPLAY_A11Y_TREND_DASHBOARD_SUMMARY_JSON` contains:

- `scope` (string)
- `historyFile` (string)
- `scopeFilter` (string|null)
- `entryCount` (int)
- `dailyLimit`, `weeklyLimit`, `regressionWindow` (int)
- `daily`, `weekly` aggregate arrays
- `global` summary fields
- `alertSummary` (object)
- `stableAlertCandidates` (array)
- `recurrenceWindow` (int)
- `dashboardMeta`:
  - `source` (`trendHistory`)
  - `regressionWindowEnv` (`DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW`)
  - `dailyLimitEnv` (`DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT`)
  - `weeklyLimitEnv` (`DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT`)
  - `recurrenceWindowEnv` (`DHC_A11Y_TREND_RECURRENCE_WINDOW`)

`stableAlertCandidates` entries now include recurrence metrics:

- `recurrenceWindow` (int)
- `recurrenceCount` (int)
- `maxAbsenceRuns` (int)
- `episodeCount` (int)
- `longestEpisodeRuns` (int)
- `lastEpisodeRuns` (int)

`rateTrend` in summary JSON includes per-metric trend entries:

- `first`, `last`, `delta`, `direction`
- `maxConsecutiveDownRuns`
- `maxDrop` (largest single-step drop in selected window)

`recurrence` fields in trend summary include:

- `recurrenceWindow` (int)
- `recurrenceThresholds` (object):
  - `maxRecurrenceCount` (int)
  - `maxAbsenceRuns` (int)
- `recurrenceCandidates` (array):
  - `id`
  - `recurrenceCount`
  - `maxAbsenceRuns`
  - `episodeCount`
  - `longestEpisodeRuns`
  - `lastEpisodeRuns`
  - `consecutiveBlockingRuns`

Top-level `trendHistory` metadata appears when history persistence is enabled:

- `historyFile`
- `historyMaxEntries`
- `trendNoiseWindow`
- `priorHistoryEntryCount`

- `alerts` may include denoise fields:
  - `noiseSuppressed` (true when still in warm-up window)
  - `noiseWindow`
  - `observedConsecutiveRuns`

Trend alert thresholds are controlled by:

- `DHC_A11Y_TREND_MAX_SCHEMA_MISMATCH`
- `DHC_A11Y_TREND_MAX_UNKNOWN_SEVERITY`
- `DHC_A11Y_TREND_MIN_PASS_RATE`
- `DHC_A11Y_TREND_MIN_PHRASE_SUCCESS_RATE`
- `DHC_A11Y_TREND_MIN_SEMANTICS_RATE`
- `DHC_A11Y_TREND_MIN_LIVEREGION_RATE`
- `DHC_A11Y_TREND_MAX_PASS_RATE_DROP`
- `DHC_A11Y_TREND_MAX_PHRASE_SUCCESS_RATE_DROP`
- `DHC_A11Y_TREND_MAX_SEMANTICS_RATE_DROP`
- `DHC_A11Y_TREND_MAX_LIVEREGION_RATE_DROP`
- `DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS`
- `DHC_A11Y_TREND_RECURRENCE_WINDOW`
- `DHC_A11Y_TREND_MAX_RECURRENCE_COUNT`
- `DHC_A11Y_TREND_MAX_ABSENCE_RUNS`
- `DHC_A11Y_TREND_HISTORY_FILE`
- `DHC_A11Y_TREND_HISTORY_MAX_ENTRIES`
- `DHC_A11Y_TREND_TREND_NOISE_WINDOW`
- `DHC_A11Y_TREND_FAIL_ON_ALERTS`
- `DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT`
- `DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT`
- `DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW`

Stable alert output:

- `COMPARE_REPLAY_A11Y_TREND_DASHBOARD_STABLE_ALERTS` should appear when stable warn/error candidates are detected.
- 每个候选项至少包含：
  - `id`
  - `consecutiveBlockingRuns`
  - `requiredConsecutiveRuns`

Trend mode is strict when either:

- `CI=true`
- `DHC_A11Y_TREND_FAIL_ON_ALERTS=true`

## Failure budgets

Parser exits non-zero in strict mode when any threshold is exceeded.

- Strict mode is enabled when either:
  - `CI=true`
  - `DHC_A11Y_REPORT_STRICT=true`
- Budget variables:
  - `DHC_A11Y_MAX_CASES_FAILED` (default 0)
  - `DHC_A11Y_MAX_PHRASE_MISSING` (default 0)
  - `DHC_A11Y_MAX_SEMANTIC_FAIL` (default 0)
  - `DHC_A11Y_MAX_LIVEREGION_FAIL` (default 0)
  - `DHC_A11Y_MAX_UNKNOWN_SEVERITY_BUCKET` (default 0)

## Lifecycle notes

- `check_compare_accessibility` should preserve current script behavior and marker names.
- Any change to `compareReplayNoDraftAccessibilitySnapshots` shape requires:
  - template migration note in this queue file
  - contract version alignment check in review notes.
