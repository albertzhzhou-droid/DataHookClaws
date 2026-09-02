#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

const String _defaultScope = 'compare_replay_accessibility';
const int _defaultDailyLimit = 14;
const int _defaultWeeklyLimit = 8;
const int _defaultRegressionWindow = 2;
const int _defaultRecurrenceWindow = 2;
const String _envHistoryFile = 'DHC_A11Y_TREND_HISTORY_FILE';
const String _envRegressionWindow =
    'DHC_A11Y_TREND_DASHBOARD_REGRESSION_WINDOW';
const String _envDailyLimit = 'DHC_A11Y_TREND_DASHBOARD_DAILY_LIMIT';
const String _envWeeklyLimit = 'DHC_A11Y_TREND_DASHBOARD_WEEKLY_LIMIT';
const String _envRecurrenceWindow = 'DHC_A11Y_TREND_RECURRENCE_WINDOW';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }
  final options = _parseOptions(args);
  if (options.historyFile == null || options.historyFile!.trim().isEmpty) {
    _printUsage();
    exit(64);
  }

  final historyEntries = _loadHistory(path: options.historyFile!);
  if (historyEntries.isEmpty) {
    stderr.writeln(
      'No usable trend history records found: ${options.historyFile}',
    );
    exit(2);
  }

  final filtered = options.scope == null
      ? historyEntries
      : historyEntries
            .where((entry) => entry.scope == options.scope)
            .toList(growable: false);

  if (filtered.isEmpty) {
    stderr.writeln(
      'No history entries for scope=${options.scope} in ${options.historyFile}',
    );
    exit(2);
  }

  filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final daily = _aggregateByPeriod(
    filtered,
    windowKey: (ts) => _dateKey(ts),
  ).toList(growable: false);

  final weekly = _aggregateByPeriod(
    filtered,
    windowKey: (ts) => _weekKey(ts),
  ).toList(growable: false);

  final dailySummary = daily
      .where((entry) => _withinLimit(entry.indexFromEnd, options.dailyLimit))
      .toList(growable: false);
  final weeklySummary = weekly
      .where((entry) => _withinLimit(entry.indexFromEnd, options.weeklyLimit))
      .toList(growable: false);

  final alertSummary = _buildAlertSummary(filtered);
  final regressionCandidates = _buildRegressionCandidates(
    filtered,
    consecutiveThreshold: options.regressionWindow,
    recurrenceWindow: options.recurrenceWindow,
  );

  final dashboard = <String, dynamic>{
    'scope': options.scope ?? _defaultScope,
    'historyFile': options.historyFile,
    'scopeFilter': options.scope,
    'entryCount': filtered.length,
    'dailyLimit': options.dailyLimit,
    'weeklyLimit': options.weeklyLimit,
    'regressionWindow': options.regressionWindow,
    'daily': dailySummary.map((item) => item.toJson()).toList(growable: false),
    'weekly': weeklySummary
        .map((item) => item.toJson())
        .toList(growable: false),
    'global': {
      'totalUnknownSeverity': filtered.fold<int>(
        0,
        (sum, entry) => sum + entry.unknownSeverity,
      ),
      'totalSchemaMismatch': filtered.fold<int>(
        0,
        (sum, entry) => sum + entry.schemaMismatchCount,
      ),
      'averagePassRate': _formatDouble(
        filtered.fold<double>(0.0, (sum, entry) => sum + entry.passRate) /
            filtered.length,
      ),
      'averagePhraseSuccessRate': _formatDouble(
        filtered.fold<double>(
              0.0,
              (sum, entry) => sum + entry.phraseSuccessRate,
            ) /
            filtered.length,
      ),
      'averageSemanticsRate': _formatDouble(
        filtered.fold<double>(0.0, (sum, entry) => sum + entry.semanticsRate) /
            filtered.length,
      ),
      'averageLiveRegionRate': _formatDouble(
        filtered.fold<double>(0.0, (sum, entry) => sum + entry.liveRegionRate) /
            filtered.length,
      ),
    },
    'alertSummary': alertSummary,
    'stableAlertCandidates': regressionCandidates,
    'recurrenceWindow': options.recurrenceWindow,
    'dashboardMeta': {
      'source': 'trendHistory',
      'regressionWindowEnv': _envRegressionWindow,
      'dailyLimitEnv': _envDailyLimit,
      'weeklyLimitEnv': _envWeeklyLimit,
      'recurrenceWindowEnv': _envRecurrenceWindow,
    },
  };

  if (options.outputJsonOnly) {
    stdout.writeln(jsonEncode(dashboard));
    return;
  }

  final dailyJson = jsonEncode(
    dailySummary.map((item) => item.toJson()).toList(),
  );
  final weeklyJson = jsonEncode(
    weeklySummary.map((item) => item.toJson()).toList(),
  );
  final stableJson = jsonEncode(regressionCandidates);
  stdout.writeln(
    'COMPARE_REPLAY_A11Y_TREND_DASHBOARD_SUMMARY scope=${dashboard['scope']} '
    'historyFile=${options.historyFile} entryCount=${dashboard['entryCount']}',
  );
  stdout.writeln('COMPARE_REPLAY_A11Y_TREND_DASHBOARD_DAILY=$dailyJson');
  stdout.writeln('COMPARE_REPLAY_A11Y_TREND_DASHBOARD_WEEKLY=$weeklyJson');
  stdout.writeln(
    'COMPARE_REPLAY_A11Y_TREND_DASHBOARD_ALERTS=${jsonEncode(alertSummary)}',
  );
  if (regressionCandidates.isNotEmpty) {
    stdout.writeln(
      'COMPARE_REPLAY_A11Y_TREND_DASHBOARD_STABLE_ALERTS=$stableJson',
    );
  }
  stdout.writeln(
    'COMPARE_REPLAY_A11Y_TREND_DASHBOARD_SUMMARY_JSON=${jsonEncode(dashboard)}',
  );
}

DashboardOptions _parseOptions(List<String> args) {
  var historyFile = args.isNotEmpty && !args.first.startsWith('--')
      ? args.first
      : Platform.environment[_envHistoryFile];
  var dailyLimit = _defaultDailyLimit;
  var weeklyLimit = _defaultWeeklyLimit;
  var regressionWindow =
      int.tryParse(Platform.environment[_envRegressionWindow] ?? '') ??
      _defaultRegressionWindow;
  if (regressionWindow < 1) {
    regressionWindow = _defaultRegressionWindow;
  }
  var recurrenceWindow =
      int.tryParse(Platform.environment[_envRecurrenceWindow] ?? '') ??
      _defaultRecurrenceWindow;
  if (recurrenceWindow < 1) {
    recurrenceWindow = _defaultRecurrenceWindow;
  }
  final envDailyLimit = int.tryParse(
    Platform.environment[_envDailyLimit] ?? '',
  );
  final envWeeklyLimit = int.tryParse(
    Platform.environment[_envWeeklyLimit] ?? '',
  );
  if (envDailyLimit != null && envDailyLimit > 0) {
    dailyLimit = envDailyLimit;
  }
  if (envWeeklyLimit != null && envWeeklyLimit > 0) {
    weeklyLimit = envWeeklyLimit;
  }
  String? scope;
  var outputJsonOnly = false;

  var startIndex = args.isNotEmpty && !args.first.startsWith('--') ? 1 : 0;
  for (var i = startIndex; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--history-file' && i + 1 < args.length) {
      historyFile = args[i + 1];
      i += 1;
    } else if (arg == '--scope' && i + 1 < args.length) {
      scope = args[i + 1];
      i += 1;
    } else if (arg == '--daily-limit' && i + 1 < args.length) {
      final parsed = int.tryParse(args[i + 1]);
      if (parsed != null && parsed > 0) {
        dailyLimit = parsed;
      }
      i += 1;
    } else if (arg == '--weekly-limit' && i + 1 < args.length) {
      final parsed = int.tryParse(args[i + 1]);
      if (parsed != null && parsed > 0) {
        weeklyLimit = parsed;
      }
      i += 1;
    } else if (arg == '--regression-window' && i + 1 < args.length) {
      final parsed = int.tryParse(args[i + 1]);
      if (parsed != null && parsed > 0) {
        regressionWindow = parsed;
      }
      i += 1;
    } else if (arg == '--recurrence-window' && i + 1 < args.length) {
      final parsed = int.tryParse(args[i + 1]);
      if (parsed != null && parsed > 0) {
        recurrenceWindow = parsed;
      }
      i += 1;
    } else if (arg == '--output-json') {
      outputJsonOnly = true;
    } else if (arg == '--help' || arg == '-h') {
      return DashboardOptions(
        historyFile: null,
        scope: null,
        dailyLimit: _defaultDailyLimit,
        weeklyLimit: _defaultWeeklyLimit,
        regressionWindow: _defaultRegressionWindow,
        recurrenceWindow: _defaultRecurrenceWindow,
        outputJsonOnly: false,
      );
    }
  }

  if (historyFile == null || historyFile.trim().isEmpty) {
    // keep null, parser will print usage.
  }

  if (scope == null || scope.trim().isEmpty) {
    scope = null;
  }
  return DashboardOptions(
    historyFile: historyFile,
    scope: scope,
    dailyLimit: dailyLimit,
    weeklyLimit: weeklyLimit,
    regressionWindow: regressionWindow,
    recurrenceWindow: recurrenceWindow,
    outputJsonOnly: outputJsonOnly,
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/build_compare_accessibility_trend_digest.dart '
    '<history.jsonl>',
  );
  stdout.writeln('Options:');
  stdout.writeln(
    '  --history-file <path>           history jsonl from analyze script '
    '(defaults to $_envHistoryFile)',
  );
  stdout.writeln(
    '  --regression-window <n>         consecutive alert windows before marking '
    'stable (defaults to env $_envRegressionWindow or $_defaultRegressionWindow)',
  );
  stdout.writeln('  --scope <name>                  filter by scope');
  stdout.writeln(
    '  --recurrence-window <n>         absence-run window for recurrence detection '
    '(defaults to env $_envRecurrenceWindow or $_defaultRecurrenceWindow)',
  );
  stdout.writeln(
    '  --daily-limit <n>               keep last n day buckets (default 14 or $_envDailyLimit)',
  );
  stdout.writeln(
    '  --weekly-limit <n>              keep last n week buckets (default 8 or $_envWeeklyLimit)',
  );
  stdout.writeln('  --output-json                   emit single JSON only');
  stdout.writeln('  --help                          show this help');
}

List<_HistoryEntry> _loadHistory({required String path}) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Trend history file not found: $path');
    return <_HistoryEntry>[];
  }

  final lines = file.readAsLinesSync();
  final entries = <_HistoryEntry>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final entry = _HistoryEntry.fromJson(
          decoded,
          sourceFile: path,
          defaultScope: _defaultScope,
        );
        if (entry != null) {
          entries.add(entry);
        }
      }
    } catch (_) {}
  }
  return entries;
}

List<_SummaryBucket> _aggregateByPeriod(
  List<_HistoryEntry> entries, {
  required String Function(DateTime) windowKey,
}) {
  final byWindow = <String, _SummaryBucket>{};
  final windowOrder = <String>[];

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final key = windowKey(entry.timestamp);
    final existing = byWindow[key];
    if (existing == null) {
      byWindow[key] = _SummaryBucket(window: key);
      windowOrder.add(key);
    }
    byWindow[key]!.add(entry);
  }

  final ordered = <_SummaryBucket>[];
  windowOrder.sort((a, b) {
    final startA = DateTime.tryParse(a);
    final startB = DateTime.tryParse(b);
    if (startA == null || startB == null) {
      return a.compareTo(b);
    }
    return startA.compareTo(startB);
  });

  for (final key in windowOrder) {
    final bucket = byWindow[key]!;
    ordered.add(bucket);
  }
  for (var i = 0; i < ordered.length; i++) {
    ordered[i].indexFromEnd = ordered.length - i;
  }
  return ordered;
}

Map<String, dynamic> _buildAlertSummary(List<_HistoryEntry> entries) {
  final totalById = <String, int>{};
  final totalByLevel = <String, int>{};
  final suppressedById = <String, int>{};

  for (final entry in entries) {
    for (final alert in entry.alerts) {
      final id = alert['id'];
      final level = (alert['level'] ?? '').toString();
      final isSuppressed = alert['noiseSuppressed'] == true;
      if (id is String && id.isNotEmpty) {
        totalById[id] = (totalById[id] ?? 0) + 1;
        if (isSuppressed) {
          suppressedById[id] = (suppressedById[id] ?? 0) + 1;
        }
      }
      if (level.isNotEmpty) {
        totalByLevel[level] = (totalByLevel[level] ?? 0) + 1;
      }
    }
  }

  final topIds = totalById.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return <String, dynamic>{
    'total': totalByLevel.values.fold(0, (sum, value) => sum + value),
    'byLevel': totalByLevel,
    'topAlertIds': topIds
        .take(10)
        .map(
          (entry) => <String, dynamic>{
            'id': entry.key,
            'count': entry.value,
            'suppressedCount': suppressedById[entry.key] ?? 0,
          },
        )
        .toList(growable: false),
  };
}

List<Map<String, dynamic>> _buildRegressionCandidates(
  List<_HistoryEntry> entries, {
  required int consecutiveThreshold,
  required int recurrenceWindow,
}) {
  if (consecutiveThreshold <= 1) {
    return <Map<String, dynamic>>[];
  }

  final candidates = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final entry in entries) {
    for (final alert in entry.alerts) {
      final id = alert['id'];
      if (id is String && id.isNotEmpty) {
        ids.add(id);
      }
    }
  }

  for (final id in ids) {
    var consecutive = 0;
    for (var i = entries.length - 1; i >= 0; i--) {
      final alert = _findAlert(entries[i].alerts, id);
      if (alert == null) {
        break;
      }
      final level = (alert['level'] ?? '').toString();
      if ((level != 'warn' && level != 'error') ||
          alert['noiseSuppressed'] == true) {
        break;
      }
      consecutive += 1;
    }

    if (consecutive >= consecutiveThreshold) {
      final recurrence = _buildRecurrenceState(
        entries: entries,
        alertId: id,
        recurrenceWindow: recurrenceWindow,
      );
      candidates.add(<String, dynamic>{
        'id': id,
        'consecutiveBlockingRuns': consecutive,
        'requiredConsecutiveRuns': consecutiveThreshold,
        'recurrenceWindow': recurrenceWindow,
        'recurrenceCount': recurrence['recurrenceCount'],
        'maxAbsenceRuns': recurrence['maxAbsenceRuns'],
        'episodeCount': recurrence['episodeCount'],
        'longestEpisodeRuns': recurrence['longestEpisodeRuns'],
        'lastEpisodeRuns': recurrence['lastEpisodeRuns'],
      });
    }
  }

  candidates.sort((a, b) {
    final aRun = (a['consecutiveBlockingRuns'] as int?) ?? 0;
    final bRun = (b['consecutiveBlockingRuns'] as int?) ?? 0;
    return bRun.compareTo(aRun);
  });

  return candidates;
}

Map<String, int> _buildRecurrenceState({
  required List<_HistoryEntry> entries,
  required String alertId,
  required int recurrenceWindow,
}) {
  final activeRunIndexes = <int>[];
  for (var i = 0; i < entries.length; i++) {
    final alert = _findAlert(entries[i].alerts, alertId);
    if (alert == null) {
      continue;
    }
    final level = (alert['level'] ?? '').toString();
    final suppressed = alert['noiseSuppressed'] == true;
    if ((level != 'warn' && level != 'error') || suppressed) {
      continue;
    }
    activeRunIndexes.add(i);
  }

  if (activeRunIndexes.isEmpty) {
    return <String, int>{
      'recurrenceCount': 0,
      'maxAbsenceRuns': 0,
      'episodeCount': 0,
      'longestEpisodeRuns': 0,
      'lastEpisodeRuns': 0,
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

  return <String, int>{
    'recurrenceCount': recurrenceCount,
    'maxAbsenceRuns': maxAbsenceRuns,
    'episodeCount': episodeCount,
    'longestEpisodeRuns': longestEpisodeRuns,
    'lastEpisodeRuns': currentEpisodeRuns,
  };
}

Map<String, dynamic>? _findAlert(List<Map<String, dynamic>> alerts, String id) {
  for (final alert in alerts) {
    final alertId = alert['id'];
    if (alertId is String && alertId == id) {
      return alert;
    }
  }
  return null;
}

bool _withinLimit(int indexFromEnd, int limit) {
  if (indexFromEnd <= limit) {
    return true;
  }
  return false;
}

String _dateKey(DateTime ts) {
  return '${ts.year.toString().padLeft(4, '0')}-'
      '${ts.month.toString().padLeft(2, '0')}-'
      '${ts.day.toString().padLeft(2, '0')}';
}

String _weekKey(DateTime ts) {
  final date = DateTime(ts.year, ts.month, ts.day);
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return _dateKey(monday);
}

double _parseDouble(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

int _parseInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _formatDouble(double value) {
  return value.toStringAsFixed(4);
}

class _HistoryEntry {
  _HistoryEntry({
    required this.timestamp,
    required this.scope,
    required this.passRate,
    required this.phraseSuccessRate,
    required this.semanticsRate,
    required this.liveRegionRate,
    required this.schemaMismatchCount,
    required this.unknownSeverity,
    required this.alerts,
  });

  final DateTime timestamp;
  final String scope;
  final double passRate;
  final double phraseSuccessRate;
  final double semanticsRate;
  final double liveRegionRate;
  final int schemaMismatchCount;
  final int unknownSeverity;
  final List<Map<String, dynamic>> alerts;

  static _HistoryEntry? fromJson(
    Map<dynamic, dynamic> payload, {
    required String sourceFile,
    required String defaultScope,
  }) {
    final rawTs = payload['ts'];
    final scope = (payload['scope'] as String?) ?? defaultScope;
    final rates = payload['rates'] is Map ? payload['rates'] as Map : null;
    final aggregate = payload['aggregate'];
    final unknownFromAggregate = aggregate is Map<dynamic, dynamic>
        ? _parseInt(aggregate['unknownSeverity'], 0)
        : 0;
    if (rawTs == null || rates == null) {
      stderr.writeln(
        'Skipping malformed history entry in $sourceFile: missing ts/rates fields',
      );
      return null;
    }

    final parsedTs = DateTime.tryParse(rawTs.toString());
    if (parsedTs == null) {
      return null;
    }

    return _HistoryEntry(
      timestamp: parsedTs.toUtc(),
      scope: scope,
      passRate: _parseDouble(rates['passRate'], 0.0),
      phraseSuccessRate: _parseDouble(rates['phraseSuccessRate'], 0.0),
      semanticsRate: _parseDouble(rates['semanticsRate'], 0.0),
      liveRegionRate: _parseDouble(rates['liveRegionRate'], 0.0),
      schemaMismatchCount: _parseInt(payload['schemaMismatchCount'], 0),
      unknownSeverity: _parseInt(
        payload['unknownSeverity'],
        unknownFromAggregate,
      ),
      alerts: _parseAlertList(payload['alerts']),
    );
  }

  static List<Map<String, dynamic>> _parseAlertList(Object? raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    final alerts = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final map = <String, dynamic>{};
        for (final entry in item.entries) {
          map[entry.key.toString()] = entry.value;
        }
        alerts.add(map);
      }
    }
    return alerts;
  }
}

class _SummaryBucket {
  _SummaryBucket({required this.window});

  final String window;
  int sampleCount = 0;
  double passRateSum = 0.0;
  double phraseSuccessRateSum = 0.0;
  double semanticsRateSum = 0.0;
  double liveRegionRateSum = 0.0;
  int unknownSeveritySum = 0;
  int schemaMismatchSum = 0;
  int indexFromEnd = 0;

  void add(_HistoryEntry entry) {
    sampleCount += 1;
    passRateSum += entry.passRate;
    phraseSuccessRateSum += entry.phraseSuccessRate;
    semanticsRateSum += entry.semanticsRate;
    liveRegionRateSum += entry.liveRegionRate;
    unknownSeveritySum += entry.unknownSeverity;
    schemaMismatchSum += entry.schemaMismatchCount;
  }

  Map<String, dynamic> toJson() {
    if (sampleCount == 0) {
      return <String, dynamic>{'window': window, 'samples': 0};
    }
    return <String, dynamic>{
      'window': window,
      'samples': sampleCount,
      'passRateAvg': _formatDouble(passRateSum / sampleCount),
      'phraseSuccessRateAvg': _formatDouble(phraseSuccessRateSum / sampleCount),
      'semanticsRateAvg': _formatDouble(semanticsRateSum / sampleCount),
      'liveRegionRateAvg': _formatDouble(liveRegionRateSum / sampleCount),
      'unknownSeveritySum': unknownSeveritySum,
      'schemaMismatchSum': schemaMismatchSum,
    };
  }
}

class DashboardOptions {
  DashboardOptions({
    required this.historyFile,
    required this.scope,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.regressionWindow,
    required this.recurrenceWindow,
    required this.outputJsonOnly,
  });

  final String? historyFile;
  final String? scope;
  final int dailyLimit;
  final int weeklyLimit;
  final int regressionWindow;
  final int recurrenceWindow;
  final bool outputJsonOnly;
}
