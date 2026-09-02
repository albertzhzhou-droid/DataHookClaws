import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dartBinary =
      Platform.environment['DHC_DART_BIN'] ??
      Platform.environment['DART_BIN'] ??
      'dart';
  final dartEnv = Map<String, String>.from(Platform.environment)
    ..putIfAbsent('HOME', () => '/tmp/dhc_dart_checks_home')
    ..['DART_SUPPRESS_ANALYTICS'] = 'true';

  ProcessResult runDartToolWithEnv(
    List<String> args, {
    required Map<String, String> additionalEnv,
  }) {
    final scriptPath = args.isNotEmpty && args.first.endsWith('.dart')
        ? args.first
        : null;
    final dartArgs = args.toList(growable: false);
    ProcessResult runResult;
    final mergedEnv = Map<String, String>.from(dartEnv)..addAll(additionalEnv);
    try {
      runResult = Process.runSync(dartBinary, dartArgs, environment: mergedEnv);
    } on ProcessException catch (error) {
      return ProcessResult(0, 1, '', 'Failed to execute dart CLI: $error');
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
      ], environment: mergedEnv);
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
        environment: mergedEnv,
      );
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  ProcessResult runDartTool(List<String> args) {
    return runDartToolWithEnv(args, additionalEnv: const {});
  }

  test(
    'trend script reports warning and exits strict when trend drops violate caps',
    () {
      final tmpDir = Directory.systemTemp.createTempSync(
        'dhc-analyze-trend-warning-',
      );
      try {
        final trendLog = File('${tmpDir.path}/trend.log')
          ..writeAsStringSync(
            [
              '2026-08-17T21:00:00Z '
                  'COMPARE_REPLAY_A11Y_PARSED_JSON='
                  '${jsonEncode({
                    'runTimestampUtc': '2026-08-17T21:00:00Z',
                    'schemaVersion': '1.0.1',
                    'snapshotScope': 'scope-a',
                    'caseCount': 10,
                    'casesPassed': 10,
                    'casesFailed': 0,
                    'phraseCount': 4,
                    'phraseMissingCount': 0,
                    'phraseFoundCount': 4,
                    'phraseSemanticsPassCount': 4,
                    'phraseSemanticsFailCount': 0,
                    'liveRegionCheckedCount': 4,
                    'liveRegionPassCount': 4,
                    'liveRegionFailCount': 0,
                    'severityBuckets': {'high': 0},
                  })}',
              '2026-08-17T21:00:01Z '
                  'COMPARE_REPLAY_A11Y_PARSED_JSON='
                  '${jsonEncode({
                    'runTimestampUtc': '2026-08-17T21:00:01Z',
                    'schemaVersion': '1.0.1',
                    'snapshotScope': 'scope-a',
                    'caseCount': 10,
                    'casesPassed': 5,
                    'casesFailed': 5,
                    'phraseCount': 4,
                    'phraseMissingCount': 2,
                    'phraseFoundCount': 2,
                    'phraseSemanticsPassCount': 2,
                    'phraseSemanticsFailCount': 2,
                    'liveRegionCheckedCount': 4,
                    'liveRegionPassCount': 2,
                    'liveRegionFailCount': 2,
                    'severityBuckets': {'high': 0},
                  })}',
            ].join('\n'),
          );

        final warningResult = runDartToolWithEnv(
          [
            'tool/analyze_compare_accessibility_trends.dart',
            trendLog.path,
            '--window-runs',
            '2',
            '--output-json',
            '--trend-noise-window',
            '1',
          ],
          additionalEnv: {'CI': 'false'},
        );
        expect(warningResult.exitCode, equals(0));
        expect(warningResult.stdout.toString(), contains('"alerts"'));

        final strictResult = runDartToolWithEnv(
          [
            'tool/analyze_compare_accessibility_trends.dart',
            trendLog.path,
            '--window-runs',
            '2',
            '--trend-noise-window',
            '1',
            '--output-json',
          ],
          additionalEnv: {
            'CI': 'true',
            'DHC_A11Y_TREND_MAX_PASS_RATE_DROP': '0.10',
            'DHC_A11Y_TREND_MAX_PHRASE_SUCCESS_RATE_DROP': '0.10',
            'DHC_A11Y_TREND_MAX_LIVEREGION_RATE_DROP': '0.10',
            'DHC_A11Y_TREND_MAX_SEMANTICS_RATE_DROP': '0.10',
            'DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS': '0',
          },
        );
        expect(strictResult.exitCode, equals(1));
        expect(
          strictResult.stderr.toString(),
          contains('COMPARE_REPLAY_A11Y_TREND_GOVERNANCE_ALERTS='),
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'trend script exits with missing parsed lines code when no valid rows exist',
    () {
      final tmpDir = Directory.systemTemp.createTempSync(
        'dhc-analyze-trend-empty-',
      );
      try {
        final trendLog = File('${tmpDir.path}/trend.log')
          ..writeAsStringSync('not-a-parsed-line\n');

        final emptyResult = runDartTool([
          'tool/analyze_compare_accessibility_trends.dart',
          trendLog.path,
          '--output-json',
        ]);
        expect(emptyResult.exitCode, equals(2));
        expect(
          emptyResult.stderr.toString(),
          contains('no parsed JSON lines found'),
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    },
  );

  test('GitHub Actions workflow covers analyze, tests, importers, and web', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('flutter analyze'));
    expect(workflow, contains('flutter test'));
    expect(
      workflow,
      contains(
        'flutter test test/domain/source_importers_test.dart test/domain/it_crea_importer_test.dart',
      ),
    );
    expect(workflow, contains('flutter build web'));
    expect(workflow, contains('actions/upload-artifact@v4'));
  });

  test('GitHub Actions workflow uses read-only repository permissions', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('\npermissions:\n  contents: read\n'));
    expect(workflow, isNot(contains('permissions: write-all')));
  });

  test('GitHub Actions workflow cancels superseded runs per ref', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();

    expect(
      workflow,
      contains(r'''
concurrency:
  group: flutter-ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
'''),
    );
  });

  test('GitHub Actions release-evidence job has a bounded timeout', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();

    expect(
      workflow,
      contains(
        '  analyze-test-web:\n    runs-on: ubuntu-latest\n    timeout-minutes: 30\n',
      ),
    );
  });

  test('CI enforces the checked-in dependency lockfile', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();
    final localChecks = File('tool/ci_checks.sh').readAsStringSync();

    expect(workflow, contains('flutter pub get --enforce-lockfile'));
    expect(localChecks, contains("'Flutter dependency lockfile'"));
    expect(localChecks, contains('pub get --enforce-lockfile'));
  });

  test('CI builds the Web artifact explicitly in release mode', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();
    final localChecks = File('tool/ci_checks.sh').readAsStringSync();

    expect(workflow, contains('run: flutter build web --release'));
    expect(localChecks, contains("'Build web artifact'"));
    expect(localChecks, contains('build web --release'));
  });

  test('CI checkout does not persist repository credentials', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();

    expect(
      workflow,
      contains(
        'uses: actions/checkout@v4\n        with:\n          persist-credentials: false',
      ),
    );
  });

  test(
    'release metadata preflight validates package and native version handoff',
    () {
      final result = runDartTool(['tool/check_release_metadata.dart']);
      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(result.stdout.toString(), contains('RELEASE_METADATA_JSON='));
      expect(result.stdout.toString(), contains('"version":"1.0.0+1"'));
      expect(result.stdout.toString(), contains('"platformHandoff"'));
    },
  );

  test(
    'release metadata preflight rejects malformed semantic version metadata',
    () {
      final tmpDir = Directory.systemTemp.createTempSync(
        'dhc-release-metadata-invalid-',
      );
      try {
        File(
          '${tmpDir.path}/pubspec.yaml',
        ).writeAsStringSync('name: data_hook_claws\nversion: 1.0+1\n');
        final result = runDartTool([
          'tool/check_release_metadata.dart',
          '--root',
          tmpDir.path,
        ]);
        expect(result.exitCode, equals(1));
        expect(
          result.stderr.toString(),
          contains('pubspec.yaml version must be SemVer'),
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    },
  );

  test('release metadata preflight can require production Android signing', () {
    final result = runDartTool([
      'tool/check_release_metadata.dart',
      '--require-release-signing',
    ]);
    expect(result.exitCode, equals(1));
    expect(
      result.stderr.toString(),
      contains('Android release build still uses debug signing'),
    );
  });

  test('release metadata preflight can require Apple distribution signing', () {
    final result = runDartTool([
      'tool/check_release_metadata.dart',
      '--require-apple-signing',
    ]);
    expect(result.exitCode, equals(1));
    expect(
      result.stderr.toString(),
      contains('iOS Release configuration uses a development or placeholder'),
    );
    expect(
      result.stderr.toString(),
      contains('macOS Release configuration uses a development or placeholder'),
    );
  });

  test(
    'release metadata preflight can require production platform identifiers',
    () {
      final result = runDartTool([
        'tool/check_release_metadata.dart',
        '--require-production-identifiers',
      ]);
      expect(result.exitCode, equals(1));
      expect(
        result.stderr.toString(),
        contains('applicationId "com.example.data_hook_claws" is a template'),
      );
      expect(
        result.stderr.toString(),
        contains('iOS Release bundle identifier'),
      );
      expect(
        result.stderr.toString(),
        contains('macOS Release bundle identifier'),
      );
    },
  );

  test('release metadata preflight is wired for clean CI releases', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();
    final localChecks = File('tool/ci_checks.sh').readAsStringSync();

    expect(workflow, contains('tool/check_release_metadata.dart'));
    expect(workflow, contains('--require-clean'));
    expect(localChecks, contains("'release metadata preflight'"));
    expect(localChecks, contains('tool/check_release_metadata.dart'));
    expect(
      File('docs/release_packaging.md').readAsStringSync(),
      contains('--require-release-signing'),
    );
    expect(
      File('docs/release_packaging.md').readAsStringSync(),
      contains('--require-apple-signing'),
    );
    expect(
      File('docs/release_packaging.md').readAsStringSync(),
      contains('--require-production-identifiers'),
    );
  });

  test('release provenance manifest is deterministic and excludes itself', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-provenance-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      Directory('${artifactDir.path}/nested').createSync();
      File('${artifactDir.path}/b.txt').writeAsStringSync('abc');
      File('${artifactDir.path}/nested/a.txt').writeAsStringSync('alpha');
      final outputPath = '${tmpDir.path}/manifest.json';

      final firstResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-artifact',
        '--revision',
        'fixture-revision',
      ]);
      expect(
        firstResult.exitCode,
        equals(0),
        reason: firstResult.stderr.toString(),
      );
      final firstManifest = File(outputPath).readAsStringSync();
      final payload = jsonDecode(firstManifest) as Map<String, dynamic>;
      expect(payload['artifact'], equals('fixture-artifact'));
      expect(payload['sourceRevision'], equals('fixture-revision'));
      expect(payload['fileCount'], equals(2));
      expect(
        ((payload['files'] as List<dynamic>).first
            as Map<String, dynamic>)['sha256'],
        equals(
          'ba7816bf8f01cfea414140de5dae2223'
          'b00361a396177a9cb410ff61f20015ad',
        ),
      );
      expect(
        (payload['files'] as List<dynamic>)
            .map((entry) => (entry as Map<String, dynamic>)['path'])
            .toList(),
        equals(['b.txt', 'nested/a.txt']),
      );

      final secondResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-artifact',
        '--revision',
        'fixture-revision',
      ]);
      expect(secondResult.exitCode, equals(0));
      expect(File(outputPath).readAsStringSync(), equals(firstManifest));

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-artifact',
        '--revision',
        'fixture-revision',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );
      File('${artifactDir.path}/b.txt').writeAsStringSync('changed');
      final tamperedResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-artifact',
        '--revision',
        'fixture-revision',
      ]);
      expect(tamperedResult.exitCode, equals(1));
      expect(tamperedResult.stderr.toString(), contains('differs'));

      final unsafeResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        '${artifactDir.path}/manifest.json',
      ]);
      expect(unsafeResult.exitCode, equals(1));
      expect(
        unsafeResult.stderr.toString(),
        contains('outside the artifact directory'),
      );

      final redirectedDir = Directory('${tmpDir.path}/artifact-link');
      Link(redirectedDir.path).createSync(artifactDir.path);
      try {
        final redirectedResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--input',
          artifactDir.path,
          '--output',
          '${redirectedDir.path}/manifest.json',
        ]);
        expect(redirectedResult.exitCode, equals(1));
        expect(
          redirectedResult.stderr.toString(),
          contains('including symlink targets'),
        );
      } finally {
        redirectedDir.deleteSync();
      }

      final inputLink = Directory('${tmpDir.path}/input-link');
      Link(inputLink.path).createSync(artifactDir.path);
      try {
        final symlinkInputResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--input',
          inputLink.path,
          '--output',
          '${tmpDir.path}/symlink-input-manifest.json',
        ]);
        expect(symlinkInputResult.exitCode, equals(1));
        expect(
          symlinkInputResult.stderr.toString(),
          contains('must be a regular directory, not a symlink'),
        );
      } finally {
        inputLink.deleteSync();
      }

      final danglingOutputLink = Link('${tmpDir.path}/dangling-output.json');
      danglingOutputLink.createSync(
        '${tmpDir.path}/missing-output-target.json',
      );
      try {
        final danglingOutputResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--input',
          artifactDir.path,
          '--output',
          danglingOutputLink.path,
        ]);
        expect(danglingOutputResult.exitCode, equals(1));
        expect(
          danglingOutputResult.stderr.toString(),
          contains('Provenance output could not be resolved safely'),
        );
      } finally {
        danglingOutputLink.deleteSync();
      }

      final danglingVerifyLink = Link('${tmpDir.path}/dangling-verify.json');
      danglingVerifyLink.createSync(
        '${tmpDir.path}/missing-verify-target.json',
      );
      try {
        final danglingVerifyResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--input',
          artifactDir.path,
          '--verify',
          danglingVerifyLink.path,
        ]);
        expect(danglingVerifyResult.exitCode, equals(1));
        expect(
          danglingVerifyResult.stderr.toString(),
          contains(
            'Provenance manifest to verify could not be resolved safely',
          ),
        );
      } finally {
        danglingVerifyLink.deleteSync();
      }

      final danglingInputLink = Link('${tmpDir.path}/dangling-input');
      danglingInputLink.createSync('${tmpDir.path}/missing-input-target');
      try {
        final danglingInputResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--input',
          danglingInputLink.path,
          '--output',
          '${tmpDir.path}/dangling-input-manifest.json',
        ]);
        expect(danglingInputResult.exitCode, equals(1));
        expect(
          danglingInputResult.stderr.toString(),
          contains('Artifact path could not be resolved safely'),
        );
      } finally {
        danglingInputLink.deleteSync();
      }
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance verification rejects unknown schema fields', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-provenance-schema-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File('${artifactDir.path}/index.html').writeAsStringSync('web');
      final outputPath = '${tmpDir.path}/manifest.json';
      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-schema',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final rootTampered =
          jsonDecode(File(outputPath).readAsStringSync())
              as Map<String, dynamic>;
      rootTampered['futureField'] = true;
      File(outputPath).writeAsStringSync(jsonEncode(rootTampered));
      final rootResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-schema',
      ]);
      expect(rootResult.exitCode, equals(1));
      expect(
        rootResult.stderr.toString(),
        contains('root fields must exactly match'),
      );

      final regenerateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-schema',
      ]);
      expect(regenerateResult.exitCode, equals(0));
      final entryTampered =
          jsonDecode(File(outputPath).readAsStringSync())
              as Map<String, dynamic>;
      final files = entryTampered['files'] as List<dynamic>;
      (files.single as Map<String, dynamic>)['futureField'] = true;
      File(outputPath).writeAsStringSync(jsonEncode(entryTampered));
      final entryResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-schema',
      ]);
      expect(entryResult.exitCode, equals(1));
      expect(
        entryResult.stderr.toString(),
        contains('entry 0 fields must exactly match'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test(
    'release provenance generation is wired into the Web artifact upload',
    () {
      final workflow = File(
        '.github/workflows/flutter-ci.yml',
      ).readAsStringSync();
      final localChecks = File('tool/ci_checks.sh').readAsStringSync();

      expect(workflow, contains('tool/build_release_provenance.dart'));
      expect(workflow, contains('build/datahookclaws-web.provenance.json'));
      expect(workflow, contains('--require-web-version'));
      expect(workflow, contains('--require-web-shell'));
      expect(workflow, contains('--require-web-shell-references'));
      expect(workflow, contains('--require-web-root-base-href'));
      expect(workflow, contains('--require-web-metadata-parity'));
      expect(workflow, contains('--require-web-pwa-contract'));
      expect(workflow, contains('--require-web-pwa-identity'));
      expect(workflow, contains('--require-web-viewport'));
      expect(workflow, contains('--require-web-language'));
      expect(workflow, contains('--require-web-title-parity'));
      expect(workflow, contains('--require-web-manifest-icon-metadata'));
      expect(workflow, contains('--require-web-theme-color-parity'));
      expect(workflow, contains('--require-web-service-worker-contract'));
      expect(workflow, contains('--require-web-manifest'));
      expect(workflow, contains('--require-web-manifest-assets'));
      expect(workflow, contains(r'--revision "$GITHUB_SHA"'));
      expect(workflow, contains('--require-revision'));
      expect(
        workflow,
        contains('--verify build/datahookclaws-web.provenance.json'),
      );
      expect(workflow, contains('include-hidden-files: true'));
      expect(workflow, contains('if-no-files-found: error'));
      expect(workflow, contains('retention-days: 14'));
      expect(localChecks, contains("'release artifact provenance manifest'"));
      expect(
        localChecks,
        contains("'release artifact provenance verification'"),
      );
      expect(localChecks, contains('tool/build_release_provenance.dart'));
      expect(localChecks, contains('--require-web-version'));
      expect(localChecks, contains('--require-web-shell'));
      expect(localChecks, contains('--require-web-shell-references'));
      expect(localChecks, contains('--require-web-root-base-href'));
      expect(localChecks, contains('--require-web-metadata-parity'));
      expect(localChecks, contains('--require-web-pwa-contract'));
      expect(localChecks, contains('--require-web-pwa-identity'));
      expect(localChecks, contains('--require-web-viewport'));
      expect(localChecks, contains('--require-web-language'));
      expect(localChecks, contains('--require-web-title-parity'));
      expect(localChecks, contains('--require-web-manifest-icon-metadata'));
      expect(localChecks, contains('--require-web-theme-color-parity'));
      expect(localChecks, contains('--require-web-service-worker-contract'));
      expect(localChecks, contains('--require-web-manifest'));
      expect(localChecks, contains('--require-web-manifest-assets'));
      expect(
        localChecks,
        contains(r'source_revision="${DHC_SOURCE_REVISION:-}"'),
      );
      expect(localChecks, contains('git rev-parse --verify HEAD'));
      expect(localChecks, contains(r'--revision "$source_revision"'));
      expect(localChecks, contains('--require-revision'));
    },
  );

  test('release provenance can require a non-empty source revision', () {
    final tmpDir = Directory.systemTemp.createTempSync('dhc-release-revision-');
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File('${artifactDir.path}/index.html').writeAsStringSync('web');
      final outputPath = '${tmpDir.path}/manifest.json';

      final missingResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-revision',
        '--require-revision',
      ]);
      expect(missingResult.exitCode, equals(1));
      expect(
        missingResult.stderr.toString(),
        contains('--require-revision requires a non-empty --revision value'),
      );

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-revision',
        '--revision',
        'fixture-source-commit',
        '--require-revision',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );
      final payload =
          jsonDecode(File(outputPath).readAsStringSync())
              as Map<String, dynamic>;
      expect(payload['sourceRevision'], equals('fixture-source-commit'));

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-revision',
        '--revision',
        'fixture-source-commit',
        '--require-revision',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require generated Web version metadata', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-version-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File('${artifactDir.path}/version.json').writeAsStringSync(
        jsonEncode({
          'app_name': 'data_hook_claws',
          'version': '1.0.0',
          'build_number': '1',
          'package_name': 'data_hook_claws',
        }),
      );
      File('${artifactDir.path}/index.html').writeAsStringSync('web');
      final outputPath = '${tmpDir.path}/manifest.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web',
        '--require-web-version',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web',
        '--require-web-version',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      File('${artifactDir.path}/version.json').writeAsStringSync(
        jsonEncode({
          'app_name': 'data_hook_claws',
          'version': '9.9.9',
          'build_number': '1',
          'package_name': 'data_hook_claws',
        }),
      );
      final mismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web',
        '--require-web-version',
      ]);
      expect(mismatchResult.exitCode, equals(1));
      expect(
        mismatchResult.stderr.toString(),
        contains('Web artifact version.json field "version" differs'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require the core Web shell', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-shell-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      for (final fileName in const [
        'index.html',
        'flutter_bootstrap.js',
        'main.dart.js',
        'manifest.json',
      ]) {
        File('${artifactDir.path}/$fileName').writeAsStringSync('shell');
      }
      final outputPath = '${tmpDir.path}/manifest.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-shell',
        '--require-web-shell',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-shell',
        '--require-web-shell',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      File('${artifactDir.path}/main.dart.js').deleteSync();
      final missingResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-shell',
        '--require-web-shell',
      ]);
      expect(missingResult.exitCode, equals(1));
      expect(
        missingResult.stderr.toString(),
        contains('missing required shell file "main.dart.js"'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require Web shell references', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-shell-references-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      final iconsDir = Directory('${artifactDir.path}/icons')..createSync();
      File(
        '${artifactDir.path}/flutter_bootstrap.js',
      ).writeAsStringSync('bootstrap');
      File('${artifactDir.path}/manifest.json').writeAsStringSync('{}');
      File('${artifactDir.path}/favicon.png').writeAsBytesSync([1]);
      File('${iconsDir.path}/Icon-192.png').writeAsBytesSync([1, 2]);
      File('${artifactDir.path}/index.html').writeAsStringSync('''
<script async src="flutter_bootstrap.js"></script>
<link href="manifest.json" rel="manifest">
<link rel="icon" href="favicon.png">
<link rel="apple-touch-icon" href="icons/Icon-192.png">
''');
      final outputPath = '${tmpDir.path}/manifest-output.json';
      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-shell-references',
        '--require-web-shell-references',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-shell-references',
        '--require-web-shell-references',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      File('${artifactDir.path}/favicon.png').deleteSync();
      final missingAssetResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-shell-references',
        '--require-web-shell-references',
      ]);
      expect(missingAssetResult.exitCode, equals(1));
      expect(
        missingAssetResult.stderr.toString(),
        contains('favicon link "favicon.png" must resolve to a regular file'),
      );

      File('${artifactDir.path}/favicon.png').writeAsBytesSync([1]);
      File('${artifactDir.path}/index.html').writeAsStringSync('''
<script async src="flutter_bootstrap.js"></script>
<link rel="icon" href="favicon.png">
<link rel="apple-touch-icon" href="icons/Icon-192.png">
''');
      final missingReferenceResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-shell-references',
        '--require-web-shell-references',
      ]);
      expect(missingReferenceResult.exitCode, equals(1));
      expect(
        missingReferenceResult.stderr.toString(),
        contains(
          'index.html must reference manifest.json with a manifest link',
        ),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require Web manifest package identity', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-manifest-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File('${artifactDir.path}/manifest.json').writeAsStringSync(
        jsonEncode({
          'name': 'data_hook_claws',
          'short_name': 'data_hook_claws',
        }),
      );
      File('${artifactDir.path}/index.html').writeAsStringSync('web');
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest',
        '--require-web-manifest',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest',
        '--require-web-manifest',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      File('${artifactDir.path}/manifest.json').writeAsStringSync(
        jsonEncode({
          'name': 'stale_data_hook_claws',
          'short_name': 'data_hook_claws',
        }),
      );
      final mismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest',
        '--require-web-manifest',
      ]);
      expect(mismatchResult.exitCode, equals(1));
      expect(
        mismatchResult.stderr.toString(),
        contains('manifest.json field "name" differs'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require Web manifest icon assets', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-manifest-assets-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      final iconsDir = Directory('${artifactDir.path}/icons')..createSync();
      File('${iconsDir.path}/Icon-192.png').writeAsBytesSync([1, 2, 3]);
      File('${artifactDir.path}/manifest.json').writeAsStringSync(
        jsonEncode({
          'name': 'data_hook_claws',
          'short_name': 'data_hook_claws',
          'icons': [
            {
              'src': 'icons/Icon-192.png',
              'sizes': '192x192',
              'type': 'image/png',
            },
          ],
        }),
      );
      final outputPath = '${tmpDir.path}/manifest-output.json';
      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest-assets',
        '--require-web-manifest',
        '--require-web-manifest-assets',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest-assets',
        '--require-web-manifest',
        '--require-web-manifest-assets',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      File('${iconsDir.path}/Icon-192.png').deleteSync();
      final missingResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest-assets',
        '--require-web-manifest-assets',
      ]);
      expect(missingResult.exitCode, equals(1));
      expect(
        missingResult.stderr.toString(),
        contains(
          'icon source "icons/Icon-192.png" must resolve to a regular file',
        ),
      );

      File('${iconsDir.path}/Icon-192.png').writeAsBytesSync([1, 2, 3]);
      File('${artifactDir.path}/manifest.json').writeAsStringSync(
        jsonEncode({
          'name': 'data_hook_claws',
          'short_name': 'data_hook_claws',
          'icons': [
            {'src': '../outside.png'},
          ],
        }),
      );
      final unsafeResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-manifest-assets',
        '--require-web-manifest-assets',
      ]);
      expect(unsafeResult.exitCode, equals(1));
      expect(
        unsafeResult.stderr.toString(),
        contains('must be a safe relative path inside the artifact'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('Web shell metadata is product-facing rather than template text', () {
    const productDescription =
        'Local-first nutrition database built from official food-composition sources.';
    final manifest = File('web/manifest.json').readAsStringSync();
    final index = File('web/index.html').readAsStringSync();

    expect(index, startsWith('<!DOCTYPE html>\n<html lang="en">'));
    expect(manifest, contains(productDescription));
    expect(index, contains(productDescription));
    expect(index, contains('<meta name="theme-color" content="#0175C2">'));
    expect(
      index,
      contains(
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
      ),
    );
    expect(manifest, contains('"id": "/"'));
    expect(manifest, contains('"scope": "/"'));
    expect(manifest, isNot(contains('A new Flutter project.')));
    expect(index, isNot(contains('A new Flutter project.')));
  });

  test('release provenance can require Web metadata parity', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-metadata-parity-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final sourceWebDir = Directory('${rootDir.path}/web')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File(
        '${rootDir.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_metadata\nversion: 1.0.0+1\n');
      const description = 'Canonical fixture description.';
      File(
        '${sourceWebDir.path}/index.html',
      ).writeAsStringSync('<meta name="description" content="$description">');
      File(
        '${sourceWebDir.path}/manifest.json',
      ).writeAsStringSync(jsonEncode({'description': description}));
      File(
        '${artifactDir.path}/index.html',
      ).writeAsStringSync('<meta content="$description" name="description">');
      File(
        '${artifactDir.path}/manifest.json',
      ).writeAsStringSync(jsonEncode({'description': description}));
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-metadata',
        '--require-web-metadata-parity',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      File('${artifactDir.path}/index.html').writeAsStringSync(
        '<meta name="description" content="stale fixture description.">',
      );
      final indexMismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-metadata',
        '--require-web-metadata-parity',
      ]);
      expect(indexMismatchResult.exitCode, equals(1));
      expect(
        indexMismatchResult.stderr.toString(),
        contains('Web artifact index.html meta description differs'),
      );

      File(
        '${artifactDir.path}/index.html',
      ).writeAsStringSync('<meta name="description" content="$description">');
      File('${artifactDir.path}/manifest.json').writeAsStringSync(
        jsonEncode({'description': 'stale fixture description.'}),
      );
      final manifestMismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-metadata',
        '--require-web-metadata-parity',
      ]);
      expect(manifestMismatchResult.exitCode, equals(1));
      expect(
        manifestMismatchResult.stderr.toString(),
        contains('Web artifact manifest.json description differs'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require the Web PWA contract', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-pwa-contract-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      final manifestFile = File('${artifactDir.path}/manifest.json');
      final validManifest = {
        'start_url': '.',
        'display': 'standalone',
        'background_color': '#0175C2',
        'theme_color': '#0175C2',
      };
      manifestFile.writeAsStringSync(jsonEncode(validManifest));
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa',
        '--require-web-pwa-contract',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      manifestFile.writeAsStringSync(
        jsonEncode({...validManifest, 'start_url': 'https://example.com'}),
      );
      final externalStartResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa',
        '--require-web-pwa-contract',
      ]);
      expect(externalStartResult.exitCode, equals(1));
      expect(
        externalStartResult.stderr.toString(),
        contains(
          'start_url "https://example.com" must be a safe relative path',
        ),
      );

      manifestFile.writeAsStringSync(
        jsonEncode({...validManifest, 'display': 'floating'}),
      );
      final displayResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa',
        '--require-web-pwa-contract',
      ]);
      expect(displayResult.exitCode, equals(1));
      expect(
        displayResult.stderr.toString(),
        contains('display must be one of'),
      );

      manifestFile.writeAsStringSync(
        jsonEncode({...validManifest}..remove('theme_color')),
      );
      final colorResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa',
        '--require-web-pwa-contract',
      ]);
      expect(colorResult.exitCode, equals(1));
      expect(
        colorResult.stderr.toString(),
        contains('theme_color must be a non-empty color value'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require Web theme-color parity', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-theme-color-parity-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final sourceWebDir = Directory('${rootDir.path}/web')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File(
        '${rootDir.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_theme\nversion: 1.0.0+1\n');
      const color = '#0175C2';
      File(
        '${sourceWebDir.path}/index.html',
      ).writeAsStringSync('<meta name="theme-color" content="$color">');
      File(
        '${sourceWebDir.path}/manifest.json',
      ).writeAsStringSync(jsonEncode({'theme_color': color}));
      File(
        '${artifactDir.path}/index.html',
      ).writeAsStringSync('<meta content="$color" name="theme-color">');
      final artifactManifest = File('${artifactDir.path}/manifest.json')
        ..writeAsStringSync(jsonEncode({'theme_color': color}));
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-theme',
        '--require-web-theme-color-parity',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      File(
        '${artifactDir.path}/index.html',
      ).writeAsStringSync('<meta name="theme-color" content="#FFFFFF">');
      final indexMismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-theme',
        '--require-web-theme-color-parity',
      ]);
      expect(indexMismatchResult.exitCode, equals(1));
      expect(
        indexMismatchResult.stderr.toString(),
        contains('Web artifact index.html theme-color differs'),
      );

      File(
        '${artifactDir.path}/index.html',
      ).writeAsStringSync('<meta name="theme-color" content="$color">');
      artifactManifest.writeAsStringSync(
        jsonEncode({'theme_color': '#FFFFFF'}),
      );
      final manifestMismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-theme',
        '--require-web-theme-color-parity',
      ]);
      expect(manifestMismatchResult.exitCode, equals(1));
      expect(
        manifestMismatchResult.stderr.toString(),
        contains('Web artifact manifest.json theme_color differs'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require the Web service-worker contract', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-service-worker-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File(
        '${rootDir.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_worker\nversion: 1.0.0+1\n');
      File('${artifactDir.path}/flutter_bootstrap.js').writeAsStringSync(r'''
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: "123456789"
  }
});
''');
      final workerFile = File('${artifactDir.path}/flutter_service_worker.js')
        ..writeAsStringSync(r'''
'use strict';
self.addEventListener('install', () => {
  self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil(self.registration.unregister());
});
''');
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-service-worker',
        '--require-web-service-worker-contract',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-service-worker',
        '--require-web-service-worker-contract',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      workerFile.writeAsStringSync(r'''
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => caches.open('stale-cache'));
self.addEventListener('fetch', () => {});
''');
      final staleWorkerResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-service-worker',
        '--require-web-service-worker-contract',
      ]);
      expect(staleWorkerResult.exitCode, equals(1));
      expect(
        staleWorkerResult.stderr.toString(),
        contains('must not access CacheStorage'),
      );

      workerFile.writeAsStringSync(r'''
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.registration.unregister());
''');
      File('${artifactDir.path}/flutter_bootstrap.js').writeAsStringSync(r'''
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: "unsafe version"
  }
});
''');
      final unsafeVersionResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-service-worker',
        '--require-web-service-worker-contract',
      ]);
      expect(unsafeVersionResult.exitCode, equals(1));
      expect(
        unsafeVersionResult.stderr.toString(),
        contains('must be a safe cache-busting token'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require the Web root base-href contract', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-root-base-href-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File(
        '${rootDir.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_base_href\nversion: 1.0.0+1\n');
      final indexFile = File('${artifactDir.path}/index.html')
        ..writeAsStringSync('<base href="/">');
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-root-base-href',
        '--require-web-root-base-href',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-root-base-href',
        '--require-web-root-base-href',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      indexFile.writeAsStringSync(r'<base href="$FLUTTER_BASE_HREF">');
      final unresolvedResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-root-base-href',
        '--require-web-root-base-href',
      ]);
      expect(unresolvedResult.exitCode, equals(1));
      expect(
        unresolvedResult.stderr.toString(),
        contains('base href must be exactly "/"'),
      );

      indexFile.writeAsStringSync('<base href="/"><base href="/app/">');
      final duplicateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-root-base-href',
        '--require-web-root-base-href',
      ]);
      expect(duplicateResult.exitCode, equals(1));
      expect(
        duplicateResult.stderr.toString(),
        contains('must contain exactly one base tag'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require the root PWA identity contract', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-pwa-identity-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final sourceWebDir = Directory('${rootDir.path}/web')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File(
        '${rootDir.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_pwa_identity\nversion: 1.0.0+1\n');
      const identity = {'id': '/', 'scope': '/'};
      File(
        '${sourceWebDir.path}/manifest.json',
      ).writeAsStringSync(jsonEncode(identity));
      final artifactManifest = File('${artifactDir.path}/manifest.json')
        ..writeAsStringSync(jsonEncode(identity));
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa-identity',
        '--require-web-pwa-identity',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa-identity',
        '--require-web-pwa-identity',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      artifactManifest.writeAsStringSync(
        jsonEncode({...identity, 'id': '/app/'}),
      );
      final idMismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa-identity',
        '--require-web-pwa-identity',
      ]);
      expect(idMismatchResult.exitCode, equals(1));
      expect(
        idMismatchResult.stderr.toString(),
        contains('manifest.json id must be exactly "/"'),
      );

      artifactManifest.writeAsStringSync(
        jsonEncode({...identity, 'scope': '/app/'}),
      );
      final scopeMismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-pwa-identity',
        '--require-web-pwa-identity',
      ]);
      expect(scopeMismatchResult.exitCode, equals(1));
      expect(
        scopeMismatchResult.stderr.toString(),
        contains('manifest.json scope must be exactly "/"'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test(
    'release provenance can require the responsive Web viewport contract',
    () {
      final tmpDir = Directory.systemTemp.createTempSync(
        'dhc-release-web-viewport-',
      );
      try {
        final rootDir = Directory('${tmpDir.path}/root')..createSync();
        final sourceWebDir = Directory('${rootDir.path}/web')..createSync();
        final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
        File(
          '${rootDir.path}/pubspec.yaml',
        ).writeAsStringSync('name: fixture_viewport\nversion: 1.0.0+1\n');
        const viewport = 'width=device-width, initial-scale=1.0';
        File(
          '${sourceWebDir.path}/index.html',
        ).writeAsStringSync('<meta content="$viewport" name="viewport">');
        final indexFile = File('${artifactDir.path}/index.html')
          ..writeAsStringSync('<meta name="viewport" content="$viewport">');
        final outputPath = '${tmpDir.path}/manifest-output.json';

        final generateResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--root',
          rootDir.path,
          '--input',
          artifactDir.path,
          '--output',
          outputPath,
          '--artifact-name',
          'fixture-web-viewport',
          '--require-web-viewport',
        ]);
        expect(
          generateResult.exitCode,
          equals(0),
          reason: generateResult.stderr.toString(),
        );

        final verifyResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--root',
          rootDir.path,
          '--input',
          artifactDir.path,
          '--verify',
          outputPath,
          '--artifact-name',
          'fixture-web-viewport',
          '--require-web-viewport',
        ]);
        expect(
          verifyResult.exitCode,
          equals(0),
          reason: verifyResult.stderr.toString(),
        );

        indexFile.writeAsStringSync(
          '<meta name="viewport" content="width=device-width">',
        );
        final mismatchResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--root',
          rootDir.path,
          '--input',
          artifactDir.path,
          '--verify',
          outputPath,
          '--artifact-name',
          'fixture-web-viewport',
          '--require-web-viewport',
        ]);
        expect(mismatchResult.exitCode, equals(1));
        expect(
          mismatchResult.stderr.toString(),
          contains('viewport meta must equal canonical value'),
        );

        indexFile.writeAsStringSync(
          '<meta name="viewport" content="$viewport">'
          '<meta name="viewport" content="$viewport">',
        );
        final duplicateResult = runDartTool([
          'tool/build_release_provenance.dart',
          '--root',
          rootDir.path,
          '--input',
          artifactDir.path,
          '--verify',
          outputPath,
          '--artifact-name',
          'fixture-web-viewport',
          '--require-web-viewport',
        ]);
        expect(duplicateResult.exitCode, equals(1));
        expect(duplicateResult.stderr.toString(), contains('found 2 value(s)'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    },
  );

  test('release provenance can require the English Web language contract', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-language-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final sourceWebDir = Directory('${rootDir.path}/web')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File(
        '${rootDir.path}/pubspec.yaml',
      ).writeAsStringSync('name: fixture_language\nversion: 1.0.0+1\n');
      File(
        '${sourceWebDir.path}/index.html',
      ).writeAsStringSync('<!DOCTYPE html><html lang="en">');
      final indexFile = File('${artifactDir.path}/index.html')
        ..writeAsStringSync('<!DOCTYPE html><html lang="en">');
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-language',
        '--require-web-language',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-language',
        '--require-web-language',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      indexFile.writeAsStringSync('<!DOCTYPE html><html lang="fr">');
      final mismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-language',
        '--require-web-language',
      ]);
      expect(mismatchResult.exitCode, equals(1));
      expect(
        mismatchResult.stderr.toString(),
        contains('html lang must be exactly "en"'),
      );

      indexFile.writeAsStringSync('<!DOCTYPE html><html>');
      final missingResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-language',
        '--require-web-language',
      ]);
      expect(missingResult.exitCode, equals(1));
      expect(
        missingResult.stderr.toString(),
        contains('html lang must be exactly "en"'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require Web title parity', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-title-parity-',
    );
    try {
      final rootDir = Directory('${tmpDir.path}/root')..createSync();
      final sourceWebDir = Directory('${rootDir.path}/web')..createSync();
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      File('${rootDir.path}/pubspec.yaml').writeAsStringSync(
        'name: fixture_title${String.fromCharCode(10)}version: 1.0.0+1',
      );
      const title = 'Fixture nutrition dashboard';
      File(
        '${sourceWebDir.path}/index.html',
      ).writeAsStringSync('<!DOCTYPE html><title>$title</title>');
      final indexFile = File('${artifactDir.path}/index.html')
        ..writeAsStringSync('<!DOCTYPE html><title>$title</title>');
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-title-parity',
        '--require-web-title-parity',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final verifyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-title-parity',
        '--require-web-title-parity',
      ]);
      expect(
        verifyResult.exitCode,
        equals(0),
        reason: verifyResult.stderr.toString(),
      );

      indexFile.writeAsStringSync(
        '<!DOCTYPE html><title>Changed title</title>',
      );
      final mismatchResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-title-parity',
        '--require-web-title-parity',
      ]);
      expect(mismatchResult.exitCode, equals(1));
      expect(
        mismatchResult.stderr.toString(),
        contains('title differs from canonical'),
      );

      indexFile.writeAsStringSync(
        '<!DOCTYPE html><title>$title</title><title>$title</title>',
      );
      final duplicateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-title-parity',
        '--require-web-title-parity',
      ]);
      expect(duplicateResult.exitCode, equals(1));
      expect(duplicateResult.stderr.toString(), contains('found 2 value(s)'));

      indexFile.writeAsStringSync('<!DOCTYPE html><title> </title>');
      final emptyResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--root',
        rootDir.path,
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-title-parity',
        '--require-web-title-parity',
      ]);
      expect(emptyResult.exitCode, equals(1));
      expect(
        emptyResult.stderr.toString(),
        contains('exactly one non-empty <title>'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('release provenance can require Web manifest icon metadata', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-release-web-manifest-icon-metadata-',
    );
    try {
      final artifactDir = Directory('${tmpDir.path}/artifact')..createSync();
      final manifestFile = File('${artifactDir.path}/manifest.json');
      final validIcons = [
        {'src': 'icons/Icon-192.png', 'sizes': '192x192', 'type': 'image/png'},
        {
          'src': 'icons/Icon-maskable-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable',
        },
      ];
      manifestFile.writeAsStringSync(jsonEncode({'icons': validIcons}));
      final outputPath = '${tmpDir.path}/manifest-output.json';

      final generateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-icon-metadata',
        '--require-web-manifest-icon-metadata',
      ]);
      expect(
        generateResult.exitCode,
        equals(0),
        reason: generateResult.stderr.toString(),
      );

      final iconsDir = Directory('${artifactDir.path}/icons')..createSync();
      File('${iconsDir.path}/Icon-192.png').writeAsBytesSync([1]);
      File('${iconsDir.path}/Icon-maskable-512.png').writeAsBytesSync([1]);
      final secondGenerateResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--output',
        outputPath,
        '--artifact-name',
        'fixture-web-icon-metadata',
        '--require-web-manifest-assets',
        '--require-web-manifest-icon-metadata',
      ]);
      expect(
        secondGenerateResult.exitCode,
        equals(0),
        reason: secondGenerateResult.stderr.toString(),
      );

      manifestFile.writeAsStringSync(
        jsonEncode({
          'icons': [
            {...validIcons.first, 'sizes': '0x192'},
            validIcons[1],
          ],
        }),
      );
      final sizeResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-icon-metadata',
        '--require-web-manifest-icon-metadata',
      ]);
      expect(sizeResult.exitCode, equals(1));
      expect(
        sizeResult.stderr.toString(),
        contains('sizes must contain positive WIDTHxHEIGHT values'),
      );

      manifestFile.writeAsStringSync(
        jsonEncode({
          'icons': [
            {...validIcons.first, 'type': 'text/plain'},
            validIcons[1],
          ],
        }),
      );
      final typeResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-icon-metadata',
        '--require-web-manifest-icon-metadata',
      ]);
      expect(typeResult.exitCode, equals(1));
      expect(
        typeResult.stderr.toString(),
        contains('type must be a supported image MIME type'),
      );

      manifestFile.writeAsStringSync(
        jsonEncode({
          'icons': [
            {...validIcons.first, 'purpose': 'invalid'},
            validIcons[1],
          ],
        }),
      );
      final purposeResult = runDartTool([
        'tool/build_release_provenance.dart',
        '--input',
        artifactDir.path,
        '--verify',
        outputPath,
        '--artifact-name',
        'fixture-web-icon-metadata',
        '--require-web-manifest-icon-metadata',
      ]);
      expect(purposeResult.exitCode, equals(1));
      expect(
        purposeResult.stderr.toString(),
        contains('purpose must use only any, maskable, or monochrome'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test(
    'compare accessibility pipeline trends parsed output, not raw output',
    () {
      final workflow = File(
        '.github/workflows/flutter-ci.yml',
      ).readAsStringSync();
      final localChecks = File('tool/ci_checks.sh').readAsStringSync();

      const rawLog = '/tmp/compare_replay_accessibility_check.log';
      const parsedLog = '/tmp/compare_replay_accessibility_parsed.log';

      expect(
        workflow,
        contains('tool/parse_compare_accessibility_report.dart'),
      );
      expect(workflow, contains(rawLog));
      expect(workflow, contains('| tee $parsedLog'));
      expect(workflow, contains('analyze_compare_accessibility_trends.dart'));
      expect(workflow, contains('set -o pipefail'));
      expect(
        localChecks,
        contains(
          'run_local_dart_check \'compare accessibility parsed output check\'',
        ),
      );
      expect(localChecks, contains('--tee $parsedLog'));
      expect(
        localChecks,
        contains('tool/parse_compare_accessibility_report.dart $rawLog'),
      );
      expect(
        localChecks,
        contains('analyze_compare_accessibility_trends.dart'),
      );
      expect(
        localChecks,
        contains('analyze_compare_replay_prompt_funnel.dart'),
      );
      expect(localChecks, contains(r'"$prompt_funnel_input"'));
    },
  );

  test('compare replay prompt funnel regression is wired into CI checks', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();
    final localChecks = File('tool/ci_checks.sh').readAsStringSync();

    expect(
      workflow,
      contains('Prepare CI Dart package config for local scripts'),
    );
    expect(
      workflow,
      contains(
        'dart --packages=/tmp/dhc_github_dart_tool_packages.json '
        'tool/analyze_compare_replay_prompt_funnel.dart',
      ),
    );
    expect(workflow, contains('HOME=/tmp/dhc_dart_checks_home'));
    expect(localChecks, contains('compare replay prompt funnel check'));
    expect(
      localChecks,
      contains(
        r'prompt_funnel_input="${DHC_COMPARE_REPLAY_PROMPT_FUNNEL_INPUT:-tool/fixtures/compare_replay_prompt_funnel_trace.json}"',
      ),
    );
  });

  test(
    'compare prompt instance IDs include evaluated time and session values',
    () {
      final homePage = File(
        'lib/src/features/home/home_page.dart',
      ).readAsStringSync();

      expect(
        homePage,
        contains(
          'final promptTimestampMs = DateTime.now().millisecondsSinceEpoch;',
        ),
      );
      expect(
        homePage,
        contains(r'''${statusKey}_${promptTimestampMs}_$promptSessionIndex'''),
      );
      expect(
        homePage,
        isNot(contains(r'''$DateTime.now().millisecondsSinceEpoch''')),
      );
    },
  );

  test('compare unit normalization fixture path is configurable in CI checks', () {
    final workflow = File(
      '.github/workflows/flutter-ci.yml',
    ).readAsStringSync();
    final localChecks = File('tool/ci_checks.sh').readAsStringSync();

    expect(
      workflow,
      contains(
        r'DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE="${DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE:-tool/fixtures/compare_unit_normalization_cases.json}"',
      ),
    );
    expect(
      workflow,
      contains(
        r'DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE: ${{ vars.DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE }}',
      ),
    );
    expect(
      workflow,
      contains(
        r'''DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE="$DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE" \''',
      ),
    );
    expect(
      localChecks,
      contains(
        r'compare_unit_normalization_fixture="${DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE:-tool/fixtures/compare_unit_normalization_cases.json}"',
      ),
    );
    expect(
      localChecks,
      contains(
        r'export DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE="$compare_unit_normalization_fixture"',
      ),
    );
  });

  test('compare unit smoke check honors override fixture path', () {
    final tmpDir = Directory.systemTemp.createTempSync(
      'dhc-compare-unit-fixture-override-',
    );
    try {
      final customFixture = File('${tmpDir.path}/custom_cases.json');
      customFixture.writeAsStringSync(
        jsonEncode({
          'normalizationCases': [
            {
              'label': 'custom_case',
              'amount': 2500,
              'unit': 'mcg',
              'expectedNormalizedUnit': 'g',
              'expectedCanonical': 'g',
              'expectedDenominator': '',
              'expectedScale': 0.000001,
            },
          ],
          'failureCases': [],
          'comparabilityCases': [
            {
              'label': 'custom_comparability',
              'leftUnit': 'mg',
              'rightUnit': 'g',
              'expectedComparable': true,
            },
          ],
        }),
      );

      final result = runDartToolWithEnv(
        ['tool/check_compare_unit_normalization.dart'],
        additionalEnv: {
          'CI': 'false',
          'DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE': customFixture.path,
        },
      );

      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(result.stdout.toString(), contains('PASS custom_case'));
      expect(
        result.stdout.toString(),
        contains('compare unit smoke check passed.'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test(
    'compare unit smoke check falls back when custom fixture path is missing',
    () {
      final customPath =
          '/tmp/does-not-exist-${DateTime.now().microsecondsSinceEpoch}.json';
      final result = runDartToolWithEnv(
        ['tool/check_compare_unit_normalization.dart'],
        additionalEnv: {
          'CI': 'false',
          'DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE': customPath,
        },
      );

      expect(result.exitCode, equals(0), reason: result.stderr.toString());
      expect(
        result.stderr.toString(),
        contains('Normalization fixture not found: $customPath'),
      );
      expect(
        result.stdout.toString(),
        contains('compare unit smoke check passed.'),
      );
    },
  );

  test(
    'compare unit smoke check falls back for malformed fixture payloads',
    () {
      final tmpDir = Directory.systemTemp.createTempSync(
        'dhc-compare-unit-fixture-malformed-',
      );
      try {
        final fixtures = <String, String>{
          'invalid-json': '{"normalizationCases": [',
          'invalid-entry': jsonEncode({
            'normalizationCases': ['not-an-object'],
            'failureCases': [],
            'comparabilityCases': [],
          }),
          'empty': jsonEncode({
            'normalizationCases': [],
            'failureCases': [],
            'comparabilityCases': [],
          }),
        };

        for (final fixture in fixtures.entries) {
          final customFixture = File('${tmpDir.path}/${fixture.key}.json')
            ..writeAsStringSync(fixture.value);
          final result = runDartToolWithEnv(
            ['tool/check_compare_unit_normalization.dart'],
            additionalEnv: {
              'CI': 'false',
              'DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE': customFixture.path,
            },
          );

          expect(
            result.exitCode,
            equals(0),
            reason: '${fixture.key}: ${result.stderr}',
          );
          expect(
            result.stderr.toString(),
            contains('normalization fixture at ${customFixture.path}'),
            reason: fixture.key,
          );
          expect(
            result.stderr.toString(),
            contains('using in-file defaults'),
            reason: fixture.key,
          );
          expect(
            result.stdout.toString(),
            contains('PASS mg_to_g'),
            reason: fixture.key,
          );
          expect(
            result.stdout.toString(),
            contains('compare unit smoke check passed.'),
            reason: fixture.key,
          );
        }
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    },
  );

  test('local CI wrapper preserves failures in strict mode', () {
    final localChecks = File('tool/ci_checks.sh').readAsStringSync();
    final flutterStepStart = localChecks.indexOf('run_flutter_step() {');
    final localDartStepStart = localChecks.indexOf('run_local_dart_check() {');
    final footerStart = localChecks.indexOf(
      "run_local_dart_check 'compare replay",
    );
    expect(flutterStepStart, greaterThanOrEqualTo(0));
    expect(localDartStepStart, greaterThan(flutterStepStart));
    expect(footerStart, greaterThan(localDartStepStart));
    final flutterStepBlock = localChecks.substring(
      flutterStepStart,
      localDartStepStart,
    );

    expect(
      localChecks,
      contains(
        r'DART_CHECKS_HOME="${DHC_DART_CHECKS_HOME:-/tmp/dhc_dart_checks_home}"',
      ),
    );
    expect(localChecks, contains(r'if [[ ! -x "$DART_BIN" ]]'));
    expect(
      localChecks,
      contains(r'Error: DART_BIN is not currently executable: %s'),
    );
    expect(
      localChecks,
      contains(r'Error: FLUTTER_BIN is not currently executable: %s'),
    );
    expect(localChecks, contains(r'exit 1'));
    expect(localChecks, contains(r'local exit_code=$?'));
    expect(
      localChecks,
      contains(r'''else
    local exit_code=$?'''),
    );
    expect(localChecks, contains(r'FLUTTER_BIN="${DHC_FLUTTER_BIN:-}"'));
    expect(
      localChecks,
      contains(r'if command -v flutter >/dev/null 2>&1; then'),
    );
    expect(localChecks, contains(r'if [[ -n "$FLUTTER_BIN" ]]; then'));
    expect(
      localChecks,
      contains(
        r'if [[ "$DART_BIN" == *"/bin/cache/dart-sdk/bin/dart" ]]; then',
      ),
    );
    expect(localChecks, contains(r'FLUTTER_CMD=()'));
    expect(localChecks, contains(r'return "$exit_code"'));
    expect(
      localChecks,
      isNot(
        contains(r'''fi

  local exit_code=$?'''),
      ),
    );
    expect(localChecks, contains('run_flutter_step()'));
    expect(localChecks, contains(r'DHC_FORCE_FLUTTER_CHECKS'));
    expect(flutterStepBlock, contains(r'DHC_FORCE_FLUTTER_CHECKS'));
    expect(flutterStepBlock, isNot(contains(r'DHC_FORCE_DART_CHECKS')));
    expect(localChecks, contains(r'DHC_FORCE_DART_CHECKS'));
  });

  test('ci_checks.sh fails fast when DART_BIN is misconfigured', () {
    final tmpRoot = Directory.systemTemp.createTempSync(
      'dhc-ci-checks-missing-dart',
    );
    final missingDart = '${tmpRoot.path}/dart';
    try {
      final workflowResult = Process.runSync(
        'bash',
        ['-lc', './tool/ci_checks.sh'],
        environment: {
          ...Platform.environment,
          'CI': 'false',
          'DHC_DART_BIN': missingDart,
          'DHC_FORCE_DART_CHECKS': 'true',
        },
        workingDirectory: '.',
      );

      expect(
        workflowResult.exitCode,
        equals(1),
        reason: workflowResult.stderr.toString(),
      );
      expect(
        workflowResult.stderr.toString(),
        contains('Error: DART_BIN is not currently executable: $missingDart'),
      );
    } finally {
      tmpRoot.deleteSync(recursive: true);
    }
  });

  test('ci_checks.sh fails fast in CI mode when DART_BIN is missing', () {
    final tmpRoot = Directory.systemTemp.createTempSync(
      'dhc-ci-checks-ci-missing-dart',
    );
    final missingDart = '${tmpRoot.path}/dart';
    try {
      final workflowResult = Process.runSync(
        'bash',
        ['-lc', './tool/ci_checks.sh'],
        environment: {
          ...Platform.environment,
          'CI': 'true',
          'DHC_DART_BIN': missingDart,
        },
        workingDirectory: '.',
      );

      expect(
        workflowResult.exitCode,
        equals(1),
        reason: workflowResult.stderr.toString(),
      );
      expect(
        workflowResult.stderr.toString(),
        contains('Error: DART_BIN is not currently executable: $missingDart'),
      );
    } finally {
      tmpRoot.deleteSync(recursive: true);
    }
  });

  test(
    'ci_checks.sh soft-skips missing flutter binary when not in strict mode',
    () {
      final tmpRoot = Directory.systemTemp.createTempSync(
        'dhc-ci-checks-nonstrict-soft-skip',
      );
      final stubDart = File('${tmpRoot.path}/dart');
      try {
        stubDart.writeAsStringSync('#!/usr/bin/env bash\nexit 0');
        final chmodResult = Process.runSync('chmod', ['+x', stubDart.path]);
        expect(
          chmodResult.exitCode,
          equals(0),
          reason: chmodResult.stderr.toString(),
        );
        final workflowResult = Process.runSync(
          'bash',
          ['-lc', './tool/ci_checks.sh'],
          environment: {
            ...Platform.environment,
            'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
            'CI': 'false',
            'DHC_DART_BIN': stubDart.path,
          },
          workingDirectory: '.',
        );

        expect(
          workflowResult.exitCode,
          equals(0),
          reason: workflowResult.stderr.toString(),
        );
        expect(
          workflowResult.stdout.toString(),
          contains('skipped in non-CI environment by policy'),
        );
      } finally {
        try {
          stubDart.deleteSync();
        } catch (_) {}
        tmpRoot.deleteSync(recursive: true);
      }
    },
  );

  test('ci_checks.sh fails fast when DART_BIN is not executable', () {
    final tmpRoot = Directory.systemTemp.createTempSync(
      'dhc-ci-checks-nonexec-dart',
    );
    final nonExecutableDart = '${tmpRoot.path}/not_exec';
    final stub = File(nonExecutableDart);
    try {
      stub.writeAsStringSync('just a file');
      final chmodResult = Process.runSync('chmod', ['-x', nonExecutableDart]);
      expect(
        chmodResult.exitCode,
        equals(0),
        reason: chmodResult.stderr.toString(),
      );

      final workflowResult = Process.runSync(
        'bash',
        ['-lc', './tool/ci_checks.sh'],
        environment: {
          ...Platform.environment,
          'CI': 'false',
          'DHC_DART_BIN': nonExecutableDart,
          'DHC_FORCE_DART_CHECKS': 'true',
        },
        workingDirectory: '.',
      );

      expect(
        workflowResult.exitCode,
        equals(1),
        reason: workflowResult.stderr.toString(),
      );
      expect(
        workflowResult.stderr.toString(),
        contains('Error: DART_BIN is not currently executable'),
      );
    } finally {
      try {
        stub.deleteSync();
      } catch (_) {}
      tmpRoot.deleteSync(recursive: true);
    }
  });

  test('ci_checks.sh fails fast when FLUTTER_BIN is misconfigured', () {
    final tmpRoot = Directory.systemTemp.createTempSync(
      'dhc-ci-checks-missing-flutter',
    );
    final missingFile = '${tmpRoot.path}/fake_dart';
    final missingFlutter = '${tmpRoot.path}/flutter';
    final fakeDart = File(missingFile);
    try {
      fakeDart.writeAsStringSync('#!/usr/bin/env bash\nexit 0');
      final chmodResult = Process.runSync('chmod', ['+x', missingFile]);
      expect(
        chmodResult.exitCode,
        equals(0),
        reason: chmodResult.stderr.toString(),
      );

      final workflowResult = Process.runSync(
        'bash',
        ['-lc', './tool/ci_checks.sh'],
        environment: {
          ...Platform.environment,
          'CI': 'false',
          'DHC_DART_BIN': missingFile,
          'DHC_FLUTTER_BIN': missingFlutter,
          'DHC_FORCE_FLUTTER_CHECKS': 'true',
        },
        workingDirectory: '.',
      );
      expect(
        workflowResult.exitCode,
        equals(1),
        reason: workflowResult.stderr.toString(),
      );
      expect(
        workflowResult.stderr.toString(),
        contains(
          'Error: FLUTTER_BIN is not currently executable: $missingFlutter',
        ),
      );
    } finally {
      try {
        fakeDart.deleteSync();
      } catch (_) {}
      tmpRoot.deleteSync(recursive: true);
    }
  });

  test('ci_checks.sh fails fast on flutter when CI mode is strict', () {
    final tmpRoot = Directory.systemTemp.createTempSync(
      'dhc-ci-checks-strict-flutter',
    );
    final fakeDart = File('${tmpRoot.path}/fake_dart');
    final missingFlutter = '${tmpRoot.path}/missing_flutter';
    try {
      fakeDart.writeAsStringSync('#!/usr/bin/env bash\nexit 0');
      final chmodResult = Process.runSync('chmod', ['+x', fakeDart.path]);
      expect(
        chmodResult.exitCode,
        equals(0),
        reason: chmodResult.stderr.toString(),
      );

      final workflowResult = Process.runSync(
        'bash',
        ['-lc', './tool/ci_checks.sh'],
        environment: {
          ...Platform.environment,
          'CI': 'true',
          'DHC_DART_BIN': fakeDart.path,
          'DHC_FLUTTER_BIN': missingFlutter,
          // strict flutter checks are implied by CI=true
        },
        workingDirectory: '.',
      );
      expect(
        workflowResult.exitCode,
        equals(1),
        reason: workflowResult.stderr.toString(),
      );
      expect(
        workflowResult.stderr.toString(),
        contains(
          'Error: FLUTTER_BIN is not currently executable: $missingFlutter',
        ),
      );
    } finally {
      try {
        fakeDart.deleteSync();
      } catch (_) {}
      tmpRoot.deleteSync(recursive: true);
    }
  });

  test('trend dashboard uses the recurrence window contract', () {
    final digest = File(
      'tool/build_compare_accessibility_trend_digest.dart',
    ).readAsStringSync();

    expect(
      digest,
      contains(
        "const String _envRecurrenceWindow = 'DHC_A11Y_TREND_RECURRENCE_WINDOW';",
      ),
    );
    expect(
      digest,
      isNot(
        contains(
          "const String _envRecurrenceWindow = 'DHC_A11Y_TREND_TREND_NOISE_WINDOW';",
        ),
      ),
    );
  });

  test('parser script advertises CLI help', () {
    final helpResult = runDartTool([
      'tool/parse_compare_accessibility_report.dart',
      '--help',
    ]);
    expect(
      helpResult.exitCode,
      equals(0),
      reason: helpResult.stderr.toString(),
    );
    expect(helpResult.stdout.toString(), contains('Usage:'));
    expect(helpResult.stdout.toString(), contains('--help'));

    final shortHelpResult = runDartTool([
      'tool/parse_compare_accessibility_report.dart',
      '-h',
    ]);
    expect(
      shortHelpResult.exitCode,
      equals(0),
      reason: shortHelpResult.stderr.toString(),
    );
    expect(shortHelpResult.stdout.toString(), contains('Usage:'));
  });

  test('parser script rejects malformed report file', () {
    final tmpDir = Directory.systemTemp.createTempSync('dhc-parse-invalid-');
    try {
      final missingSummaryFile = File('${tmpDir.path}/missing_summary.log')
        ..writeAsStringSync('not a parseable payload\n');
      final missingSummaryResult = runDartTool([
        'tool/parse_compare_accessibility_report.dart',
        missingSummaryFile.path,
      ]);
      expect(
        missingSummaryResult.exitCode,
        equals(1),
        reason: missingSummaryResult.stderr.toString(),
      );
      expect(
        missingSummaryResult.stderr.toString(),
        contains('compare replay accessibility summary json line is missing.'),
      );
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  });

  test('analyze and digest scripts provide CLI help', () {
    final analyzeHelpResult = runDartTool([
      'tool/analyze_compare_accessibility_trends.dart',
      '--help',
    ]);
    final analyzeHelpOutput =
        '${analyzeHelpResult.stdout}${analyzeHelpResult.stderr}';
    expect(
      analyzeHelpResult.exitCode,
      equals(0),
      reason: analyzeHelpResult.stderr.toString(),
    );
    expect(analyzeHelpOutput, contains('Usage:'));
    expect(analyzeHelpOutput, contains('--window-runs'));
    expect(analyzeHelpOutput, contains('--help'));

    final digestHelpResult = runDartTool([
      'tool/build_compare_accessibility_trend_digest.dart',
      '--help',
    ]);
    final digestHelpOutput =
        '${digestHelpResult.stdout}${digestHelpResult.stderr}';
    expect(
      digestHelpResult.exitCode,
      equals(0),
      reason: digestHelpResult.stderr.toString(),
    );
    expect(digestHelpOutput, contains('Usage:'));
  });

  test(
    'runDartTool falls back to AOT when dart emits build-hook failure text',
    () {
      final tmpDir = Directory.systemTemp.createTempSync(
        'dhc-run-dart-tool-fallback-',
      );
      try {
        final script = File('${tmpDir.path}/simulate_build_hook_failure.dart')
          ..writeAsStringSync('''
            import 'dart:io';

            void main() {
              stderr.writeln('Running build hooks failed');
              exit(1);
            }
          ''');

        final result = runDartTool([script.path]);
        expect(result.exitCode, equals(1), reason: result.stderr.toString());
        expect(
          result.stderr.toString(),
          contains('Running build hooks failed'),
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    },
  );
}
