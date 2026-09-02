#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

const String _summaryLinePrefix = 'COMPARE_REPLAY_A11Y_TEMPLATE_SUMMARY_JSON=';
const String _runTimestampKey = 'runTimestampUtc';
const String _startLineMarker = 'COMPARE_REPLAY_A11Y_TEMPLATE_REPORT_START';
const String _endLineMarker = 'COMPARE_REPLAY_A11Y_TEMPLATE_REPORT_END';
const String _expectedSchemaVersion = '1.0.1';
const int _maxSummaryPayloadLength = 1048576;
const Set<String> _expectedSeverityBuckets = <String>{
  'critical',
  'high',
  'medium',
  'low',
  'info',
  'warning',
  'missing',
  'invalid',
};
const String _parseUsage =
    'Usage: dart run tool/parse_compare_accessibility_report.dart [options] <check_log_file>\n'
    'Options:\n'
    '  --help               print this help\n'
    'If no file is provided, read report output from stdin.';

void main(List<String> args) {
  final normalizedArgs = List<String>.from(args);
  final wantsHelp = normalizedArgs.any((arg) => arg == '--help' || arg == '-h');
  if (wantsHelp) {
    stdout.writeln(_parseUsage);
    return;
  }
  final output = _readPayload(args);
  final lines = output.split(RegExp(r'\r?\n'));

  final rawSummaryLine = _extractSummaryLine(lines);
  if (rawSummaryLine == null) {
    _emitError('compare replay accessibility summary json line is missing.');
  }

  final parsed = _parseSummary(rawSummaryLine);
  if (parsed == null) {
    _emitError('compare replay accessibility summary json is not valid JSON.');
  }

  final int? cases = _extractInt(parsed, 'caseCount');
  final int? casesPassed = _extractInt(parsed, 'casesPassed');
  final int? phraseCount = _extractInt(parsed, 'phraseCount');
  final int? phraseMissing = _extractInt(parsed, 'phraseMissingCount');
  final int? phraseFound = _extractInt(parsed, 'phraseFoundCount');
  final int? phraseSemanticsPass = _extractInt(
    parsed,
    'phraseSemanticsPassCount',
  );
  final int? phraseSemanticsFail = _extractInt(
    parsed,
    'phraseSemanticsFailCount',
  );
  final int? liveRegionFail = _extractInt(parsed, 'liveRegionFailCount');
  final int? liveRegionChecked = _extractInt(parsed, 'liveRegionCheckedCount');
  final int? liveRegionPass = _extractInt(parsed, 'liveRegionPassCount');
  final int? casesFailed = _extractInt(parsed, 'casesFailed');
  final String schemaVersion = (parsed['schemaVersion'] is String)
      ? parsed['schemaVersion'] as String
      : 'unknown';
  final String snapshotScope = (parsed['snapshotScope'] is String)
      ? parsed['snapshotScope'] as String
      : 'unknown';

  if (cases == null ||
      casesPassed == null ||
      phraseCount == null ||
      phraseMissing == null ||
      phraseFound == null ||
      phraseSemanticsPass == null ||
      phraseSemanticsFail == null ||
      liveRegionFail == null ||
      liveRegionChecked == null ||
      liveRegionPass == null ||
      casesFailed == null) {
    _emitError(
      'compare replay accessibility summary payload is missing required numeric fields.',
    );
  }

  final severityBuckets = _extractMapInt(parsed, 'severityBuckets');
  if (severityBuckets == null) {
    _emitError(
      'compare replay accessibility summary payload is missing severityBuckets.',
    );
  }

  final String summaryPayload = jsonEncode(parsed);
  if (summaryPayload.length > _maxSummaryPayloadLength) {
    stderr.writeln(
      'COMPARE_REPLAY_A11Y_CI_REPORT_JSON_LENGTH_EXCEEDED '
      'actual=${summaryPayload.length} '
      'max=$_maxSummaryPayloadLength',
    );
    if (Platform.environment['CI'] == 'true' ||
        Platform.environment['DHC_A11Y_REPORT_STRICT'] == 'true') {
      exit(1);
    }
  }

  final reportLine = _buildReportLine(
    schemaVersion: schemaVersion,
    snapshotScope: snapshotScope,
    cases: cases,
    casesPassed: casesPassed,
    casesFailed: casesFailed,
    phraseCount: phraseCount,
    phraseMissing: phraseMissing,
    phraseFound: phraseFound,
    phraseSemanticsPass: phraseSemanticsPass,
    phraseSemanticsFail: phraseSemanticsFail,
    liveRegionFail: liveRegionFail,
    liveRegionChecked: liveRegionChecked,
    liveRegionPass: liveRegionPass,
    severityBuckets: severityBuckets,
  );
  stdout.writeln(reportLine);

  final reportEnvelope = <String, Object?>{
    _runTimestampKey: DateTime.now().toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'snapshotScope': snapshotScope,
    'caseCount': cases,
    'casesPassed': casesPassed,
    'casesFailed': casesFailed,
    'phraseCount': phraseCount,
    'phraseMissingCount': phraseMissing,
    'phraseFoundCount': phraseFound,
    'phraseSemanticsPassCount': phraseSemanticsPass,
    'phraseSemanticsFailCount': phraseSemanticsFail,
    'liveRegionCheckedCount': liveRegionChecked,
    'liveRegionPassCount': liveRegionPass,
    'liveRegionFailCount': liveRegionFail,
    'severityBuckets': severityBuckets,
  };
  stdout.writeln(
    'COMPARE_REPLAY_A11Y_PARSED_JSON='
    '${jsonEncode(reportEnvelope)}',
  );

  _validateFailureBudget(
    casesFailed,
    phraseMissing,
    phraseSemanticsFail,
    liveRegionFail,
    severityBuckets,
    schemaVersion,
  );

  _ensureReportBlockIntegrity(lines);
}

String _readPayload(List<String> args) {
  if (args.isNotEmpty) {
    final filePath = args[0];
    final reportFile = File(filePath);
    if (!reportFile.existsSync()) {
      _emitError(
        'compare replay accessibility check output file not found: $filePath',
      );
    }
    return reportFile.readAsStringSync();
  }

  final stdInPayload = StringBuffer();
  while (true) {
    final chunk = stdin.readLineSync();
    if (chunk == null) {
      break;
    }
    stdInPayload.writeln(chunk);
  }
  return stdInPayload.toString();
}

String? _extractSummaryLine(List<String> lines) {
  String? latestSummaryLine;
  for (final line in lines) {
    if (line.startsWith(_summaryLinePrefix)) {
      latestSummaryLine = line;
    }
  }
  return latestSummaryLine;
}

Map<String, Object?>? _parseSummary(String summaryLine) {
  final jsonPart = summaryLine.substring(_summaryLinePrefix.length);
  try {
    final decoded = jsonDecode(jsonPart);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return null;
  } on FormatException {
    return null;
  }
}

int? _extractInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is int) {
    return value;
  }
  return null;
}

Map<String, int>? _extractMapInt(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is Map) {
    final buckets = <String, int>{};
    for (final entry in value.entries) {
      final severity = entry.key;
      final count = entry.value;
      if (severity is String && count is int) {
        buckets[severity] = count;
      } else {
        return null;
      }
    }
    return buckets;
  }
  return null;
}

String _buildReportLine({
  required String schemaVersion,
  required String snapshotScope,
  required int cases,
  required int casesPassed,
  required int casesFailed,
  required int phraseCount,
  required int phraseMissing,
  required int phraseFound,
  required int phraseSemanticsPass,
  required int phraseSemanticsFail,
  required int liveRegionFail,
  required int liveRegionChecked,
  required int liveRegionPass,
  required Map<String, int> severityBuckets,
}) {
  final passRate = cases == 0 ? 0.0 : (casesPassed / cases);
  return 'COMPARE_REPLAY_A11Y_CI_METRICS '
      'schemaVersion=$schemaVersion '
      'snapshotScope=$snapshotScope '
      'caseCount=$cases '
      'casesPassed=$casesPassed '
      'casesFailed=$casesFailed '
      'phraseCount=$phraseCount '
      'phraseMissing=$phraseMissing '
      'phraseFound=$phraseFound '
      'phraseSemanticsPass=$phraseSemanticsPass '
      'phraseSemanticsFail=$phraseSemanticsFail '
      'liveRegionChecked=$liveRegionChecked '
      'liveRegionPass=$liveRegionPass '
      'liveRegionFail=$liveRegionFail '
      'passRate=${passRate.toStringAsFixed(4)} '
      'severityBuckets=${jsonEncode(severityBuckets)}';
}

void _validateFailureBudget(
  int casesFailed,
  int phraseMissing,
  int phraseSemanticsFail,
  int liveRegionFail,
  Map<String, int> severityBuckets,
  String schemaVersion,
) {
  final strictMode =
      (Platform.environment['CI'] == 'true' ||
      Platform.environment['DHC_A11Y_REPORT_STRICT'] == 'true');

  final maxCasesFailed =
      int.tryParse(Platform.environment['DHC_A11Y_MAX_CASES_FAILED'] ?? '') ??
      0;
  final maxPhraseMissing =
      int.tryParse(Platform.environment['DHC_A11Y_MAX_PHRASE_MISSING'] ?? '') ??
      0;
  final maxSemanticsFail =
      int.tryParse(Platform.environment['DHC_A11Y_MAX_SEMANTIC_FAIL'] ?? '') ??
      0;
  final maxLiveRegionFail =
      int.tryParse(
        Platform.environment['DHC_A11Y_MAX_LIVEREGION_FAIL'] ?? '',
      ) ??
      0;
  final maxUnknownSeverity =
      int.tryParse(
        Platform.environment['DHC_A11Y_MAX_UNKNOWN_SEVERITY_BUCKET'] ?? '',
      ) ??
      0;
  final failures = <String>[];
  if (casesFailed > maxCasesFailed) {
    failures.add('casesFailed($casesFailed) > maxCasesFailed($maxCasesFailed)');
  }
  if (phraseMissing > maxPhraseMissing) {
    failures.add(
      'phraseMissing($phraseMissing) > maxPhraseMissing($maxPhraseMissing)',
    );
  }
  if (phraseSemanticsFail > maxSemanticsFail) {
    failures.add(
      'phraseSemanticsFail($phraseSemanticsFail) > maxSemanticsFail($maxSemanticsFail)',
    );
  }
  if (liveRegionFail > maxLiveRegionFail) {
    failures.add(
      'liveRegionFail($liveRegionFail) > maxLiveRegionFail($maxLiveRegionFail)',
    );
  }
  var unknownSeverityCount = 0;
  for (final entry in severityBuckets.entries) {
    if (!_expectedSeverityBuckets.contains(entry.key)) {
      unknownSeverityCount += entry.value;
    }
  }
  if (unknownSeverityCount > maxUnknownSeverity) {
    failures.add(
      'unknownSeverityBuckets($unknownSeverityCount) > maxUnknownSeverityBuckets($maxUnknownSeverity)',
    );
  }
  if (schemaVersion != _expectedSchemaVersion) {
    failures.add(
      'schemaVersionMismatch($schemaVersion) != expectedSchemaVersion($_expectedSchemaVersion)',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln('COMPARE_REPLAY_A11Y_CI_REPORT_BUDGET_VIOLATION');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    if (strictMode) {
      exit(1);
    }
  }
}

void _ensureReportBlockIntegrity(List<String> lines) {
  var startIndex = -1;
  var endIndex = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] == _startLineMarker && startIndex < 0) {
      startIndex = i;
    } else if (lines[i] == _endLineMarker && endIndex < 0) {
      endIndex = i;
    }
  }

  if (startIndex < 0 || endIndex < 0) {
    stderr.writeln(
      'COMPARE_REPLAY_A11Y_CI_REPORT_INTEGRITY_WARNING: report start/end markers missing',
    );
    return;
  }
  if (startIndex > endIndex) {
    stderr.writeln(
      'COMPARE_REPLAY_A11Y_CI_REPORT_INTEGRITY_WARNING: report markers order invalid',
    );
  }
}

Never _emitError(String message) {
  stderr.writeln('COMPARE_REPLAY_A11Y_REPORT_PARSE_ERROR: $message');
  exit(1);
}
