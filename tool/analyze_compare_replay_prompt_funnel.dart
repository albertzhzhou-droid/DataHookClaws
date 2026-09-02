#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

const int _defaultMaxPayloadLength = 1048576;

void main(List<String> args) {
  if (args.isEmpty || args.any((arg) => arg == '--help' || arg == '-h')) {
    _printUsage();
    return;
  }

  var outputJsonOnly = false;
  var maxPayloadLength = _defaultMaxPayloadLength;
  final files = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--output-json') {
      outputJsonOnly = true;
    } else if (arg == '--max-payload-length' && i + 1 < args.length) {
      final parsed = int.tryParse(args[i + 1]);
      if (parsed != null && parsed > 0) {
        maxPayloadLength = parsed;
      }
      i += 1;
    } else if (arg.startsWith('--')) {
      stderr.writeln('Unsupported option: $arg');
      _printUsage();
      exit(2);
    } else {
      files.add(arg);
    }
  }

  if (files.isEmpty) {
    stderr.writeln('No source files provided.');
    _printUsage();
    exit(2);
  }

  final sessions = <String, Map<int, _PromptSessionFunnel>>{};
  var parsedEventCount = 0;
  var invalidEventCount = 0;

  for (final file in files) {
    final entries = _loadEntriesFromFile(file);
    for (final entry in entries) {
      final parsed = _parsePromptEvent(entry);
      if (parsed == null) {
        invalidEventCount += 1;
        continue;
      }
      parsedEventCount += 1;
      final scopeMap = sessions.putIfAbsent(parsed.scopeKey, () => {});
      final funnel = scopeMap.putIfAbsent(
        parsed.promptSessionIndex,
        () => _PromptSessionFunnel(scopeKey: parsed.scopeKey),
      );
      funnel.record(parsed);
    }
  }

  final scopeSummaries = <Map<String, Object?>>[];
  for (final scopeEntry in sessions.entries) {
    for (final sessionEntry in scopeEntry.value.entries) {
      scopeSummaries.add({
        'scopeKey': scopeEntry.key,
        'promptSessionIndex': sessionEntry.key,
        ...sessionEntry.value.buildSummary(),
      });
    }
  }

  final sessionCount = scopeSummaries.length;
  final actionDistribution = <String, int>{};
  final suppressReasonDistribution = <String, int>{};
  for (final scopeSummary in scopeSummaries) {
    final userActions = (scopeSummary['userActions'] as Map)
        .cast<String, int>();
    for (final entry in userActions.entries) {
      actionDistribution[entry.key] =
          (actionDistribution[entry.key] ?? 0) + entry.value;
    }

    final suppressReasons = (scopeSummary['suppressReasons'] as Map)
        .cast<String, int>();
    for (final entry in suppressReasons.entries) {
      suppressReasonDistribution[entry.key] =
          (suppressReasonDistribution[entry.key] ?? 0) + entry.value;
    }
  }

  final payload = <String, Object?>{
    'parsedEventCount': parsedEventCount,
    'invalidEventCount': invalidEventCount,
    'sessionCount': sessionCount,
    'sessionSummaries': scopeSummaries
      ..sort((a, b) {
        final scopeCompare = (a['scopeKey'] as String).compareTo(
          b['scopeKey'] as String,
        );
        if (scopeCompare != 0) {
          return scopeCompare;
        }
        return (a['promptSessionIndex'] as int).compareTo(
          b['promptSessionIndex'] as int,
        );
      }),
    'userActionTotals': actionDistribution,
    'suppressReasonTotals': suppressReasonDistribution,
  };

  final encoded = jsonEncode(payload);
  if (encoded.length > maxPayloadLength) {
    stderr.writeln(
      'COMPARE_REPLAY_PROMPT_FUNNEL_PAYLOAD_TOO_LARGE ${encoded.length}',
    );
    exit(1);
  }

  if (outputJsonOnly) {
    stdout.writeln('COMPARE_REPLAY_PROMPT_FUNNEL_JSON=$encoded');
    return;
  }

  stdout.writeln('COMPARE_REPLAY_PROMPT_FUNNEL_SUMMARY_JSON=$encoded');
  stdout.writeln('Parsed events: $parsedEventCount');
  stdout.writeln('Invalid events: $invalidEventCount');
  stdout.writeln('Sessions: $sessionCount');
  for (final scopeSummary in scopeSummaries) {
    final userActions = (scopeSummary['userActions'] as Map)
        .cast<String, int>();
    final deferredCount = _sumActionCounts(userActions, const [
      'remind_later',
      'dismissed_by_user',
      'dismissed_no_action',
    ]);
    final clearNowCount = userActions['clear_from_prompt'] ?? 0;
    stdout.writeln(
      'Session scope=${scopeSummary['scopeKey']} '
      'index=${scopeSummary['promptSessionIndex']} '
      'shown=${userActions['shown'] ?? 0} '
      'suppressed=${userActions['suppressed'] ?? 0} '
      'deferred=$deferredCount '
      'clearNow=$clearNowCount',
    );
  }
}

int _sumActionCounts(Map<String, int> actions, Iterable<String> keys) {
  var total = 0;
  for (final key in keys) {
    total += actions[key] ?? 0;
  }
  return total;
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/analyze_compare_replay_prompt_funnel.dart '
    '[options] <activity_trace_file> [more_files]',
  );
  stdout.writeln('Options:');
  stdout.writeln('  --help, -h               print this help');
  stdout.writeln(
    '  --output-json            print only machine-readable JSON line',
  );
  stdout.writeln(
    '  --max-payload-length     max allowed payload length for hard fail (default=$_defaultMaxPayloadLength)',
  );
}

List<Map<String, Object?>> _loadEntriesFromFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Input file missing: $path');
    exit(1);
  }
  final raw = file.readAsStringSync();

  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((entry) => _asStringMap(entry))
          .whereType<Map<String, Object?>>()
          .toList();
    }
    if (decoded is Map) {
      final maybeList = decoded['entries'];
      if (maybeList is List) {
        return maybeList
            .map((entry) => _asStringMap(entry))
            .whereType<Map<String, Object?>>()
            .toList();
      }
      final maybeActivityTrace = decoded['activityTrace'];
      if (maybeActivityTrace is List) {
        return maybeActivityTrace
            .map((entry) => _asStringMap(entry))
            .whereType<Map<String, Object?>>()
            .toList();
      }
    }
  } on FormatException {
    // fall back to line-wise JSON
  }

  final entries = <Map<String, Object?>>[];
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      final decodedLine = jsonDecode(trimmed);
      final parsedLine = _asStringMap(decodedLine);
      if (parsedLine != null) {
        entries.add(parsedLine);
      }
    } on FormatException {
      // ignore lines that are not JSON
    }
  }

  if (entries.isEmpty) {
    stderr.writeln('No parseable JSON entries found in $path');
    return const [];
  }

  return entries;
}

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is! Map) {
    return null;
  }

  final typed = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      continue;
    }
    typed[key] = entry.value;
  }

  return typed;
}

_ParsedPromptEvent? _parsePromptEvent(Map<String, Object?> entry) {
  if (entry['action'] != 'compare') {
    return null;
  }
  final details = entry['details'];
  if (details is! Map) {
    return null;
  }
  final rawScopeKey = details['scopeKey'];
  if (rawScopeKey is! String || rawScopeKey.isEmpty) {
    return null;
  }
  final rawUserAction = details['userAction'];
  if (rawUserAction is! String || rawUserAction.isEmpty) {
    return null;
  }
  final rawTrigger = details['trigger'];
  if (rawTrigger != 'urgent_prompt') {
    return null;
  }
  final scopeKey = rawScopeKey.toLowerCase();
  final promptSessionIndex = _toInt(details['promptSessionIndex']);
  if (promptSessionIndex == null) {
    return null;
  }
  final suppressReason = details['suppressReason'];
  return _ParsedPromptEvent(
    scopeKey: scopeKey,
    promptSessionIndex: promptSessionIndex,
    userAction: rawUserAction,
    suppressReason: suppressReason is String ? suppressReason : null,
  );
}

int? _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class _ParsedPromptEvent {
  _ParsedPromptEvent({
    required this.scopeKey,
    required this.promptSessionIndex,
    required this.userAction,
    this.suppressReason,
  });

  final String scopeKey;
  final int promptSessionIndex;
  final String userAction;
  final String? suppressReason;
}

class _PromptSessionFunnel {
  _PromptSessionFunnel({required this.scopeKey});

  final String scopeKey;
  final Map<String, int> _userActions = {};
  final Map<String, int> _suppressReasons = {};

  void record(_ParsedPromptEvent event) {
    _userActions[event.userAction] = (_userActions[event.userAction] ?? 0) + 1;
    if (event.suppressReason != null && event.suppressReason!.isNotEmpty) {
      _suppressReasons[event.suppressReason!] =
          (_suppressReasons[event.suppressReason!] ?? 0) + 1;
    }
  }

  Map<String, Object?> buildSummary() {
    return {
      'userActions': Map<String, int>.from(_userActions),
      'suppressReasons': Map<String, int>.from(_suppressReasons),
    };
  }
}
