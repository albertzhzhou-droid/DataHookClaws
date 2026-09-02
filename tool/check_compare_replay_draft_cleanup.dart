import 'dart:io';

const String _homePagePath = 'lib/src/features/home/home_page.dart';
const String _clearMethodCall = '_clearCompareReplayDraftState(';
const String _resetMethodCall =
    '_resetUrgentCompareReplayDraftPromptScheduler(';

void main() {
  final sourceFile = File(_homePagePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source file: $_homePagePath');
    exit(1);
  }

  final lines = sourceFile.readAsLinesSync();
  final clearLineIndexes = <int>[];

  for (var index = 0; index < lines.length; index++) {
    if (lines[index].contains(_clearMethodCall)) {
      clearLineIndexes.add(index);
    }
  }

  final issues = <String>[];

  for (final clearLineIndex in clearLineIndexes) {
    final functionStartIndex = _findEnclosingFunctionStartLine(
      lines,
      clearLineIndex,
    );
    if (functionStartIndex == null) {
      issues.add(
        'Line ${clearLineIndex + 1}: unable to resolve enclosing function for clear call.',
      );
      continue;
    }

    final functionName = _extractFunctionName(lines[functionStartIndex]);
    if (functionName == '_clearCompareReplayDraftState') {
      continue;
    }

    final functionEndIndex = _findFunctionEndLine(lines, functionStartIndex);
    if (functionEndIndex == null) {
      issues.add(
        'Line ${clearLineIndex + 1}: function $functionName appears unbalanced (no closing brace).',
      );
      continue;
    }

    if (!_hasResetAfterClear(lines, clearLineIndex, functionEndIndex)) {
      issues.add(
        'Line ${clearLineIndex + 1}: in $functionName, no '
        '$_resetMethodCall call found after clear-state cleanup.',
      );
    }
  }

  if (issues.isNotEmpty) {
    stderr.writeln('compare replay draft cleanup consistency check failed:');
    for (final issue in issues) {
      stderr.writeln('- $issue');
    }
    exit(1);
  }

  stdout.writeln(
    'compare replay draft cleanup consistency check passed: all clear-state cleanup '
    'calls are paired with timer reset in function scope.',
  );
}

int? _findEnclosingFunctionStartLine(List<String> lines, int clearLineIndex) {
  for (var index = clearLineIndex; index >= 0; index--) {
    if (_isFunctionStartLine(lines[index])) {
      return index;
    }
  }
  return null;
}

String _extractFunctionName(String functionStartLine) {
  final match = _functionStartPattern.firstMatch(functionStartLine);
  if (match != null) {
    return match.group(1) ?? '<unknown>';
  }

  final fallbackMatch = _functionStartPatternWithOpenParen.firstMatch(
    functionStartLine,
  );
  return fallbackMatch?.group(1) ?? '<unknown>';
}

int? _findFunctionEndLine(List<String> lines, int functionStartIndex) {
  var openBraces = 0;
  var foundOpenBrace = false;
  var parenDepth = 0;

  for (var index = functionStartIndex; index < lines.length; index++) {
    final line = lines[index];
    for (var charIndex = 0; charIndex < line.length; charIndex++) {
      final char = line.codeUnitAt(charIndex);
      if (!foundOpenBrace) {
        if (char == _openParen) {
          parenDepth++;
        } else if (char == _closeParen) {
          parenDepth--;
        }

        if (char == _openBrace && parenDepth == 0) {
          openBraces = 1;
          foundOpenBrace = true;
        }
        continue;
      }

      if (char == _openBrace) {
        openBraces++;
        foundOpenBrace = true;
      } else if (char == _closeBrace) {
        openBraces--;
      }

      if (foundOpenBrace && openBraces == 0) {
        return index;
      }
    }
  }

  return null;
}

bool _hasResetAfterClear(
  List<String> lines,
  int clearLineIndex,
  int functionEndIndex,
) {
  for (var index = clearLineIndex; index <= functionEndIndex; index++) {
    if (lines[index].contains(_resetMethodCall)) {
      return true;
    }
  }
  return false;
}

bool _isFunctionStartLine(String line) {
  return _functionStartPattern.hasMatch(line) ||
      _functionStartPatternWithOpenParen.hasMatch(line);
}

const int _openBrace = 0x7B; // '{'
const int _closeBrace = 0x7D; // '}'
const int _openParen = 0x28; // '('
const int _closeParen = 0x29; // ')'

final RegExp _functionStartPattern = RegExp(
  r'^\s*(?:[A-Za-z@][@\w<>,\s\[\]\?\.]*\s+)+(_[A-Za-z_][A-Za-z0-9_]*)'
  r'\s*\([^)]*\)\s*(?:async\s*)?\{\s*$',
);
final RegExp _functionStartPatternWithOpenParen = RegExp(
  r'^\s*(?:[A-Za-z@][@\w<>,\s\[\]\?\.]*\s+)+(_[A-Za-z_][A-Za-z0-9_]*)'
  r'\s*\([^)]*$',
);
