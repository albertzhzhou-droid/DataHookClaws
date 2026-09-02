import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dartBinary =
      Platform.environment['DHC_DART_BIN'] ??
      Platform.environment['DART_BIN'] ??
      'dart';
  final dartEnv = Map<String, String>.from(Platform.environment)
    ..putIfAbsent('HOME', () => '/tmp/dhc_dart_checks_home')
    ..['DART_SUPPRESS_ANALYTICS'] = 'true';

  ProcessResult runDartTool(List<String> args) {
    final scriptPath = args.isNotEmpty && args.first.endsWith('.dart')
        ? args.first
        : null;
    final dartArgs = args.toList(growable: false);
    ProcessResult runResult;
    try {
      runResult = Process.runSync(dartBinary, dartArgs, environment: dartEnv);
    } on ProcessException catch (error) {
      return ProcessResult(0, 1, '', 'Failed to execute dart tool: $error');
    }

    final stderr = runResult.stderr.toString();
    if (scriptPath == null ||
        runResult.exitCode == 0 ||
        (!stderr.contains('Running build hooks failed') &&
            !stderr.contains('Failed to set file modification time') &&
            !stderr.contains('Failed host lookup'))) {
      return runResult;
    }

    final tempDir = Directory.systemTemp.createTempSync('dhc-dart-tool-aot-');
    try {
      final fallbackBinary =
          '${tempDir.path}/${scriptPath.split('/').last}-test-aot';
      final compileResult = Process.runSync(dartBinary, [
        'compile',
        'exe',
        scriptPath,
        '-o',
        fallbackBinary,
      ], environment: dartEnv);
      if (compileResult.exitCode != 0) {
        return ProcessResult(
          0,
          compileResult.exitCode,
          compileResult.stdout,
          '${compileResult.stderr}\nOriginal failure: $stderr',
        );
      }
      return Process.runSync(
        fallbackBinary,
        args.sublist(1),
        environment: dartEnv,
      );
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  test('prompt funnel script advertises help', () {
    final helpResult = runDartTool([
      'tool/analyze_compare_replay_prompt_funnel.dart',
      '--help',
    ]);
    expect(
      helpResult.exitCode,
      equals(0),
      reason: helpResult.stderr.toString(),
    );
    expect(helpResult.stdout.toString(), contains('Usage:'));
    expect(helpResult.stdout.toString(), contains('--output-json'));
  });

  test('prompt funnel script parses activity trace events', () {
    final tmpDir = Directory.systemTemp.createTempSync('dhc-prompt-funnel-');
    try {
      final input = File('${tmpDir.path}/activity_trace.json')
        ..writeAsStringSync(
          jsonEncode([
            {
              'action': 'compare',
              'summary': 'Showed compare replay draft expiry prompt',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'shown',
                'promptSessionIndex': 1,
              },
            },
            {
              'action': 'compare',
              'summary': 'Suppressed compare replay draft expiry prompt',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'suppressed',
                'suppressReason': 'cooldown_active',
                'promptSessionIndex': 1,
              },
            },
            {
              'action': 'compare',
              'summary': 'Deferred compare replay draft expiry prompt',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'remind_later',
                'promptSessionIndex': 1,
              },
            },
            {
              'action': 'compare',
              'summary': 'Dismissed compare replay draft expiry prompt',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'dismissed_by_user',
                'promptSessionIndex': 1,
              },
            },
            {
              'action': 'compare',
              'summary': 'Dismissed compare replay draft expiry prompt',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'dismissed_no_action',
                'promptSessionIndex': 1,
              },
            },
            {
              'action': 'compare',
              'summary': 'Cleared compare replay draft from prompt',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'clear_from_prompt',
                'promptSessionIndex': 1,
              },
            },
            {
              'action': 'compare',
              'summary': 'Ignored event from non-urgent prompt',
              'details': {
                'scopeKey': 'scope:beta',
                'trigger': 'manual',
                'userAction': 'manual_clear',
                'promptSessionIndex': 1,
              },
            },
          ]),
        );

      final result = runDartTool([
        'tool/analyze_compare_replay_prompt_funnel.dart',
        '--output-json',
        input.path,
      ]);
      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      final line = result.stdout.toString();
      expect(line, contains('COMPARE_REPLAY_PROMPT_FUNNEL_JSON='));
      final jsonLine = line
          .trim()
          .split('\n')
          .firstWhere(
            (value) => value.contains('COMPARE_REPLAY_PROMPT_FUNNEL_JSON='),
          );
      final payload =
          jsonDecode(
                jsonLine.substring('COMPARE_REPLAY_PROMPT_FUNNEL_JSON='.length),
              )
              as Map<String, Object?>;

      expect(payload['parsedEventCount'], equals(6));
      expect(payload['sessionCount'], equals(1));
      expect(
        (payload['userActionTotals'] as Map<String, Object?>)['shown'],
        equals(1),
      );
      expect(
        (payload['suppressReasonTotals']
            as Map<String, Object?>)['cooldown_active'],
        equals(1),
      );
      final sessions = payload['sessionSummaries'] as List<Object?>;
      expect(sessions.length, equals(1));
      final session = sessions.first as Map<String, Object?>;
      final userActions = session['userActions'] as Map<String, Object?>;
      expect(userActions['shown'], equals(1));
      expect(userActions['suppressed'], equals(1));
      expect(userActions['remind_later'], equals(1));
      expect(userActions['dismissed_by_user'], equals(1));
      expect(userActions['dismissed_no_action'], equals(1));
      expect(userActions['clear_from_prompt'], equals(1));

      final humanResult = runDartTool([
        'tool/analyze_compare_replay_prompt_funnel.dart',
        input.path,
      ]);
      expect(
        humanResult.exitCode,
        equals(0),
        reason: humanResult.stderr.toString(),
      );
      expect(
        humanResult.stdout.toString(),
        contains(
          'Session scope=scope:alpha index=1 shown=1 suppressed=1 deferred=3 clearNow=1',
        ),
      );
      expect(humanResult.stdout.toString(), isNot(contains('deferred=0')));
      expect(humanResult.stdout.toString(), isNot(contains('clearNow=0')));
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('prompt funnel script rejects missing source file', () {
    final result = runDartTool([
      'tool/analyze_compare_replay_prompt_funnel.dart',
      '--output-json',
      '/tmp/does-not-exist.json',
    ]);
    expect(result.exitCode, equals(1), reason: result.stderr.toString());
    expect(result.stderr.toString(), contains('Input file missing'));
  });

  test('prompt funnel script enforces payload limit', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-prompt-funnel-size-',
    );
    try {
      final input = File('${tmpDir.path}/activity_trace.json')
        ..writeAsStringSync(
          jsonEncode([
            {
              'action': 'compare',
              'summary': 'urgent prompt shown',
              'details': {
                'scopeKey': 'scope:alpha',
                'trigger': 'urgent_prompt',
                'userAction': 'shown',
                'promptSessionIndex': 1,
              },
            },
          ]),
        );

      final result = runDartTool([
        'tool/analyze_compare_replay_prompt_funnel.dart',
        '--output-json',
        '--max-payload-length',
        '10',
        input.path,
      ]);
      expect(result.exitCode, equals(1), reason: result.stderr.toString());
      expect(
        result.stderr.toString(),
        contains('COMPARE_REPLAY_PROMPT_FUNNEL_PAYLOAD_TOO_LARGE'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });
}
