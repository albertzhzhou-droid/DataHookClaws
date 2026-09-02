#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

const String _homePagePath = 'lib/src/features/home/home_page.dart';
const String _compareReplayA11ySnapshotPath =
    'docs/compare_replay_accessibility_snapshot_template.json';
const String _functionName = '_buildComparisonPanel';
const List<String> _compareReplayStatusPhrases = <String>[
  'Compare replay unavailable',
  'Compare replay still missing after',
  'Rebuild compare manually',
  'Please rebuild compare manually.',
  'Missing IDs:',
  'Retry missing items',
  'Compare replay draft urgent warning',
];

const String _exportStatusSemanticsHost = 'Export status message:';
const String _recentExportReplaySemanticsHost = 'Recent export replay:';
const int _defaultSemanticsSearchWindow = 24;
const int _defaultLiveRegionSearchWindow = 28;

void main() {
  final sourceFile = File(_homePagePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source file: $_homePagePath');
    exit(1);
  }

  final lines = sourceFile.readAsLinesSync();
  final functionStartLine = _findFunctionStartLine(lines, _functionName);
  if (functionStartLine == null) {
    stderr.writeln(
      'Unable to locate $_functionName definition in $_homePagePath',
    );
    exit(1);
  }

  final functionEndLine = _findFunctionEndLine(lines, functionStartLine);
  if (functionEndLine == null) {
    stderr.writeln(
      'Unable to resolve closing brace for $_functionName in $_homePagePath',
    );
    exit(1);
  }

  final sourceText = lines.join('\n');
  final functionText = lines
      .sublist(functionStartLine, functionEndLine + 1)
      .join('\n');
  final issues = <String>[];
  final templateSummary = _validateCompareReplayAccessibilitySnapshots(
    sourceText,
    lines,
    issues,
  );

  _require(
    functionText.contains('FocusTraversalGroup('),
    'compare panel should declare FocusTraversalGroup for keyboard order',
    issues,
  );
  _require(
    functionText.contains('FocusTraversalOrder('),
    'compare panel should use FocusTraversalOrder for ordered focus traversal',
    issues,
  );
  _require(
    functionText.contains('Focus('),
    'compare panel should keep interactive nodes focusable',
    issues,
  );

  _require(
    functionText.contains('onKeyEvent: (node, event)'),
    'selected compare food chips should bind key events',
    issues,
  );
  _require(
    functionText.contains('LogicalKeyboardKey.delete') ||
        functionText.contains('LogicalKeyboardKey.backspace'),
    'compare food removal key action should include Delete/Backspace',
    issues,
  );

  _require(
    functionText.contains("label: 'Selected foods for comparison'"),
    'selected foods area should expose accessibility container label',
    issues,
  );
  _require(
    functionText.contains('label: \'Nutrient row '),
    'nutrient rows should include semantic labels',
    issues,
  );
  _require(
    functionText.contains('label: label.statusSummary'),
    'nutrient cells should keep row status summaries as semantics labels',
    issues,
  );
  _require(
    functionText.contains('_removeCompareWithUndo('),
    'compare removal should route through undo-capable handler',
    issues,
  );
  _require(
    sourceText.contains('Draft mode active') ||
        sourceText.contains('Unavailable (manual rebuild required)'),
    'compare replay failure states should expose recovery/blocked state text',
    issues,
  );
  _require(
    sourceText.contains('Missing IDs: ') ||
        sourceText.contains('Retry missing items'),
    'compare replay failure recovery should expose missing-ID guidance',
    issues,
  );
  _require(
    _hasSemanticsForPhrase(sourceText, lines, 'Missing IDs:') &&
        _hasSemanticsForPhrase(sourceText, lines, 'Retry missing items'),
    'compare replay missing-ID and retry paths should be semantically labeled',
    issues,
  );
  _require(
    _hasSemanticsForPhrase(sourceText, lines, 'Draft remaining:') &&
        _hasSemanticsForPhrase(sourceText, lines, 'Clear draft now'),
    'compare replay draft remaining + clear controls should be semantically labeled',
    issues,
  );
  _require(
    _hasSemanticsForPhrase(
      sourceText,
      lines,
      'Compare replay draft urgent warning',
    ),
    'compare replay urgent warning path should be semantically labeled',
    issues,
  );
  _require(
    _hasSemanticsForPhrase(sourceText, lines, 'Rebuild compare manually'),
    'compare manual rebuild path should be semantically labeled',
    issues,
  );
  _require(
    sourceText.contains('Please rebuild compare manually.') ||
        sourceText.contains('Rebuild compare manually.'),
    'compare replay hard-failure path should expose manual rebuild guidance text',
    issues,
  );
  _require(
    _hasSemanticsAround(sourceText, lines, _recentExportReplaySemanticsHost),
    'compare replay recall chip should carry semantic wrapper for status context',
    issues,
  );
  _require(
    sourceText.contains("label: 'Clear draft compare recalls'") ||
        sourceText.contains("label: 'Clear unavailable compare recalls'") ||
        sourceText.contains("label: 'Clear all recent export recalls'"),
    'compare recall clear actions should expose explicit semantics labels',
    issues,
  );
  _require(
    sourceText.contains('SnackBarAction(') &&
        sourceText.contains("label: 'Undo'"),
    'compare undo flow should expose Undo action',
    issues,
  );
  _require(
    sourceText.contains('removed from compare'),
    'compare undo flow should emit user-facing undo recovery text',
    issues,
  );
  _require(
    _hasSemanticsWithLiveRegionForPhrase(
      sourceText,
      lines,
      'Compare replay draft urgent warning',
    ),
    'compare replay urgent warning should be exposed as a live-region semantics node',
    issues,
  );
  _require(
    _hasSemanticsAround(sourceText, lines, _exportStatusSemanticsHost),
    'last export status text should be surfaced in an accessibility semantic container',
    issues,
  );
  _require(
    sourceText.contains('Export status message:'),
    'export status live region should expose explicit accessibility label',
    issues,
  );
  for (final phrase in _compareReplayStatusPhrases) {
    final phraseHost = _semanticHostForPhrase(phrase);
    _require(
      sourceText.contains(phrase),
      'compare replay status phrase should exist in source: $phrase',
      issues,
    );
    _require(
      _hasSemanticsForPhrase(
        sourceText,
        lines,
        phrase,
        semanticHost: phraseHost,
      ),
      'compare replay phrase should be semantically surfaced: $phrase',
      issues,
    );
  }

  _printTemplateSummary(templateSummary);

  if (issues.isNotEmpty) {
    stderr.writeln('compare accessibility regression check failed:');
    for (final issue in issues) {
      stderr.writeln('- $issue');
    }
    exit(1);
  }
  stdout.writeln('compare accessibility regression check passed.');
}

void _printTemplateSummary(_TemplateValidationSummary summary) {
  const maxReportPayloadLength = 1048576;
  stdout.writeln('COMPARE_REPLAY_A11Y_TEMPLATE_REPORT_START');
  stdout.writeln(
    'compare replay accessibility template checks: '
    'schemaVersion=${summary.schemaVersion}, '
    'snapshotScope=${summary.snapshotScope}, '
    'cases=${summary.caseCount}, phrases=${summary.phraseCount}, '
    'casesPassed=${summary.casesPassedCount}, '
    'casesFailed=${summary.caseFailureCount}, '
    'phraseFound=${summary.phraseFoundCount}, '
    'phraseMissing=${summary.phraseMissingCount}, '
    'semanticPass=${summary.phraseSemanticsPassCount}, '
    'semanticFail=${summary.phraseSemanticsFailCount}, '
    'liveRegionChecked=${summary.liveRegionCheckedCount}, '
    'liveRegionPass=${summary.liveRegionPassCount}, '
    'liveRegionFail=${summary.liveRegionFailCount}.',
  );
  if (summary.severityBuckets.isNotEmpty) {
    final keys = summary.severityBuckets.keys.toList()..sort();
    final bucketStr = keys
        .map((key) => '$key=${summary.severityBuckets[key]}')
        .join(', ');
    stdout.writeln('COMPARE_REPLAY_A11Y_TEMPLATE_SEVERITY: $bucketStr');
  } else {
    stdout.writeln('COMPARE_REPLAY_A11Y_TEMPLATE_SEVERITY: missing');
  }

  final summaryPayload = <String, Object?>{
    'schemaVersion': summary.schemaVersion,
    'snapshotScope': summary.snapshotScope,
    'caseCount': summary.caseCount,
    'casesPassed': summary.casesPassedCount,
    'casesFailed': summary.caseFailureCount,
    'phraseCount': summary.phraseCount,
    'phraseFoundCount': summary.phraseFoundCount,
    'phraseMissingCount': summary.phraseMissingCount,
    'phraseSemanticsPassCount': summary.phraseSemanticsPassCount,
    'phraseSemanticsFailCount': summary.phraseSemanticsFailCount,
    'liveRegionCheckedCount': summary.liveRegionCheckedCount,
    'liveRegionPassCount': summary.liveRegionPassCount,
    'liveRegionFailCount': summary.liveRegionFailCount,
    'severityBuckets': summary.severityBuckets,
  };
  final encodedSummaryPayload = jsonEncode(summaryPayload);
  if (encodedSummaryPayload.length > maxReportPayloadLength) {
    stdout.writeln(
      'COMPARE_REPLAY_A11Y_TEMPLATE_SUMMARY_JSON_LENGTH_EXCEEDED: '
      '${encodedSummaryPayload.length}',
    );
  }
  stdout.writeln(
    'COMPARE_REPLAY_A11Y_TEMPLATE_SUMMARY_JSON='
    '$encodedSummaryPayload',
  );

  for (final caseReport in summary.caseReports) {
    stdout.writeln(caseReport);
  }
  for (final phraseReport in summary.phraseReports) {
    stdout.writeln(phraseReport);
  }
  stdout.writeln('COMPARE_REPLAY_A11Y_TEMPLATE_REPORT_END');
}

_TemplateValidationSummary _validateCompareReplayAccessibilitySnapshots(
  String sourceText,
  List<String> lines,
  List<String> issues,
) {
  final summary = _TemplateValidationSummary();
  final templateFile = File(_compareReplayA11ySnapshotPath);
  if (!templateFile.existsSync()) {
    issues.add(
      'compare replay accessibility snapshot template should exist at '
      '$_compareReplayA11ySnapshotPath',
    );
    summary.caseReports.add(
      'COMPARE_REPLAY_A11Y_TEMPLATE status=missing-template; '
      'path=$_compareReplayA11ySnapshotPath',
    );
    return summary;
  }

  final rawJson = templateFile.readAsStringSync();
  late final Map<String, Object?> decoded;
  try {
    final decodedJson = jsonDecode(rawJson);
    if (decodedJson is! Map<String, Object?>) {
      issues.add(
        'compare replay accessibility snapshot template must be a JSON object.',
      );
      summary.caseReports.add(
        'COMPARE_REPLAY_A11Y_TEMPLATE status=invalid-json-root',
      );
      return summary;
    }
    decoded = decodedJson;
  } on FormatException {
    issues.add(
      'compare replay accessibility snapshot template must be valid JSON.',
    );
    summary.caseReports.add('COMPARE_REPLAY_A11Y_TEMPLATE status=invalid-json');
    return summary;
  }

  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion is! String || schemaVersion.trim().isEmpty) {
    issues.add(
      'compare replay accessibility snapshot template schemaVersion is required.',
    );
    summary.caseReports.add(
      'COMPARE_REPLAY_A11Y_TEMPLATE status=invalid-schemaVersion',
    );
  } else {
    summary.schemaVersion = schemaVersion;
  }

  final snapshotScope = decoded['snapshotScope'];
  if (snapshotScope is! String || snapshotScope.trim().isEmpty) {
    issues.add(
      'compare replay accessibility snapshot template snapshotScope is required.',
    );
    summary.caseReports.add(
      'COMPARE_REPLAY_A11Y_TEMPLATE status=invalid-snapshotScope',
    );
  } else {
    summary.snapshotScope = snapshotScope;
  }

  final snapshots = decoded['compareReplayNoDraftAccessibilitySnapshots'];
  if (snapshots is! List || snapshots.isEmpty) {
    issues.add(
      'compare replay accessibility snapshot template must define '
      'compareReplayNoDraftAccessibilitySnapshots with at least one case.',
    );
    summary.caseReports.add(
      'COMPARE_REPLAY_A11Y_TEMPLATE status=invalid-cases; '
      'trigger=missing-or-empty',
    );
    return summary;
  }

  final templatePhrases = <String>{};
  var caseIndex = 0;
  for (final item in snapshots) {
    caseIndex += 1;
    if (item is! Map<String, Object?>) {
      summary.caseCount += 1;
      issues.add(
        'compare replay accessibility snapshot case must be an object.',
      );
      summary.caseReports.add(
        'COMPARE_REPLAY_A11Y_CASE status=failed '
        'caseIndex=$caseIndex '
        'name=unknown '
        'trigger=unknown '
        'reason=non-object-case',
      );
      continue;
    }

    summary.caseCount += 1;

    final caseName = item['name'];
    final caseTrigger = item['trigger'];
    final normalizedCaseName = caseName is String ? caseName.trim() : '';
    var caseHasFailure = false;

    if (caseName is! String || caseName.trim().isEmpty) {
      issues.add(
        'compare replay accessibility snapshot case missing non-empty name (case #$caseIndex).',
      );
      caseHasFailure = true;
      summary.caseReports.add(
        'COMPARE_REPLAY_A11Y_CASE status=failed '
        'caseIndex=$caseIndex '
        'name=unknown '
        'trigger=${caseTrigger ?? ""} '
        'reason=missing-name',
      );
      continue;
    }

    if (caseTrigger is! String || caseTrigger.trim().isEmpty) {
      issues.add(
        'compare replay accessibility snapshot case missing trigger text: $normalizedCaseName',
      );
      caseHasFailure = true;
    }

    final sourcePhrases = item['sourcePhrases'];
    if (sourcePhrases is! List) {
      issues.add(
        'compare replay accessibility snapshot case missing sourcePhrases list: '
        '$normalizedCaseName',
      );
      summary.caseReports.add(
        'COMPARE_REPLAY_A11Y_CASE status=failed '
        'caseIndex=$caseIndex '
        'name=$normalizedCaseName '
        'reason=missing-sourcePhrases',
      );
      continue;
    }

    var phraseCount = 0;
    var phraseMissing = 0;
    var semanticPass = 0;
    var semanticFail = 0;
    var liveRegionChecked = 0;
    var liveRegionPass = 0;

    if (sourcePhrases.isEmpty) {
      issues.add(
        'compare replay accessibility snapshot case has empty sourcePhrases: '
        '$normalizedCaseName',
      );
      summary.caseReports.add(
        'COMPARE_REPLAY_A11Y_CASE status=failed '
        'caseIndex=$caseIndex '
        'name=$normalizedCaseName '
        'trigger=${(caseTrigger ?? '').toString()} '
        'reason=empty-sourcePhrases',
      );
      continue;
    }

    for (final phrase in sourcePhrases) {
      String? text;
      String? severity;
      String? semanticRequirement;
      bool requiresLiveRegion = false;

      if (phrase is String) {
        text = phrase.trim();
      } else if (phrase is Map<String, Object?>) {
        final phraseText = phrase['text'];
        if (phraseText is String) {
          text = phraseText.trim();
        }
        final phraseSeverity = phrase['severity'];
        if (phraseSeverity is String && phraseSeverity.trim().isNotEmpty) {
          severity = phraseSeverity.trim().toLowerCase();
        }
        final phraseReq = phrase['semanticRequirement'];
        if (phraseReq is String) {
          semanticRequirement = phraseReq.trim();
        }
        final phraseRequiresLiveRegion = phrase['requiresLiveRegion'];
        if (!phrase.containsKey('requiresLiveRegion')) {
          issues.add(
            'compare replay accessibility snapshot phrase missing requiresLiveRegion in case: '
            '$normalizedCaseName',
          );
          caseHasFailure = true;
        } else if (phraseRequiresLiveRegion is bool) {
          requiresLiveRegion = phraseRequiresLiveRegion;
        } else {
          issues.add(
            'compare replay accessibility snapshot phrase requiresLiveRegion must be bool in case: '
            '$normalizedCaseName',
          );
          caseHasFailure = true;
        }

        if (severity == null || severity.trim().isEmpty) {
          issues.add(
            'compare replay accessibility snapshot phrase missing severity in case: '
            '$normalizedCaseName',
          );
          severity = 'missing';
          caseHasFailure = true;
        }
        if (severity == 'missing') {
          summary.severityBuckets['missing'] =
              (summary.severityBuckets['missing'] ?? 0) + 1;
        } else {
          const allowedSeverities = <String>{
            'critical',
            'high',
            'medium',
            'low',
            'info',
            'warning',
          };
          if (allowedSeverities.contains(severity)) {
            summary.severityBuckets[severity] =
                (summary.severityBuckets[severity] ?? 0) + 1;
          } else {
            issues.add(
              'compare replay accessibility snapshot phrase has unknown severity in case: '
              '$normalizedCaseName $text severity=$severity',
            );
            summary.severityBuckets['invalid'] =
                (summary.severityBuckets['invalid'] ?? 0) + 1;
            caseHasFailure = true;
          }
        }
      } else {
        issues.add(
          'compare replay accessibility snapshot phrase must be string or object in case: '
          '$normalizedCaseName',
        );
        caseHasFailure = true;
        continue;
      }

      if (text == null || text.isEmpty) {
        issues.add(
          'compare replay accessibility snapshot phrase missing text in case: '
          '$normalizedCaseName',
        );
        caseHasFailure = true;
        continue;
      }

      if (semanticRequirement == null || semanticRequirement.isEmpty) {
        issues.add(
          'compare replay accessibility snapshot phrase missing semanticRequirement in case: '
          '$normalizedCaseName',
        );
        caseHasFailure = true;
      }

      templatePhrases.add(text);
      summary.phraseCount += 1;
      phraseCount += 1;

      if (!sourceText.contains(text)) {
        phraseMissing += 1;
        summary.phraseMissingCount += 1;
        caseHasFailure = true;
        summary.phraseReports.add(
          'COMPARE_REPLAY_A11Y_PHRASE status=missing '
          'case=$normalizedCaseName '
          'text=$text '
          'severity=$severity '
          'requirement=$semanticRequirement',
        );
        continue;
      }

      summary.phraseFoundCount += 1;
      final phraseHost = _semanticHostForPhrase(text);
      if (_hasSemanticsForPhrase(
        sourceText,
        lines,
        text,
        semanticHost: phraseHost,
      )) {
        semanticPass += 1;
        summary.phraseSemanticsPassCount += 1;
      } else {
        semanticFail += 1;
        summary.phraseSemanticsFailCount += 1;
        caseHasFailure = true;
        summary.phraseReports.add(
          'COMPARE_REPLAY_A11Y_PHRASE status=missing-semantics '
          'case=$normalizedCaseName '
          'text=$text '
          'severity=$severity '
          'requirement=$semanticRequirement',
        );
      }

      if (requiresLiveRegion) {
        liveRegionChecked += 1;
        summary.liveRegionCheckedCount += 1;
        if (_hasSemanticsWithLiveRegionForPhrase(
          sourceText,
          lines,
          text,
          semanticHost: phraseHost,
        )) {
          liveRegionPass += 1;
          summary.liveRegionPassCount += 1;
        } else {
          summary.liveRegionFailCount += 1;
          caseHasFailure = true;
          summary.phraseReports.add(
            'COMPARE_REPLAY_A11Y_PHRASE status=missing-live-region '
            'case=$normalizedCaseName '
            'text=$text '
            'severity=$severity',
          );
        }
      }
    }

    final status = caseHasFailure ? 'failed' : 'passed';
    summary.caseReports.add(
      'COMPARE_REPLAY_A11Y_CASE status=$status '
      'case=$normalizedCaseName '
      'index=$caseIndex '
      'trigger=${(caseTrigger ?? '').toString()} '
      'phrases=$phraseCount '
      'semanticsPass=$semanticPass/$phraseCount '
      'semanticsFail=$semanticFail '
      'liveRegionPass=$liveRegionPass/$liveRegionChecked '
      'missing=$phraseMissing',
    );

    if (!caseHasFailure) {
      summary.casesPassedCount += 1;
    }
  }

  if (summary.caseCount >= summary.casesPassedCount) {
    summary.caseFailureCount = summary.caseCount - summary.casesPassedCount;
  } else {
    summary.caseFailureCount = 0;
  }

  if (summary.caseCount == 0) {
    issues.add(
      'compare replay accessibility snapshot template must include non-empty '
      'sourcePhrases for at least one case.',
    );
    summary.caseReports.add(
      'COMPARE_REPLAY_A11Y_TEMPLATE status=no-valid-case',
    );
  }

  if (templatePhrases.isEmpty) {
    summary.caseReports.add('COMPARE_REPLAY_A11Y_TEMPLATE status=no-phrases');
  }

  if (summary.phraseCount == 0) {
    issues.add(
      'compare replay accessibility snapshot template must include non-empty '
      'sourcePhrases for at least one case.',
    );
  }

  for (final trackedPhrase in templatePhrases) {
    if (trackedPhrase.length > 1048576) {
      issues.add(
        'compare replay accessibility snapshot phrase length overflow: '
        '${trackedPhrase.substring(0, 32)}... ',
      );
    }
  }
  return summary;
}

String _semanticHostForPhrase(String phrase) {
  switch (phrase) {
    case 'Compare replay unavailable':
    case 'Compare replay still missing after':
    case 'Please rebuild compare manually.':
    case 'Rebuild compare manually.':
    case 'Unavailable (manual rebuild required)':
      return _exportStatusSemanticsHost;
    case 'Rebuild compare manually':
      return phrase;
    case 'Retry missing items':
      return 'Retry missing compare items';
    case 'Missing IDs:':
      return 'Missing IDs for compare replay:';
    default:
      return phrase;
  }
}

class _TemplateValidationSummary {
  String schemaVersion = 'unknown';
  String snapshotScope = 'unknown';
  int caseCount = 0;
  int phraseCount = 0;
  int phraseFoundCount = 0;
  int phraseMissingCount = 0;
  int phraseSemanticsPassCount = 0;
  int phraseSemanticsFailCount = 0;
  int liveRegionCheckedCount = 0;
  int liveRegionPassCount = 0;
  int liveRegionFailCount = 0;
  int casesPassedCount = 0;
  int caseFailureCount = 0;
  final Map<String, int> severityBuckets = <String, int>{};
  final List<String> caseReports = <String>[];
  final List<String> phraseReports = <String>[];
}

int? _findFunctionStartLine(List<String> lines, String functionName) {
  final pattern = RegExp(
    r'^\s*Widget\s+' + RegExp.escape(functionName) + r'\s*\([^)]*\)\s*\{\s*$',
  );
  for (var index = 0; index < lines.length; index++) {
    if (pattern.hasMatch(lines[index])) {
      return index;
    }
  }
  return null;
}

int? _findFunctionEndLine(List<String> lines, int functionStartLine) {
  var openBraces = 0;
  var foundOpen = false;

  for (var index = functionStartLine; index < lines.length; index++) {
    final line = lines[index];
    for (var charIndex = 0; charIndex < line.length; charIndex++) {
      final char = line.codeUnitAt(charIndex);
      if (char == _openBrace) {
        openBraces++;
        foundOpen = true;
      } else if (char == _closeBrace) {
        openBraces--;
      }

      if (foundOpen && openBraces == 0) {
        return index;
      }
    }
  }
  return null;
}

void _require(bool condition, String message, List<String> issues) {
  if (!condition) {
    issues.add(message);
  }
}

bool _hasSemanticsForPhrase(
  String sourceText,
  List<String> lines,
  String phrase, {
  String? semanticHost,
}) {
  if (!sourceText.contains(phrase)) {
    return false;
  }

  final hosts = <String?>{semanticHost, phrase}.whereType<String>().toList();
  final anchors = hosts.where((value) => sourceText.contains(value)).toList();
  if (anchors.isEmpty) {
    return false;
  }

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (!anchors.any((anchor) => line.contains(anchor))) {
      continue;
    }
    final start = index - _defaultSemanticsSearchWindow >= 0
        ? index - _defaultSemanticsSearchWindow
        : 0;
    final end = index + _defaultSemanticsSearchWindow < lines.length
        ? index + _defaultSemanticsSearchWindow
        : lines.length - 1;
    for (var cursor = start; cursor <= end; cursor++) {
      if (lines[cursor].contains('Semantics(')) {
        return true;
      }
    }
  }
  return false;
}

bool _hasSemanticsWithLiveRegionForPhrase(
  String sourceText,
  List<String> lines,
  String phrase, {
  String? semanticHost,
}) {
  if (!sourceText.contains(phrase)) {
    return false;
  }

  final hosts = <String?>{semanticHost, phrase}.whereType<String>().toList();
  final anchors = hosts.where((value) => sourceText.contains(value)).toList();
  if (anchors.isEmpty) {
    return false;
  }

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (!anchors.any((anchor) => line.contains(anchor))) {
      continue;
    }
    final start = index - _defaultLiveRegionSearchWindow >= 0
        ? index - _defaultLiveRegionSearchWindow
        : 0;
    final end = index + _defaultLiveRegionSearchWindow < lines.length
        ? index + _defaultLiveRegionSearchWindow
        : lines.length - 1;
    for (var cursor = start; cursor <= end; cursor++) {
      if (!lines[cursor].contains('Semantics(')) {
        continue;
      }
      for (var look = cursor; look <= end; look++) {
        if (lines[look].contains('liveRegion: true')) {
          return true;
        }
      }
    }
  }
  return false;
}

bool _hasSemanticsAround(String sourceText, List<String> lines, String phrase) {
  if (!sourceText.contains(phrase)) {
    return false;
  }

  for (var index = 0; index < lines.length; index++) {
    if (!lines[index].contains(phrase)) {
      continue;
    }
    final start = index - _defaultSemanticsSearchWindow >= 0
        ? index - _defaultSemanticsSearchWindow
        : 0;
    final end = index + _defaultSemanticsSearchWindow < lines.length
        ? index + _defaultSemanticsSearchWindow
        : lines.length - 1;
    for (var cursor = start; cursor <= end; cursor++) {
      if (lines[cursor].contains('Semantics(')) {
        return true;
      }
    }
  }
  return false;
}

const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
