#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

const String _parsedLinePrefix = 'COMPARE_REPLAY_A11Y_PARSED_JSON=';
const String _runTimestampKey = 'runTimestampUtc';
const String _schemaVersion = '1.0.1';
const int _defaultWindowRuns = 7;
const int _defaultWindowDays = 7;
const String _windowRunsMode = 'runs';
const String _windowDaysMode = 'days';

const int _defaultMaxSchemaMismatch = 0;
const int _defaultMaxUnknownSeverity = 0;
const double _defaultMinPassRate = 0.95;
const double _defaultMinPhraseSuccessRate = 0.98;
const double _defaultMinSemanticsRate = 0.98;
const double _defaultMinLiveRegionRate = 0.98;
const double _defaultMaxPassRateDrop = 0.02;
const double _defaultMaxPhraseSuccessRateDrop = 0.02;
const double _defaultMaxSemanticsRateDrop = 0.02;
const double _defaultMaxLiveRegionRateDrop = 0.02;
const int _defaultMaxConsecutiveDownRuns = 3;
const int _defaultTrendHistoryMaxEntries = 50;
const int _defaultTrendNoiseWindow = 1;
const int _defaultRecurrenceWindow = 2;
const int _defaultMaxRecurrenceCount = 0;
const int _defaultMaxAbsenceRuns = 999;

final RegExp _isoTimestampPattern = RegExp(
  r'(\d{4}-\d{2}-\d{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(?:[.,][0-9]{1,9})?(?:Z|[+-][0-9]{2}:?[0-9]{2})?)',
);

void main(List<String> args) {
  final options = _parseOptions(args);

  if (options.showHelp) {
    _printUsage();
    return;
  }

  if (options.files.isEmpty && stdin.hasTerminal) {
    _printUsage();
    return;
  }

  final runs = <_RunMetrics>[];
  final sources = options.files.isNotEmpty
      ? options.files
      : <String>['<stdin>'];

  for (final source in sources) {
    final fallbackTimestamp = source == '<stdin>'
        ? DateTime.now().toUtc()
        : _sourceFileLastModifiedUtc(source);
    final lines = source == '<stdin>'
        ? _readStdinLines()
        : File(source).readAsLinesSync();
    for (final line in lines) {
      final parsed = _extractParsedJson(line);
      if (parsed == null) {
        continue;
      }
      final run = _RunMetrics.fromJson(
        parsed.payload,
        source: source,
        timestamp: parsed.timestamp ?? fallbackTimestamp,
      );
      if (run != null) {
        runs.add(run);
      }
    }
  }

  if (runs.isEmpty) {
    stderr.writeln(
      'COMPARE_REPLAY_A11Y_TREND_INFO: no parsed JSON lines found; expected '
      '$_parsedLinePrefix',
    );
    exit(2);
  }

  runs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final selection = _selectWindow(runs, options);
  final summary = _buildSummary(
    selection.runs,
    options: options,
    totalRuns: runs.length,
    windowCutoff: selection.windowCutoff,
    fallbackUsed: selection.fallbackUsed,
  );

  final priorHistory = _readTrendHistory(
    path: options.historyFile,
    maxEntries: options.historyMaxEntries,
  );
  final noiseSuppressedAlerts = _applyTrendNoiseSuppression(
    alerts: (summary['alerts'] as List<Map<String, dynamic>>),
    priorHistory: priorHistory,
    noiseWindow: options.trendNoiseWindow,
  );
  final recurrenceCandidates = _buildRecurrenceCandidates(
    priorHistory: priorHistory,
    currentAlerts: noiseSuppressedAlerts,
    recurrenceWindow: options.recurrenceWindow,
  );
  final recurrenceAlerts = _buildRecurrenceThresholdAlerts(
    recurrenceCandidates: recurrenceCandidates,
    maxRecurrenceCount: options.maxRecurrenceCount,
    maxAbsenceRuns: options.maxAbsenceRuns,
  );
  summary['alerts'] = <Map<String, dynamic>>[
    ...noiseSuppressedAlerts,
    ...recurrenceAlerts,
  ];
  summary['trendHistory'] = <String, dynamic>{
    'historyFile': options.historyFile,
    'historyMaxEntries': options.historyMaxEntries,
    'trendNoiseWindow': options.trendNoiseWindow,
    'priorHistoryEntryCount': priorHistory.length,
  };
  summary['recurrenceWindow'] = options.recurrenceWindow;
  summary['recurrenceCandidates'] = recurrenceCandidates;
  summary['recurrenceThresholds'] = {
    'maxRecurrenceCount': options.maxRecurrenceCount,
    'maxAbsenceRuns': options.maxAbsenceRuns,
  };

  if (options.outputJsonOnly) {
    stdout.writeln(jsonEncode(summary));
  } else {
    _printHumanSummary(summary, options);
  }

  _appendTrendHistory(
    path: options.historyFile,
    maxEntries: options.historyMaxEntries,
    summary: summary,
  );

  if (_shouldFailOnTrendAlerts(summary['alerts'] as List<dynamic>?)) {
    stderr.writeln(
      'COMPARE_REPLAY_A11Y_TREND_GOVERNANCE_ALERTS=${jsonEncode(summary['alerts'])}',
    );
    exit(1);
  }
}

_Options _parseOptions(List<String> args) {
  var windowMode = _windowRunsMode;
  var windowValue = _defaultWindowRuns;
  var showHelp = false;
  var outputJsonOnly = false;
  var historyFile = Platform.environment['DHC_A11Y_TREND_HISTORY_FILE'];
  var historyMaxEntries =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_HISTORY_MAX_ENTRIES'] ?? '',
      ) ??
      _defaultTrendHistoryMaxEntries;
  var trendNoiseWindow =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_TREND_NOISE_WINDOW'] ?? '',
      ) ??
      _defaultTrendNoiseWindow;
  var recurrenceWindow =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_RECURRENCE_WINDOW'] ?? '',
      ) ??
      _defaultRecurrenceWindow;
  var maxRecurrenceCount =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_MAX_RECURRENCE_COUNT'] ?? '',
      ) ??
      _defaultMaxRecurrenceCount;
  var maxAbsenceRuns =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_MAX_ABSENCE_RUNS'] ?? '',
      ) ??
      _defaultMaxAbsenceRuns;
  final files = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--window-runs' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue > 0) {
        windowMode = _windowRunsMode;
        windowValue = parsedValue;
      }
      i += 1;
    } else if (arg == '--window-days' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue > 0) {
        windowMode = _windowDaysMode;
        windowValue = parsedValue;
      }
      i += 1;
    } else if (arg == '--history-file' && i + 1 < args.length) {
      historyFile = args[i + 1];
      i += 1;
    } else if (arg == '--history-max-entries' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue > 0) {
        historyMaxEntries = parsedValue;
      }
      i += 1;
    } else if (arg == '--trend-noise-window' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue > 0) {
        trendNoiseWindow = parsedValue;
      }
      i += 1;
    } else if (arg == '--recurrence-window' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue > 0) {
        recurrenceWindow = parsedValue;
      }
      i += 1;
    } else if (arg == '--max-recurrence-count' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue >= 0) {
        maxRecurrenceCount = parsedValue;
      }
      i += 1;
    } else if (arg == '--max-absence-runs' && i + 1 < args.length) {
      final parsedValue = int.tryParse(args[i + 1]);
      if (parsedValue != null && parsedValue >= 0) {
        maxAbsenceRuns = parsedValue;
      }
      i += 1;
    } else if (arg == '--output-json') {
      outputJsonOnly = true;
    } else if (arg == '--help' || arg == '-h') {
      showHelp = true;
      windowMode = _windowRunsMode;
      windowValue = _defaultWindowRuns;
      outputJsonOnly = false;
      break;
    } else {
      files.add(arg);
    }
  }

  if (windowMode == _windowRunsMode && windowValue < 1) {
    windowValue = _defaultWindowRuns;
  }
  if (windowMode == _windowDaysMode && windowValue < 1) {
    windowValue = _defaultWindowDays;
  }
  if (historyMaxEntries < 1) {
    historyMaxEntries = _defaultTrendHistoryMaxEntries;
  }
  if (trendNoiseWindow < 1) {
    trendNoiseWindow = _defaultTrendNoiseWindow;
  }
  if (recurrenceWindow < 1) {
    recurrenceWindow = _defaultRecurrenceWindow;
  }
  if (maxRecurrenceCount < 0) {
    maxRecurrenceCount = _defaultMaxRecurrenceCount;
  }
  if (maxAbsenceRuns < 0) {
    maxAbsenceRuns = _defaultMaxAbsenceRuns;
  }

  return _Options(
    windowMode: windowMode,
    windowValue: windowValue,
    showHelp: showHelp,
    outputJsonOnly: outputJsonOnly,
    files: files,
    historyFile: historyFile,
    historyMaxEntries: historyMaxEntries,
    trendNoiseWindow: trendNoiseWindow,
    recurrenceWindow: recurrenceWindow,
    maxRecurrenceCount: maxRecurrenceCount,
    maxAbsenceRuns: maxAbsenceRuns,
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/analyze_compare_accessibility_trends.dart '
    '[options] <log1> <log2> ...',
  );
  stdout.writeln('Options:');
  stdout.writeln(
    '  --window-runs <n>   analyze last n parsed runs (default 7, run-based)',
  );
  stdout.writeln(
    '  --window-days <n>   analyze runs in the last n days using parsed timestamps '
    '(default 7, day-based)',
  );
  stdout.writeln('  --output-json        emit compact JSON summary only');
  stdout.writeln(
    '  --history-file <path> append summary JSONL records to a local history file',
  );
  stdout.writeln(
    '  --history-max-entries <n> max history entries kept in file (default '
    '$_defaultTrendHistoryMaxEntries)',
  );
  stdout.writeln(
    '  --trend-noise-window <n> suppress alert fail until same alert repeats '
    'for n consecutive windows (default $_defaultTrendNoiseWindow)',
  );
  stdout.writeln(
    '  --recurrence-window <n> analyze recurrence patterns with history and '
    'recurrence window size (default $_defaultRecurrenceWindow)',
  );
  stdout.writeln(
    '  --max-recurrence-count <n> block when recurrence count > this threshold '
    '(default $_defaultMaxRecurrenceCount)',
  );
  stdout.writeln(
    '  --max-absence-runs <n> block when max absence-run length > this threshold '
    '(default $_defaultMaxAbsenceRuns)',
  );
  stdout.writeln(
    '  --help               print this help\n'
    'Alert env vars:\n'
    '  DHC_A11Y_TREND_MAX_SCHEMA_MISMATCH (default $_defaultMaxSchemaMismatch)\n'
    '  DHC_A11Y_TREND_MAX_UNKNOWN_SEVERITY (default $_defaultMaxUnknownSeverity)\n'
    '  DHC_A11Y_TREND_MIN_PASS_RATE (default $_defaultMinPassRate)\n'
    '  DHC_A11Y_TREND_MIN_PHRASE_SUCCESS_RATE (default $_defaultMinPhraseSuccessRate)\n'
    '  DHC_A11Y_TREND_MIN_SEMANTICS_RATE (default $_defaultMinSemanticsRate)\n'
    '  DHC_A11Y_TREND_MIN_LIVEREGION_RATE (default $_defaultMinLiveRegionRate)\n'
    '  DHC_A11Y_TREND_MAX_PASS_RATE_DROP (default $_defaultMaxPassRateDrop)\n'
    '  DHC_A11Y_TREND_MAX_PHRASE_SUCCESS_RATE_DROP (default $_defaultMaxPhraseSuccessRateDrop)\n'
    '  DHC_A11Y_TREND_MAX_SEMANTICS_RATE_DROP (default $_defaultMaxSemanticsRateDrop)\n'
    '  DHC_A11Y_TREND_MAX_LIVEREGION_RATE_DROP (default $_defaultMaxLiveRegionRateDrop)\n'
    '  DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS (default $_defaultMaxConsecutiveDownRuns)\n'
    '  DHC_A11Y_TREND_RECURRENCE_WINDOW (default $_defaultRecurrenceWindow)\n'
    '  DHC_A11Y_TREND_MAX_RECURRENCE_COUNT (default $_defaultMaxRecurrenceCount)\n'
    '  DHC_A11Y_TREND_MAX_ABSENCE_RUNS (default $_defaultMaxAbsenceRuns)\n'
    '  DHC_A11Y_TREND_FAIL_ON_ALERTS (default false, CI mode implies true)\n'
    'History env vars:\n'
    '  DHC_A11Y_TREND_HISTORY_FILE (optional path)\n'
    '  DHC_A11Y_TREND_HISTORY_MAX_ENTRIES (default $_defaultTrendHistoryMaxEntries)\n'
    '  DHC_A11Y_TREND_TREND_NOISE_WINDOW (default $_defaultTrendNoiseWindow)',
  );
}

List<String> _readStdinLines() {
  final buffer = <String>[];
  while (true) {
    final line = stdin.readLineSync();
    if (line == null) {
      break;
    }
    buffer.add(line);
  }
  return buffer;
}

_ParsedPayload? _extractParsedJson(String line) {
  final markerIndex = line.indexOf(_parsedLinePrefix);
  if (markerIndex < 0) {
    return null;
  }
  final payload = line.substring(markerIndex + _parsedLinePrefix.length);
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, Object?>) {
      return _ParsedPayload(
        payload: decoded,
        timestamp:
            _parseTimestampFromPayload(decoded[_runTimestampKey]) ??
            _parseTimestampFromLine(line),
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}

DateTime? _parseTimestampFromPayload(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }
    return parsed.toUtc();
  }
  return null;
}

DateTime? _parseTimestampFromLine(String line) {
  final match = _isoTimestampPattern.firstMatch(line);
  if (match == null || match.group(1) == null) {
    return null;
  }

  final normalized = match.group(1)!.replaceAll(',', '.');
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) {
    return null;
  }
  return parsed.toUtc();
}

DateTime _sourceFileLastModifiedUtc(String source) {
  try {
    return File(source).lastModifiedSync().toUtc();
  } catch (_) {
    return DateTime.now().toUtc();
  }
}

_WindowSelection _selectWindow(List<_RunMetrics> runs, _Options options) {
  if (options.windowMode == _windowDaysMode) {
    final cutoff = DateTime.now().toUtc().subtract(
      Duration(days: options.windowValue),
    );
    final windowed = runs
        .where((run) => !run.timestamp.isBefore(cutoff))
        .toList(growable: false);
    if (windowed.isNotEmpty) {
      return _WindowSelection(
        runs: windowed,
        windowCutoff: cutoff,
        fallbackUsed: false,
      );
    }

    if (runs.length <= options.windowValue) {
      return _WindowSelection(
        runs: runs,
        windowCutoff: cutoff,
        fallbackUsed: true,
      );
    }

    return _WindowSelection(
      runs: runs.sublist(runs.length - options.windowValue),
      windowCutoff: cutoff,
      fallbackUsed: true,
    );
  }

  if (runs.length <= options.windowValue) {
    return _WindowSelection(
      runs: runs,
      windowCutoff: null,
      fallbackUsed: false,
    );
  }

  return _WindowSelection(
    runs: runs.sublist(runs.length - options.windowValue),
    windowCutoff: null,
    fallbackUsed: false,
  );
}

Map<String, dynamic> _buildSummary(
  List<_RunMetrics> runs, {
  required _Options options,
  required int totalRuns,
  required bool fallbackUsed,
  DateTime? windowCutoff,
}) {
  var totalCases = 0;
  var totalCasesPassed = 0;
  var totalCasesFailed = 0;
  var totalPhraseFound = 0;
  var totalPhraseMissing = 0;
  var totalSemanticsPass = 0;
  var totalSemanticsFail = 0;
  var totalLiveChecked = 0;
  var totalLivePass = 0;
  var totalLiveFail = 0;
  var totalUnknownSeverity = 0;
  var schemaMismatchCount = 0;

  for (final run in runs) {
    totalCases += run.caseCount;
    totalCasesPassed += run.casesPassed;
    totalCasesFailed += run.casesFailed;
    totalPhraseFound += run.phraseFound;
    totalPhraseMissing += run.phraseMissing;
    totalSemanticsPass += run.phraseSemanticsPass;
    totalSemanticsFail += run.phraseSemanticsFail;
    totalLiveChecked += run.liveRegionChecked;
    totalLivePass += run.liveRegionPass;
    totalLiveFail += run.liveRegionFail;
    totalUnknownSeverity += run.unknownSeverity;
    if (run.schemaVersion != _schemaVersion) {
      schemaMismatchCount += 1;
    }
  }

  final passRate = totalCases == 0 ? 0.0 : totalCasesPassed / totalCases;
  final phraseSuccessRate = totalPhraseFound == 0
      ? 0.0
      : 1.0 - (totalPhraseMissing / (totalPhraseFound + totalPhraseMissing));
  final liveRegionRate = totalLiveChecked == 0
      ? 0.0
      : totalLivePass / totalLiveChecked;
  final semanticsRate = (totalPhraseFound + totalPhraseMissing) == 0
      ? 0.0
      : totalSemanticsPass / (totalPhraseFound + totalPhraseMissing);

  final rates = {
    'passRate': double.parse(passRate.toStringAsFixed(4)),
    'phraseSuccessRate': double.parse(phraseSuccessRate.toStringAsFixed(4)),
    'semanticsRate': double.parse(semanticsRate.toStringAsFixed(4)),
    'liveRegionRate': double.parse(liveRegionRate.toStringAsFixed(4)),
  };
  final trend = _computeRateTrend(runs);

  final alerts = <Map<String, dynamic>>[];
  alerts.addAll(
    _evaluateThresholdAlerts(
      schemaMismatchCount: schemaMismatchCount,
      unknownSeverity: totalUnknownSeverity,
      passRate: rates['passRate']!,
      phraseSuccessRate: rates['phraseSuccessRate']!,
      semanticsRate: rates['semanticsRate']!,
      liveRegionRate: rates['liveRegionRate']!,
    ),
  );
  alerts.addAll(_evaluateRateTrendAlerts(rateTrend: trend));

  return <String, dynamic>{
    'scope': 'compare_replay_accessibility',
    'windowMode': options.windowMode,
    'windowValue': options.windowValue,
    'windowRuns': options.windowMode == _windowRunsMode
        ? options.windowValue
        : null,
    'windowDays': options.windowMode == _windowDaysMode
        ? options.windowValue
        : null,
    'consideredRunCount': runs.length,
    'totalRunCountObserved': totalRuns,
    'windowFallbackUsed': fallbackUsed,
    'windowCutoff': windowCutoff?.toIso8601String(),
    'snapshotVersionExpected': _schemaVersion,
    'schemaMismatchCount': schemaMismatchCount,
    'aggregate': {
      'cases': totalCases,
      'casesPassed': totalCasesPassed,
      'casesFailed': totalCasesFailed,
      'phraseFound': totalPhraseFound,
      'phraseMissing': totalPhraseMissing,
      'phraseSemanticsPass': totalSemanticsPass,
      'phraseSemanticsFail': totalSemanticsFail,
      'liveRegionChecked': totalLiveChecked,
      'liveRegionPass': totalLivePass,
      'liveRegionFail': totalLiveFail,
      'unknownSeverity': totalUnknownSeverity,
    },
    'rates': rates,
    'rateTrend': trend,
    'alerts': alerts,
    'severityByRun': runs
        .map(
          (run) => <String, dynamic>{
            'snapshotScope': run.snapshotScope,
            'schemaVersion': run.schemaVersion,
            'unknownSeverity': run.unknownSeverity,
            'caseCount': run.caseCount,
            'timestamp': run.timestamp.toIso8601String(),
            'source': run.source,
          },
        )
        .toList(growable: false),
  };
}

Map<String, dynamic> _computeRateTrend(List<_RunMetrics> runs) {
  if (runs.length < 2) {
    return <String, dynamic>{'sampleCount': runs.length};
  }

  final runRates = runs.map(_deriveRatesForRun).toList(growable: false);
  final passRates = <double>[];
  final phraseSuccessRates = <double>[];
  final semanticsRates = <double>[];
  final liveRegionRates = <double>[];

  for (final rates in runRates) {
    passRates.add(rates['passRate']!);
    phraseSuccessRates.add(rates['phraseSuccessRate']!);
    semanticsRates.add(rates['semanticsRate']!);
    liveRegionRates.add(rates['liveRegionRate']!);
  }

  return <String, dynamic>{
    'sampleCount': runs.length,
    'passRate': _buildRateTrendFromSamples(passRates),
    'phraseSuccessRate': _buildRateTrendFromSamples(phraseSuccessRates),
    'semanticsRate': _buildRateTrendFromSamples(semanticsRates),
    'liveRegionRate': _buildRateTrendFromSamples(liveRegionRates),
  };
}

Map<String, dynamic> _buildRateTrendFromSamples(List<double> values) {
  final first = values.first;
  final last = values.last;
  final delta = double.parse((last - first).toStringAsFixed(4));
  final maxConsecutiveDownRuns = _maxConsecutiveDownRuns(values);
  final maxDrop = double.parse(_maxRateDrop(values).toStringAsFixed(4));
  return <String, dynamic>{
    'first': first,
    'last': last,
    'delta': delta,
    'direction': delta == 0.0 ? 'flat' : (delta > 0 ? 'up' : 'down'),
    'maxConsecutiveDownRuns': maxConsecutiveDownRuns,
    'maxDrop': maxDrop,
  };
}

int _maxConsecutiveDownRuns(List<double> values) {
  if (values.length < 2) {
    return 0;
  }
  var longest = 0;
  var current = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] < values[i - 1]) {
      current += 1;
      if (current > longest) {
        longest = current;
      }
    } else {
      current = 0;
    }
  }
  return longest;
}

double _maxRateDrop(List<double> values) {
  if (values.length < 2) {
    return 0.0;
  }
  var maxDrop = 0.0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] >= values[i - 1]) {
      continue;
    }
    final drop = values[i - 1] - values[i];
    if (drop > maxDrop) {
      maxDrop = drop;
    }
  }
  return maxDrop;
}

List<Map<String, dynamic>> _readTrendHistory({
  required String? path,
  required int maxEntries,
}) {
  if (path == null || path.trim().isEmpty || maxEntries < 1) {
    return <Map<String, dynamic>>[];
  }

  final file = File(path);
  if (!file.existsSync()) {
    return <Map<String, dynamic>>[];
  }

  final lines = file.readAsLinesSync();
  final parsed = <Map<String, dynamic>>[];
  final start = lines.length > maxEntries ? lines.length - maxEntries : 0;
  for (var i = start; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      continue;
    }
    try {
      final payload = jsonDecode(line);
      if (payload is Map<String, dynamic>) {
        parsed.add(payload);
      }
    } catch (_) {}
  }
  return parsed;
}

List<Map<String, dynamic>> _applyTrendNoiseSuppression({
  required List<Map<String, dynamic>> alerts,
  required List<Map<String, dynamic>> priorHistory,
  required int noiseWindow,
}) {
  if (noiseWindow <= 1 || alerts.isEmpty) {
    return alerts
        .map((alert) => Map<String, dynamic>.from(alert))
        .toList(growable: false);
  }

  final ids = alerts
      .map((alert) => alert['id'])
      .where((id) => id is String && id.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList(growable: false);
  if (ids.isEmpty) {
    return alerts
        .map((alert) => Map<String, dynamic>.from(alert))
        .toList(growable: false);
  }

  final consecutiveCounts = <String, int>{for (final id in ids) id: 0};
  final broken = <String, bool>{for (final id in ids) id: false};

  for (var i = priorHistory.length - 1; i >= 0; i--) {
    final entryIds = _extractAlertIdsFromHistory(priorHistory[i]);
    for (final id in ids) {
      if (broken[id] == true) {
        continue;
      }
      if (entryIds.contains(id)) {
        consecutiveCounts[id] = (consecutiveCounts[id] ?? 0) + 1;
      } else {
        broken[id] = true;
      }
    }
  }

  final output = <Map<String, dynamic>>[];
  for (final alert in alerts) {
    final id = alert['id'];
    if (id is! String || id.isEmpty) {
      output.add(Map<String, dynamic>.from(alert));
      continue;
    }

    final observedRuns = consecutiveCounts[id] ?? 0;
    final suppressedRun = observedRuns + 1 < noiseWindow;
    final nextAlert = Map<String, dynamic>.from(alert);
    if (suppressedRun) {
      nextAlert['level'] = 'info';
      nextAlert['noiseSuppressed'] = true;
      nextAlert['noiseWindow'] = noiseWindow;
      nextAlert['observedConsecutiveRuns'] = observedRuns + 1;
      nextAlert['message'] =
          '${nextAlert['message']} [suppressed: window ${observedRuns + 1}/$noiseWindow]';
    }
    output.add(nextAlert);
  }

  return output;
}

Set<String> _extractAlertIdsFromHistory(Map<String, dynamic> entry) {
  final raw = entry['alerts'];
  if (raw is! List) {
    return <String>{};
  }

  final ids = <String>{};
  for (final rawAlert in raw) {
    if (rawAlert is Map && rawAlert['id'] is String) {
      final id = rawAlert['id'] as String;
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
  }
  return ids;
}

List<Map<String, dynamic>> _buildRecurrenceCandidates({
  required List<Map<String, dynamic>> priorHistory,
  required List<Map<String, dynamic>> currentAlerts,
  required int recurrenceWindow,
}) {
  if (recurrenceWindow < 1) {
    return <Map<String, dynamic>>[];
  }

  final ids = <String>{};
  for (final alert in currentAlerts) {
    if (!_isBlockingTrendAlert(alert, includeDerived: true)) {
      continue;
    }
    final id = alert['id'];
    if (id is String && id.isNotEmpty) {
      ids.add(id);
    }
  }
  if (ids.isEmpty) {
    return <Map<String, dynamic>>[];
  }

  final historyEntries = <Map<String, dynamic>>[
    ...priorHistory,
    <String, dynamic>{'alerts': currentAlerts},
  ];
  final candidates = <Map<String, dynamic>>[];

  for (final id in ids) {
    final recurrence = _buildRecurrenceStateFromHistory(
      entries: historyEntries,
      alertId: id,
      recurrenceWindow: recurrenceWindow,
    );
    candidates.add(<String, dynamic>{
      'id': id,
      'recurrenceWindow': recurrenceWindow,
      'recurrenceCount': recurrence['recurrenceCount']!,
      'maxAbsenceRuns': recurrence['maxAbsenceRuns']!,
      'episodeCount': recurrence['episodeCount']!,
      'longestEpisodeRuns': recurrence['longestEpisodeRuns']!,
      'lastEpisodeRuns': recurrence['lastEpisodeRuns']!,
      'consecutiveBlockingRuns': recurrence['consecutiveBlockingRuns']!,
    });
  }
  candidates.sort((a, b) {
    final aRuns = _toInt(a['consecutiveBlockingRuns'], 0);
    final bRuns = _toInt(b['consecutiveBlockingRuns'], 0);
    if (bRuns != aRuns) {
      return bRuns.compareTo(aRuns);
    }
    final aCount = _toInt(a['recurrenceCount'], 0);
    final bCount = _toInt(b['recurrenceCount'], 0);
    return bCount.compareTo(aCount);
  });

  return candidates;
}

Map<String, dynamic> _buildRecurrenceStateFromHistory({
  required List<Map<String, dynamic>> entries,
  required String alertId,
  required int recurrenceWindow,
}) {
  final activeRunIndexes = <int>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final alert = _findAlert(entry['alerts'], alertId);
    if (alert == null) {
      continue;
    }
    if (!_isBlockingTrendAlert(alert, includeDerived: true)) {
      continue;
    }
    activeRunIndexes.add(i);
  }

  if (activeRunIndexes.isEmpty) {
    return <String, dynamic>{
      'recurrenceCount': 0,
      'maxAbsenceRuns': 0,
      'episodeCount': 0,
      'longestEpisodeRuns': 0,
      'lastEpisodeRuns': 0,
      'consecutiveBlockingRuns': 0,
    };
  }

  var recurrenceCount = 0;
  var maxAbsenceRuns = 0;
  var episodeCount = 1;
  var currentEpisodeRuns = 1;
  var longestEpisodeRuns = 1;

  for (var i = 1; i < activeRunIndexes.length; i++) {
    final gapRuns = activeRunIndexes[i] - activeRunIndexes[i - 1] - 1;
    if (gapRuns == 0) {
      currentEpisodeRuns += 1;
      continue;
    }

    if (gapRuns > maxAbsenceRuns) {
      maxAbsenceRuns = gapRuns;
    }
    if (gapRuns >= recurrenceWindow) {
      recurrenceCount += 1;
    }

    if (currentEpisodeRuns > longestEpisodeRuns) {
      longestEpisodeRuns = currentEpisodeRuns;
    }
    episodeCount += 1;
    currentEpisodeRuns = 1;
  }

  if (currentEpisodeRuns > longestEpisodeRuns) {
    longestEpisodeRuns = currentEpisodeRuns;
  }

  return <String, dynamic>{
    'recurrenceCount': recurrenceCount,
    'maxAbsenceRuns': maxAbsenceRuns,
    'episodeCount': episodeCount,
    'longestEpisodeRuns': longestEpisodeRuns,
    'lastEpisodeRuns': currentEpisodeRuns,
    'consecutiveBlockingRuns': currentEpisodeRuns,
  };
}

Map<String, dynamic>? _findAlert(Object? rawAlerts, String alertId) {
  if (rawAlerts is! List) {
    return null;
  }
  for (final rawAlert in rawAlerts) {
    if (rawAlert is Map && rawAlert['id'] == alertId) {
      return Map<String, dynamic>.from(rawAlert);
    }
  }
  return null;
}

bool _isBlockingTrendAlert(Object? rawAlert, {required bool includeDerived}) {
  if (rawAlert is! Map) {
    return false;
  }
  final level = rawAlert['level'];
  if (level is! String) {
    return false;
  }
  if (level != 'warn' && level != 'error') {
    return false;
  }
  if (rawAlert['noiseSuppressed'] == true) {
    return false;
  }
  if (!includeDerived) {
    return true;
  }
  final isRecurrenceAlert = rawAlert['isRecurrenceAlert'];
  return isRecurrenceAlert != true;
}

List<Map<String, dynamic>> _buildRecurrenceThresholdAlerts({
  required List<Map<String, dynamic>> recurrenceCandidates,
  required int maxRecurrenceCount,
  required int maxAbsenceRuns,
}) {
  if (recurrenceCandidates.isEmpty) {
    return <Map<String, dynamic>>[];
  }

  final alerts = <Map<String, dynamic>>[];
  for (final candidate in recurrenceCandidates) {
    final id = candidate['id'];
    if (id is! String || id.isEmpty) {
      continue;
    }
    final recurrenceCount = _toInt(candidate['recurrenceCount'], 0);
    final observedAbsence = _toInt(candidate['maxAbsenceRuns'], 0);

    if (recurrenceCount > maxRecurrenceCount) {
      alerts.add(
        _buildAlert(
          '${id}RecurrenceCount',
          'warn',
          'recurrence count for $id is $recurrenceCount and exceeds allowed $maxRecurrenceCount '
              '(window=${candidate['recurrenceWindow']})',
          <String, dynamic>{
            'id': id,
            'recurrenceWindow': candidate['recurrenceWindow'],
            'recurrenceCount': recurrenceCount,
            'recurrenceCountThreshold': maxRecurrenceCount,
            'isRecurrenceAlert': true,
          },
        ),
      );
    }

    if (observedAbsence > maxAbsenceRuns) {
      alerts.add(
        _buildAlert(
          '${id}MaxAbsence',
          'warn',
          'max absence runs for $id is $observedAbsence and exceeds allowed $maxAbsenceRuns '
              '(window=${candidate['recurrenceWindow']})',
          <String, dynamic>{
            'id': id,
            'recurrenceWindow': candidate['recurrenceWindow'],
            'maxAbsenceRuns': observedAbsence,
            'maxAbsenceRunsThreshold': maxAbsenceRuns,
            'isRecurrenceAlert': true,
          },
        ),
      );
    }
  }

  return alerts;
}

void _appendTrendHistory({
  required String? path,
  required int maxEntries,
  required Map<String, dynamic> summary,
}) {
  if (path == null || path.trim().isEmpty || maxEntries < 1) {
    return;
  }

  final file = File(path);
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }

  final prior = _readTrendHistory(path: path, maxEntries: maxEntries);
  final payload = <String, dynamic>{
    'ts': DateTime.now().toUtc().toIso8601String(),
    'scope': summary['scope'],
    'windowMode': summary['windowMode'],
    'windowValue': summary['windowValue'],
    'consideredRunCount': summary['consideredRunCount'],
    'totalRunCountObserved': summary['totalRunCountObserved'],
    'rates': summary['rates'],
    'rateTrend': summary['rateTrend'],
    'alerts': summary['alerts'],
    'recurrenceWindow': summary['recurrenceWindow'],
    'recurrenceCandidates': summary['recurrenceCandidates'],
  };

  final keep = <Map<String, dynamic>>[...prior, payload];
  final maxKeep = maxEntries;
  final trimmed = keep.length <= maxKeep
      ? keep
      : keep.sublist(keep.length - maxKeep);
  final lines = trimmed
      .map((entry) => jsonEncode(entry))
      .toList(growable: false);
  file.writeAsStringSync('${lines.join('\n')}\n');
}

Map<String, double> _deriveRatesForRun(_RunMetrics run) {
  final passRate = run.caseCount == 0 ? 0.0 : run.casesPassed / run.caseCount;
  final phraseDenominator = run.phraseFound + run.phraseMissing;
  final phraseSuccessRate = phraseDenominator == 0
      ? 0.0
      : 1.0 - (run.phraseMissing / phraseDenominator);
  final semanticsDenominator = run.phraseFound + run.phraseMissing;
  final semanticsRate = semanticsDenominator == 0
      ? 0.0
      : run.phraseSemanticsPass / semanticsDenominator;
  final liveRegionRate = run.liveRegionChecked == 0
      ? 0.0
      : run.liveRegionPass / run.liveRegionChecked;
  return <String, double>{
    'passRate': double.parse(passRate.toStringAsFixed(4)),
    'phraseSuccessRate': double.parse(phraseSuccessRate.toStringAsFixed(4)),
    'semanticsRate': double.parse(semanticsRate.toStringAsFixed(4)),
    'liveRegionRate': double.parse(liveRegionRate.toStringAsFixed(4)),
  };
}

List<Map<String, dynamic>> _evaluateThresholdAlerts({
  required int schemaMismatchCount,
  required int unknownSeverity,
  required double passRate,
  required double phraseSuccessRate,
  required double semanticsRate,
  required double liveRegionRate,
}) {
  final alerts = <Map<String, dynamic>>[];
  final maxSchemaMismatch =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_MAX_SCHEMA_MISMATCH'] ?? '',
      ) ??
      _defaultMaxSchemaMismatch;
  final maxUnknownSeverity =
      int.tryParse(
        Platform.environment['DHC_A11Y_TREND_MAX_UNKNOWN_SEVERITY'] ?? '',
      ) ??
      _defaultMaxUnknownSeverity;
  final minPassRate =
      double.tryParse(
        Platform.environment['DHC_A11Y_TREND_MIN_PASS_RATE'] ?? '',
      ) ??
      _defaultMinPassRate;
  final minPhraseSuccessRate =
      double.tryParse(
        Platform.environment['DHC_A11Y_TREND_MIN_PHRASE_SUCCESS_RATE'] ?? '',
      ) ??
      _defaultMinPhraseSuccessRate;
  final minSemanticsRate =
      double.tryParse(
        Platform.environment['DHC_A11Y_TREND_MIN_SEMANTICS_RATE'] ?? '',
      ) ??
      _defaultMinSemanticsRate;
  final minLiveRegionRate =
      double.tryParse(
        Platform.environment['DHC_A11Y_TREND_MIN_LIVEREGION_RATE'] ?? '',
      ) ??
      _defaultMinLiveRegionRate;

  if (schemaMismatchCount > maxSchemaMismatch) {
    alerts.add(
      _buildAlert(
        'schemaMismatch',
        'error',
        'schema mismatch count $schemaMismatchCount > $maxSchemaMismatch',
        <String, dynamic>{
          'schemaMismatchCount': schemaMismatchCount,
          'threshold': maxSchemaMismatch,
        },
      ),
    );
  }

  if (unknownSeverity > maxUnknownSeverity) {
    alerts.add(
      _buildAlert(
        'unknownSeverity',
        'warn',
        'unknown severity count $unknownSeverity > $maxUnknownSeverity',
        <String, dynamic>{
          'unknownSeverity': unknownSeverity,
          'threshold': maxUnknownSeverity,
        },
      ),
    );
  }

  if (passRate < minPassRate) {
    alerts.add(
      _buildAlert(
        'passRate',
        'warn',
        'passRate ${passRate.toStringAsFixed(4)} < ${minPassRate.toStringAsFixed(2)}',
        <String, dynamic>{
          'passRate': double.parse(passRate.toStringAsFixed(4)),
          'threshold': minPassRate,
        },
      ),
    );
  }

  if (phraseSuccessRate < minPhraseSuccessRate) {
    alerts.add(
      _buildAlert(
        'phraseSuccessRate',
        'warn',
        'phraseSuccessRate ${phraseSuccessRate.toStringAsFixed(4)} < ${minPhraseSuccessRate.toStringAsFixed(2)}',
        <String, dynamic>{
          'phraseSuccessRate': double.parse(
            phraseSuccessRate.toStringAsFixed(4),
          ),
          'threshold': minPhraseSuccessRate,
        },
      ),
    );
  }

  if (semanticsRate < minSemanticsRate) {
    alerts.add(
      _buildAlert(
        'semanticsRate',
        'warn',
        'semanticsRate ${semanticsRate.toStringAsFixed(4)} < ${minSemanticsRate.toStringAsFixed(2)}',
        <String, dynamic>{
          'semanticsRate': double.parse(semanticsRate.toStringAsFixed(4)),
          'threshold': minSemanticsRate,
        },
      ),
    );
  }

  if (liveRegionRate < minLiveRegionRate) {
    alerts.add(
      _buildAlert(
        'liveRegionRate',
        'warn',
        'liveRegionRate ${liveRegionRate.toStringAsFixed(4)} < ${minLiveRegionRate.toStringAsFixed(2)}',
        <String, dynamic>{
          'liveRegionRate': double.parse(liveRegionRate.toStringAsFixed(4)),
          'threshold': minLiveRegionRate,
        },
      ),
    );
  }

  return alerts;
}

List<Map<String, dynamic>> _evaluateRateTrendAlerts({
  required Map<String, dynamic> rateTrend,
}) {
  final sampleCount = rateTrend['sampleCount'];
  if (sampleCount is! int || sampleCount < 2) {
    return <Map<String, dynamic>>[];
  }

  final passRateDrop = _parseDoubleEnv(
    'DHC_A11Y_TREND_MAX_PASS_RATE_DROP',
    _defaultMaxPassRateDrop,
  );
  final phraseSuccessRateDrop = _parseDoubleEnv(
    'DHC_A11Y_TREND_MAX_PHRASE_SUCCESS_RATE_DROP',
    _defaultMaxPhraseSuccessRateDrop,
  );
  final semanticsRateDrop = _parseDoubleEnv(
    'DHC_A11Y_TREND_MAX_SEMANTICS_RATE_DROP',
    _defaultMaxSemanticsRateDrop,
  );
  final liveRegionRateDrop = _parseDoubleEnv(
    'DHC_A11Y_TREND_MAX_LIVEREGION_RATE_DROP',
    _defaultMaxLiveRegionRateDrop,
  );
  final maxConsecutiveDownRuns = _parseIntEnv(
    'DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS',
    _defaultMaxConsecutiveDownRuns,
  );

  final alerts = <Map<String, dynamic>>[];
  _evaluateSingleRateTrend(
    alerts: alerts,
    metricName: 'passRate',
    metricLabel: 'passRate',
    maxDrop: passRateDrop,
    maxConsecutiveDownRuns: maxConsecutiveDownRuns,
    trend: (rateTrend['passRate'] is Map)
        ? Map<String, dynamic>.from(rateTrend['passRate'] as Map)
        : <String, dynamic>{},
  );
  _evaluateSingleRateTrend(
    alerts: alerts,
    metricName: 'phraseSuccessRate',
    metricLabel: 'phraseSuccessRate',
    maxDrop: phraseSuccessRateDrop,
    maxConsecutiveDownRuns: maxConsecutiveDownRuns,
    trend: (rateTrend['phraseSuccessRate'] is Map)
        ? Map<String, dynamic>.from(rateTrend['phraseSuccessRate'] as Map)
        : <String, dynamic>{},
  );
  _evaluateSingleRateTrend(
    alerts: alerts,
    metricName: 'semanticsRate',
    metricLabel: 'semanticsRate',
    maxDrop: semanticsRateDrop,
    maxConsecutiveDownRuns: maxConsecutiveDownRuns,
    trend: (rateTrend['semanticsRate'] is Map)
        ? Map<String, dynamic>.from(rateTrend['semanticsRate'] as Map)
        : <String, dynamic>{},
  );
  _evaluateSingleRateTrend(
    alerts: alerts,
    metricName: 'liveRegionRate',
    metricLabel: 'liveRegionRate',
    maxDrop: liveRegionRateDrop,
    maxConsecutiveDownRuns: maxConsecutiveDownRuns,
    trend: (rateTrend['liveRegionRate'] is Map)
        ? Map<String, dynamic>.from(rateTrend['liveRegionRate'] as Map)
        : <String, dynamic>{},
  );

  return alerts;
}

void _evaluateSingleRateTrend({
  required List<Map<String, dynamic>> alerts,
  required String metricName,
  required String metricLabel,
  required double maxDrop,
  required int maxConsecutiveDownRuns,
  required Map<String, dynamic> trend,
}) {
  final observedDirection = trend['direction'];
  final observedMaxDrop = _toDouble(trend['maxDrop'], 0.0);
  final observedConsecutiveDownRuns = _toInt(
    trend['maxConsecutiveDownRuns'],
    0,
  );

  if (observedMaxDrop > maxDrop) {
    alerts.add(
      _buildAlert(
        '${metricName}MaxDrop',
        'warn',
        'max single-step drop on $metricLabel is ${observedMaxDrop.toStringAsFixed(4)} '
            'and exceeds allowed ${maxDrop.toStringAsFixed(4)}',
        <String, dynamic>{
          'metric': metricLabel,
          'maxDrop': observedMaxDrop,
          'maxDropThreshold': maxDrop,
        },
      ),
    );
  }

  if (observedDirection == 'down' &&
      observedConsecutiveDownRuns > maxConsecutiveDownRuns) {
    alerts.add(
      _buildAlert(
        '${metricName}ConsecutiveDown',
        'warn',
        'consecutive downward transitions on $metricLabel '
            'is $observedConsecutiveDownRuns and exceeds allowed $maxConsecutiveDownRuns',
        <String, dynamic>{
          'metric': metricLabel,
          'maxConsecutiveDownRuns': observedConsecutiveDownRuns,
          'maxConsecutiveDownRunsAllowed': maxConsecutiveDownRuns,
        },
      ),
    );
  }
}

Map<String, dynamic> _buildAlert(
  String id,
  String level,
  String message,
  Map<String, dynamic> values,
) {
  return <String, dynamic>{
    'id': id,
    'level': level,
    'message': message,
    ...values,
  };
}

bool _shouldFailOnTrendAlerts(List<dynamic>? alerts) {
  return (Platform.environment['CI'] == 'true' ||
          Platform.environment['DHC_A11Y_TREND_FAIL_ON_ALERTS'] == 'true') &&
      _hasBlockingTrendAlert(alerts);
}

bool _hasBlockingTrendAlert(List<dynamic>? alerts) {
  if (alerts == null || alerts.isEmpty) {
    return false;
  }
  for (final alert in alerts) {
    if (alert is! Map) {
      return true;
    }
    final level = alert['level'];
    if (level is! String) {
      return true;
    }
    if (level == 'warn' || level == 'error') {
      return true;
    }
  }
  return false;
}

double _parseDoubleEnv(String key, double fallback) {
  return double.tryParse(Platform.environment[key] ?? '') ?? fallback;
}

int _parseIntEnv(String key, int fallback) {
  return int.tryParse(Platform.environment[key] ?? '') ?? fallback;
}

int _toInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double _toDouble(Object? value, double fallback) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

void _printHumanSummary(Map<String, dynamic> summary, _Options options) {
  final aggregate = summary['aggregate'] as Map<String, dynamic>;
  final rates = summary['rates'] as Map<String, dynamic>;
  final alerts = (summary['alerts'] as List<dynamic>? ?? <dynamic>[])
      .cast<Map<String, dynamic>>();
  final trendHistory = summary['trendHistory'] as Map<String, dynamic>?;
  final recurrenceCandidates =
      (summary['recurrenceCandidates'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
  final suppressedAlertCount = alerts
      .where((alert) => alert['noiseSuppressed'] == true)
      .length;
  final mismatch = summary['schemaMismatchCount'] as int;
  final windowMode = summary['windowMode'] as String;
  final recurrenceWindow = summary['recurrenceWindow'];
  final recurrenceThresholds =
      summary['recurrenceThresholds'] as Map<String, dynamic>?;

  stdout.writeln(
    'COMPARE_REPLAY_A11Y_TREND_SUMMARY mode=$windowMode '
    'value=${summary['windowValue']}',
  );
  stdout.writeln('scope=${summary['scope']}');
  if (windowMode == _windowDaysMode) {
    stdout.writeln('windowCutoff=${summary['windowCutoff']}');
  }
  if (summary['windowFallbackUsed'] == true) {
    stdout.writeln('windowFallbackUsed=1');
  }
  stdout.writeln(
    'consideredRunCount=${summary['consideredRunCount']} '
    'totalRunCountObserved=${summary['totalRunCountObserved']}',
  );
  stdout.writeln(
    'schemaMismatchCount=$mismatch '
    'expectedSchemaVersion=${summary['snapshotVersionExpected']}',
  );
  stdout.writeln(
    'cases=${aggregate['cases']} '
    'casesPassed=${aggregate['casesPassed']} '
    'casesFailed=${aggregate['casesFailed']}',
  );
  stdout.writeln(
    'phrasesFound=${aggregate['phraseFound']} '
    'phrasesMissing=${aggregate['phraseMissing']} '
    'semanticsPass=${aggregate['phraseSemanticsPass']} '
    'semanticsFail=${aggregate['phraseSemanticsFail']} '
    'unknownSeverity=${aggregate['unknownSeverity']}',
  );
  stdout.writeln(
    'liveRegionChecked=${aggregate['liveRegionChecked']} '
    'liveRegionPass=${aggregate['liveRegionPass']} '
    'liveRegionFail=${aggregate['liveRegionFail']}',
  );
  stdout.writeln(
    'passRate=${rates['passRate']} '
    'phraseSuccessRate=${rates['phraseSuccessRate']} '
    'semanticsRate=${rates['semanticsRate']} '
    'liveRegionRate=${rates['liveRegionRate']}',
  );
  if (trendHistory != null) {
    final historyFile = trendHistory['historyFile'];
    final historyFileText = historyFile == null
        ? 'unset'
        : historyFile.toString();
    stdout.writeln(
      'trendHistoryFile=$historyFileText '
      'historyKeep=${trendHistory['historyMaxEntries']} '
      'noiseWindow=${trendHistory['trendNoiseWindow']} '
      'priorHistory=${trendHistory['priorHistoryEntryCount']}',
    );
  }
  if (suppressedAlertCount > 0) {
    stdout.writeln('suppressedAlerts=$suppressedAlertCount');
  }
  if (recurrenceWindow != null) {
    stdout.writeln('recurrenceWindow=$recurrenceWindow');
  }
  if (recurrenceThresholds != null) {
    stdout.writeln('recurrenceThresholds=$recurrenceThresholds');
  }
  if (recurrenceCandidates.isNotEmpty) {
    stdout.writeln('recurrenceCandidates=${jsonEncode(recurrenceCandidates)}');
  }
  if (alerts.isNotEmpty) {
    stdout.writeln('alerts=${jsonEncode(alerts)}');
  }
  stdout.writeln('rateTrend=${jsonEncode(summary['rateTrend'])}');
  stdout.writeln(
    'COMPARE_REPLAY_A11Y_TREND_SUMMARY_JSON=${jsonEncode(summary)}',
  );
}

class _RunMetrics {
  _RunMetrics({
    required this.source,
    required this.timestamp,
    required this.snapshotScope,
    required this.schemaVersion,
    required this.caseCount,
    required this.casesPassed,
    required this.casesFailed,
    required this.phraseFound,
    required this.phraseMissing,
    required this.phraseSemanticsPass,
    required this.phraseSemanticsFail,
    required this.liveRegionChecked,
    required this.liveRegionPass,
    required this.liveRegionFail,
    required this.unknownSeverity,
    required this.alerts,
  });

  final String source;
  final DateTime timestamp;
  final String snapshotScope;
  final String schemaVersion;
  final int caseCount;
  final int casesPassed;
  final int casesFailed;
  final int phraseFound;
  final int phraseMissing;
  final int phraseSemanticsPass;
  final int phraseSemanticsFail;
  final int liveRegionChecked;
  final int liveRegionPass;
  final int liveRegionFail;
  final int unknownSeverity;
  final List<Map<String, dynamic>> alerts;

  static _RunMetrics? fromJson(
    Map<String, Object?> json, {
    required String source,
    required DateTime timestamp,
  }) {
    final snapshotScope = json['snapshotScope'];
    final schemaVersion = json['schemaVersion'];
    final caseCount = json['caseCount'];
    final casesPassed = json['casesPassed'];
    final casesFailed = json['casesFailed'];
    final phraseFound = json['phraseFoundCount'];
    final phraseMissing = json['phraseMissingCount'];
    final phraseSemanticsPass = json['phraseSemanticsPassCount'];
    final phraseSemanticsFail = json['phraseSemanticsFailCount'];
    final liveRegionChecked = json['liveRegionCheckedCount'];
    final liveRegionPass = json['liveRegionPassCount'];
    final liveRegionFail = json['liveRegionFailCount'];
    final severityBuckets = json['severityBuckets'];
    final alerts = json['alerts'];

    if (snapshotScope is! String ||
        schemaVersion is! String ||
        caseCount is! int ||
        casesPassed is! int ||
        casesFailed is! int ||
        phraseFound is! int ||
        phraseMissing is! int ||
        phraseSemanticsPass is! int ||
        phraseSemanticsFail is! int ||
        liveRegionChecked is! int ||
        liveRegionPass is! int ||
        liveRegionFail is! int ||
        severityBuckets is! Map) {
      return null;
    }

    final parsedAlerts = _parseRunAlerts(alerts);

    final unknownSeverity = _countUnknownSeverity(severityBuckets);
    return _RunMetrics(
      source: source,
      timestamp: timestamp,
      snapshotScope: snapshotScope,
      schemaVersion: schemaVersion,
      caseCount: caseCount,
      casesPassed: casesPassed,
      casesFailed: casesFailed,
      phraseFound: phraseFound,
      phraseMissing: phraseMissing,
      phraseSemanticsPass: phraseSemanticsPass,
      phraseSemanticsFail: phraseSemanticsFail,
      liveRegionChecked: liveRegionChecked,
      liveRegionPass: liveRegionPass,
      liveRegionFail: liveRegionFail,
      unknownSeverity: unknownSeverity,
      alerts: parsedAlerts,
    );
  }

  static List<Map<String, dynamic>> _parseRunAlerts(Object? alerts) {
    if (alerts is! List) {
      return <Map<String, dynamic>>[];
    }
    final parsed = <Map<String, dynamic>>[];
    for (final alert in alerts) {
      if (alert is Map<String, dynamic>) {
        parsed.add(Map<String, dynamic>.from(alert));
      } else if (alert is Map) {
        final sanitized = <String, dynamic>{};
        for (final entry in alert.entries) {
          final key = entry.key;
          if (key is String) {
            sanitized[key] = entry.value;
          }
        }
        parsed.add(sanitized);
      }
    }
    return parsed;
  }

  static int _countUnknownSeverity(Map<dynamic, dynamic> severityBuckets) {
    const allowed = <String>{
      'critical',
      'high',
      'medium',
      'low',
      'info',
      'warning',
      'missing',
      'invalid',
    };
    var total = 0;
    for (final entry in severityBuckets.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is int) {
        if (!allowed.contains(key)) {
          total += value;
        }
      }
    }
    return total;
  }
}

class _ParsedPayload {
  _ParsedPayload({required this.payload, required this.timestamp});

  final Map<String, Object?> payload;
  final DateTime? timestamp;
}

class _WindowSelection {
  _WindowSelection({
    required this.runs,
    required this.windowCutoff,
    required this.fallbackUsed,
  });

  final List<_RunMetrics> runs;
  final DateTime? windowCutoff;
  final bool fallbackUsed;
}

class _Options {
  _Options({
    required this.windowMode,
    required this.windowValue,
    required this.showHelp,
    required this.outputJsonOnly,
    required this.files,
    required this.historyFile,
    required this.historyMaxEntries,
    required this.trendNoiseWindow,
    required this.recurrenceWindow,
    required this.maxRecurrenceCount,
    required this.maxAbsenceRuns,
  });

  final String windowMode;
  final int windowValue;
  final bool showHelp;
  final bool outputJsonOnly;
  final List<String> files;
  final String? historyFile;
  final int historyMaxEntries;
  final int trendNoiseWindow;
  final int recurrenceWindow;
  final int maxRecurrenceCount;
  final int maxAbsenceRuns;
}
