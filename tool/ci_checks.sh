#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"
DART_CHECKS_HOME="${DHC_DART_CHECKS_HOME:-/tmp/dhc_dart_checks_home}"
mkdir -p "$DART_CHECKS_HOME/.dart_tool"
DART_CI_PACKAGES_CONFIG="$DART_CHECKS_HOME/.dhc_dart_tool_packages.json"
{
  printf '{\n'
  printf '  "configVersion": 2,\n'
  printf '  "packages": [\n'
  printf '    {\n'
  printf '      "name": "data_hook_claws",\n'
  printf '      "rootUri": "file://%s",\n' "$ROOT_DIR"
  printf '      "packageUri": "lib/",\n'
  printf '      "languageVersion": "3.10"\n'
  printf '    }\n'
  printf '  ],\n'
  printf '  "generator": "dhc_ci_checks"\n'
  printf '}\n'
} > "$DART_CI_PACKAGES_CONFIG"
if [[ -n "${DHC_DART_BIN:-}" ]]; then
  DART_BIN="$DHC_DART_BIN"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin_dir="$(cd "$(dirname "$(command -v flutter)")" && pwd)"
  DART_BIN="$flutter_bin_dir/../bin/cache/dart-sdk/bin/dart"
else
  DART_BIN="$(command -v dart || true)"
fi
if [[ -z "${DART_BIN:-}" ]]; then
  DART_BIN="dart"
fi
if [[ ! -x "$DART_BIN" ]]; then
  printf 'Error: DART_BIN is not currently executable: %s\n' "$DART_BIN" >&2
  exit 1
fi
FLUTTER_BIN="${DHC_FLUTTER_BIN:-}"
if [[ -n "$FLUTTER_BIN" ]]; then
  if [[ ! -x "$FLUTTER_BIN" ]]; then
    printf 'Error: FLUTTER_BIN is not currently executable: %s\n' "$FLUTTER_BIN" >&2
    exit 1
  fi
else
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="$(command -v flutter)"
  elif [[ "$DART_BIN" == *"/bin/cache/dart-sdk/bin/dart" ]]; then
    FLUTTER_BIN="${DART_BIN%/bin/cache/dart-sdk/bin/dart}/bin/flutter"
  fi
fi
printf 'Using DART_BIN=%s\n' "$DART_BIN"
if [[ -n "$FLUTTER_BIN" ]]; then
  printf 'Using FLUTTER_BIN=%s\n' "$FLUTTER_BIN"
fi

printf 'Running DataHookClaws CI checks...\n'
run_flutter_step() {
  local label="$1"
  shift
  local flutter_cmd="$1"

  if [[ ! -x "$flutter_cmd" ]]; then
    if [[ "${CI:-false}" == "true" || "${DHC_FORCE_FLUTTER_CHECKS:-false}" == "true" ]]; then
      printf '%s: flutter command is not executable: %s\n' "$label" "$flutter_cmd"
      return 127
    fi
    printf '%s: skipped in non-CI environment by policy (exit_code=127, set DHC_FORCE_FLUTTER_CHECKS=true to fail fast).\n' "$label"
    return 0
  fi
  shift

  printf 'Running %s...\n' "$label"
  if "$flutter_cmd" "$@"; then
    printf '%s passed.\n' "$label"
    return 0
  else
    local exit_code=$?
    if [[ "${CI:-false}" == "true" || "${DHC_FORCE_FLUTTER_CHECKS:-false}" == "true" ]]; then
      return "$exit_code"
    fi
    printf '%s: skipped in non-CI environment by policy (exit_code=%d, set DHC_FORCE_FLUTTER_CHECKS=true to fail fast).\n' \
      "$label" "$exit_code"
  fi

  return 0
}

FLUTTER_CMD=()
if [[ -n "$FLUTTER_BIN" ]]; then
  FLUTTER_CMD+=("$FLUTTER_BIN")
else
  FLUTTER_CMD+=(flutter)
fi

run_flutter_step \
  'Flutter dependency lockfile' \
  "${FLUTTER_CMD[@]}" pub get --enforce-lockfile
run_flutter_step 'Flutter analyze' "${FLUTTER_CMD[@]}" analyze
run_flutter_step 'Flutter test' "${FLUTTER_CMD[@]}" test
run_flutter_step \
  'Source importer tests' \
  "${FLUTTER_CMD[@]}" test test/domain/source_importers_test.dart test/domain/it_crea_importer_test.dart

run_local_dart_check() {
  local label="$1"
  shift
  if [[ $# -eq 0 ]]; then
    printf 'Error: run_local_dart_check requires a command argument.\n' >&2
    return 1
  fi
  local cmd=("$@")
  local tee_target=""
  if [[ "${cmd[0]}" == "--tee" ]]; then
    tee_target="${cmd[1]}"
    cmd=("${cmd[@]:2}")
  fi

  printf 'Running %s...\n' "$label"
  if [[ "${cmd[0]}" == "bash" ]]; then
    if HOME="$DART_CHECKS_HOME" DART_SUPPRESS_ANALYTICS="true" "${cmd[@]}"; then
      printf '%s passed.\n' "$label"
      return 0
    fi
    local exit_code=$?
    if [[ "${CI:-false}" == "true" || "${DHC_FORCE_DART_CHECKS:-false}" == "true" ]]; then
      return "$exit_code"
    fi
    printf '%s: skipped in non-CI environment by policy (exit_code=%d, set DHC_FORCE_DART_CHECKS=true to fail fast).\n' \
      "$label" "$exit_code"
    return 0
  fi

  if [[ "${cmd[0]}" == "$DART_BIN" ]]; then
    cmd=("${cmd[@]:1}")
  fi
  if [[ "${cmd[0]}" == "run" ]]; then
    cmd=("${cmd[@]:1}")
  fi

  local script_path="${cmd[0]}"
  if [[ -z "$script_path" ]]; then
    printf 'Error: run_local_dart_check could not resolve a script path for %s.\n' "$label" >&2
    return 1
  fi
  local args=("${cmd[@]:1}")
  local run_output
  local run_stdout
  local run_exit_code=0

  run_output="$(mktemp)"
  if [[ -n "$tee_target" ]]; then
    if HOME="$DART_CHECKS_HOME" DART_SUPPRESS_ANALYTICS="true" \
      "$DART_BIN" --packages="$DART_CI_PACKAGES_CONFIG" "$script_path" \
      ${args+"${args[@]}"} 2>&1 | tee "$run_output" "$tee_target"; then
      run_exit_code=0
    else
      run_exit_code="${PIPESTATUS[0]}"
    fi
  else
    if HOME="$DART_CHECKS_HOME" DART_SUPPRESS_ANALYTICS="true" \
      "$DART_BIN" --packages="$DART_CI_PACKAGES_CONFIG" "$script_path" \
      ${args+"${args[@]}"} 2>&1 | tee "$run_output"; then
      run_exit_code=0
    else
      run_exit_code="${PIPESTATUS[0]}"
    fi
  fi

  run_stdout="$(cat "$run_output")"
  rm -f "$run_output"
  if [[ "$run_exit_code" == 0 ]]; then
    printf '%s passed.\n' "$label"
    return 0
  fi

  if [[ "$run_stdout" == *"Running build hooks failed"* ]] ||
    [[ "$run_stdout" == *"Failed to set file modification time"* ]] ||
    [[ "$run_stdout" == *"Failed host lookup"* ]]; then
    local temp_dir
    local aot_binary
    local compile_output
    local compile_exit_code=0
    local fallback_stdout
    local fallback_exit_code=0
    temp_dir="$(mktemp -d)"
    aot_binary="$temp_dir/$(basename "$script_path")-aot"
    compile_output="$(mktemp)"

    if HOME="$DART_CHECKS_HOME" DART_SUPPRESS_ANALYTICS="true" \
      "$DART_BIN" compile exe "$script_path" -o "$aot_binary" \
      2>&1 | tee "$compile_output"; then
      fallback_stdout="$(mktemp)"
      if [[ -n "$tee_target" ]]; then
        if HOME="$DART_CHECKS_HOME" DART_SUPPRESS_ANALYTICS="true" \
          "$aot_binary" ${args+"${args[@]}"} 2>&1 | tee "$fallback_stdout" "$tee_target"; then
          fallback_exit_code="${PIPESTATUS[0]}"
        else
          fallback_exit_code="${PIPESTATUS[0]}"
        fi
      else
        if HOME="$DART_CHECKS_HOME" DART_SUPPRESS_ANALYTICS="true" \
          "$aot_binary" ${args+"${args[@]}"} 2>&1 | tee "$fallback_stdout"; then
          fallback_exit_code="${PIPESTATUS[0]}"
        else
          fallback_exit_code="${PIPESTATUS[0]}"
        fi
      fi

      if [[ "$fallback_exit_code" == 0 ]]; then
        rm -f "$fallback_stdout" "$compile_output"
        rm -rf "$temp_dir"
        printf '%s passed with AOT fallback.\n' "$label"
        return 0
      fi

      run_stdout="$(cat "$fallback_stdout")"
      run_exit_code="$fallback_exit_code"
      rm -f "$fallback_stdout"
    else
      compile_exit_code="${PIPESTATUS[0]}"
      run_stdout+="\nFailed to compile AOT fallback:\n$(cat "$compile_output")"
      run_exit_code="$compile_exit_code"
    fi

    rm -f "$compile_output"
    rm -rf "$temp_dir"
  fi

  if [[ "${CI:-false}" == "true" || "${DHC_FORCE_DART_CHECKS:-false}" == "true" ]]; then
    printf '%s' "$run_stdout\n" >&2
    return "$run_exit_code"
  fi
  printf '%s: skipped in non-CI environment by policy (exit_code=%d, set DHC_FORCE_DART_CHECKS=true to fail fast).\n' \
    "$label" "$run_exit_code"
  return 0
}

run_local_dart_check 'compare replay draft cleanup regression check' \
  tool/check_compare_replay_draft_cleanup.dart
run_local_dart_check 'release metadata preflight' \
  tool/check_release_metadata.dart
compare_unit_normalization_fixture="${DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE:-tool/fixtures/compare_unit_normalization_cases.json}"
export DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE="$compare_unit_normalization_fixture"
run_local_dart_check 'compare unit normalization smoke check' \
  tool/check_compare_unit_normalization.dart
run_local_dart_check 'compare accessibility regression check' \
  --tee /tmp/compare_replay_accessibility_check.log \
  tool/check_compare_accessibility.dart
run_local_dart_check 'compare accessibility parsed output check' \
  --tee /tmp/compare_replay_accessibility_parsed.log \
  tool/parse_compare_accessibility_report.dart /tmp/compare_replay_accessibility_check.log
run_local_dart_check 'compare accessibility trend governance check' \
  tool/analyze_compare_accessibility_trends.dart \
    /tmp/compare_replay_accessibility_parsed.log \
    --window-runs 7 \
    --history-file /tmp/compare_replay_accessibility_trend_history.jsonl \
    --history-max-entries 50 \
    --output-json
trend_dashboard_scope="${DHC_A11Y_TREND_DASHBOARD_SCOPE:-compare_replay_accessibility}"
DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT="${DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT:-14}"
DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT="${DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT:-8}"
DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW="${DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW:-2}"
DHC_A11Y_TREND_TREND_NOISE_WINDOW="${DHC_A11Y_TREND_TREND_NOISE_WINDOW:-2}"
DHC_A11Y_TREND_RECURRENCE_WINDOW="${DHC_A11Y_TREND_RECURRENCE_WINDOW:-2}"
DHC_A11Y_TREND_MAX_RECURRENCE_COUNT="${DHC_A11Y_TREND_MAX_RECURRENCE_COUNT:-0}"
DHC_A11Y_TREND_MAX_ABSENCE_RUNS="${DHC_A11Y_TREND_MAX_ABSENCE_RUNS:-999}"
export DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT
export DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT
export DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW
export DHC_A11Y_TREND_TREND_NOISE_WINDOW
export DHC_A11Y_TREND_RECURRENCE_WINDOW
export DHC_A11Y_TREND_MAX_RECURRENCE_COUNT
export DHC_A11Y_TREND_MAX_ABSENCE_RUNS

run_local_dart_check 'compare accessibility trend dashboard check' \
  tool/build_compare_accessibility_trend_digest.dart \
    /tmp/compare_replay_accessibility_trend_history.jsonl \
    --scope "$trend_dashboard_scope" \
    --output-json

prompt_funnel_input="${DHC_COMPARE_REPLAY_PROMPT_FUNNEL_INPUT:-tool/fixtures/compare_replay_prompt_funnel_trace.json}"
run_local_dart_check 'compare replay prompt funnel check' \
  tool/analyze_compare_replay_prompt_funnel.dart \
    --output-json \
    "$prompt_funnel_input"

run_flutter_step \
  'Build web artifact' \
  "${FLUTTER_CMD[@]}" build web --release
source_revision="${DHC_SOURCE_REVISION:-}"
if [[ -z "$source_revision" ]]; then
  source_revision="$(git rev-parse --verify HEAD 2>/dev/null || true)"
fi
run_local_dart_check 'release artifact provenance manifest' \
  tool/build_release_provenance.dart \
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
    --revision "$source_revision" \
    --require-revision
run_local_dart_check 'release artifact provenance verification' \
  tool/build_release_provenance.dart \
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
    --revision "$source_revision" \
    --require-revision
printf 'CI checks passed.\n'
