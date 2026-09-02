#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

final _semver = RegExp(
  r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
  r'(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\+([1-9][0-9]*)$',
);

void main(List<String> args) {
  final options = _parseOptions(args);
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }
  if (options.error != null) {
    stderr.writeln(options.error);
    stderr.write(_usage);
    exit(2);
  }

  final root = Directory(options.rootPath).absolute;
  final failures = <String>[];
  final pubspec = _readFile(_join(root.path, 'pubspec.yaml'), failures);
  final packageName = pubspec == null
      ? null
      : _topLevelScalar(pubspec, 'name', failures);
  final version = pubspec == null
      ? null
      : _topLevelScalar(pubspec, 'version', failures);
  if (version != null && !_semver.hasMatch(version)) {
    failures.add(
      'pubspec.yaml version must be SemVer with a positive build number, '
      'got "$version".',
    );
  }
  if (options.requireRevision &&
      (options.revision == null || options.revision!.trim().isEmpty)) {
    failures.add(
      '--require-revision requires a non-empty --revision value so release '
      'evidence remains tied to a source commit.',
    );
  }

  final input = _resolvePath(root, options.inputPath!);
  final output = options.outputPath == null
      ? null
      : _resolvePath(root, options.outputPath!);
  final verify = options.verifyPath == null
      ? null
      : _resolvePath(root, options.verifyPath!);
  final inputDirectory = Directory(input);
  final containmentInput = _safeResolvePathForContainment(
    input,
    failures,
    'Artifact path',
  );
  final inputType = FileSystemEntity.typeSync(input, followLinks: false);
  if (inputType == FileSystemEntityType.notFound) {
    failures.add('Missing artifact directory: ${options.inputPath}.');
  } else if (inputType == FileSystemEntityType.link) {
    failures.add(
      'Artifact directory must be a regular directory, not a symlink: '
      '${options.inputPath}.',
    );
  } else if (inputType != FileSystemEntityType.directory ||
      !inputDirectory.existsSync()) {
    failures.add(
      'Artifact path must be a regular directory: ${options.inputPath}.',
    );
  }
  final containmentOutput = output == null
      ? null
      : _safeResolvePathForContainment(output, failures, 'Provenance output');
  if (output != null &&
      containmentInput != null &&
      containmentOutput != null &&
      _isWithin(containmentOutput, containmentInput)) {
    failures.add(
      'Provenance output must be outside the artifact directory, including '
      'symlink targets, so it cannot change the file set being hashed.',
    );
  }
  final containmentVerify = verify == null
      ? null
      : _safeResolvePathForContainment(
          verify,
          failures,
          'Provenance manifest to verify',
        );
  if (verify != null &&
      containmentInput != null &&
      containmentVerify != null &&
      _isWithin(containmentVerify, containmentInput)) {
    failures.add(
      'Provenance manifest to verify must be outside the artifact directory, '
      'including symlink targets, so it cannot change the file set being '
      'hashed.',
    );
  }
  if (options.requireWebVersion &&
      packageName != null &&
      version != null &&
      _semver.hasMatch(version)) {
    _checkWebVersionFile(input, packageName, version, failures);
  }
  if (options.requireWebShell) {
    _checkWebShell(input, failures);
  }
  if (options.requireWebManifest && packageName != null) {
    _checkWebManifest(input, packageName, failures);
  }
  if (options.requireWebManifestAssets) {
    _checkWebManifestAssets(input, failures);
  }
  if (options.requireWebShellReferences) {
    _checkWebShellReferences(input, failures);
  }
  if (options.requireWebRootBaseHref) {
    _checkWebRootBaseHref(input, failures);
  }
  if (options.requireWebMetadataParity) {
    _checkWebMetadataParity(root.path, input, failures);
  }
  if (options.requireWebPwaContract) {
    _checkWebPwaContract(input, failures);
  }
  if (options.requireWebPwaIdentity) {
    _checkWebPwaIdentity(root.path, input, failures);
  }
  if (options.requireWebViewport) {
    _checkWebViewport(root.path, input, failures);
  }
  if (options.requireWebLanguage) {
    _checkWebLanguage(root.path, input, failures);
  }
  if (options.requireWebTitleParity) {
    _checkWebTitleParity(root.path, input, failures);
  }
  if (options.requireWebManifestIconMetadata) {
    _checkWebManifestIconMetadata(input, failures);
  }
  if (options.requireWebThemeColorParity) {
    _checkWebThemeColorParity(root.path, input, failures);
  }
  if (options.requireWebServiceWorkerContract) {
    _checkWebServiceWorkerContract(input, failures);
  }

  if (failures.isNotEmpty) {
    _reportFailures(failures);
  }

  final files = <Map<String, Object>>[];
  var totalBytes = 0;
  final entities = inputDirectory.listSync(recursive: true, followLinks: false)
    ..sort((left, right) => left.path.compareTo(right.path));
  for (final entity in entities) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      failures.add(
        'Symlink is not allowed in a release artifact: ${entity.path}.',
      );
      continue;
    }
    if (type != FileSystemEntityType.file) {
      continue;
    }
    final bytes = File(entity.path).readAsBytesSync();
    final relativePath = _relativePath(input, entity.path);
    files.add({
      'path': relativePath,
      'bytes': bytes.length,
      'sha256': _sha256Hex(bytes),
    });
    totalBytes += bytes.length;
  }
  if (files.isEmpty) {
    failures.add('Artifact directory contains no regular files.');
  }
  if (failures.isNotEmpty) {
    _reportFailures(failures);
  }

  files.sort(
    (left, right) =>
        (left['path']! as String).compareTo(right['path']! as String),
  );
  final manifest = <String, Object>{
    'schemaVersion': '1.0.0',
    'artifact': options.artifactName!,
    'package': packageName!,
    'version': version!,
    'fileCount': files.length,
    'totalBytes': totalBytes,
    'files': files,
  };
  if (options.revision != null) {
    manifest['sourceRevision'] = options.revision!;
  }

  if (verify != null) {
    _verifyManifest(verify, manifest, failures);
  }
  if (failures.isNotEmpty) {
    _reportFailures(failures);
  }

  if (output != null) {
    final outputFile = File(output);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    stdout.writeln(
      'release provenance manifest written: ${_displayPath(output)} '
      '(files=${files.length}, bytes=$totalBytes)',
    );
  }
  if (verify != null) {
    stdout.writeln(
      'release provenance manifest verified: ${_displayPath(verify)} '
      '(files=${files.length}, bytes=$totalBytes)',
    );
  }
}

class _Options {
  const _Options({
    required this.rootPath,
    required this.inputPath,
    required this.outputPath,
    required this.verifyPath,
    required this.artifactName,
    required this.revision,
    required this.requireRevision,
    required this.requireWebVersion,
    required this.requireWebShell,
    required this.requireWebManifest,
    required this.requireWebManifestAssets,
    required this.requireWebShellReferences,
    required this.requireWebRootBaseHref,
    required this.requireWebMetadataParity,
    required this.requireWebPwaContract,
    required this.requireWebPwaIdentity,
    required this.requireWebViewport,
    required this.requireWebLanguage,
    required this.requireWebTitleParity,
    required this.requireWebManifestIconMetadata,
    required this.requireWebThemeColorParity,
    required this.requireWebServiceWorkerContract,
    required this.showHelp,
    required this.error,
  });

  final String rootPath;
  final String? inputPath;
  final String? outputPath;
  final String? verifyPath;
  final String? artifactName;
  final String? revision;
  final bool requireRevision;
  final bool requireWebVersion;
  final bool requireWebShell;
  final bool requireWebManifest;
  final bool requireWebManifestAssets;
  final bool requireWebShellReferences;
  final bool requireWebRootBaseHref;
  final bool requireWebMetadataParity;
  final bool requireWebPwaContract;
  final bool requireWebPwaIdentity;
  final bool requireWebViewport;
  final bool requireWebLanguage;
  final bool requireWebTitleParity;
  final bool requireWebManifestIconMetadata;
  final bool requireWebThemeColorParity;
  final bool requireWebServiceWorkerContract;
  final bool showHelp;
  final String? error;
}

_Options _parseOptions(List<String> args) {
  var rootPath = '.';
  String? inputPath;
  String? outputPath;
  String? verifyPath;
  String? artifactName;
  String? revision;
  var requireRevision = false;
  var requireWebVersion = false;
  var requireWebShell = false;
  var requireWebManifest = false;
  var requireWebManifestAssets = false;
  var requireWebShellReferences = false;
  var requireWebRootBaseHref = false;
  var requireWebMetadataParity = false;
  var requireWebPwaContract = false;
  var requireWebPwaIdentity = false;
  var requireWebViewport = false;
  var requireWebLanguage = false;
  var requireWebTitleParity = false;
  var requireWebManifestIconMetadata = false;
  var requireWebThemeColorParity = false;
  var requireWebServiceWorkerContract = false;

  String? requiredValue(String option, int index) {
    if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
      return '$option requires a value.';
    }
    return null;
  }

  for (var index = 0; index < args.length; index++) {
    switch (args[index]) {
      case '-h':
      case '--help':
        return const _Options(
          rootPath: '.',
          inputPath: null,
          outputPath: null,
          verifyPath: null,
          artifactName: null,
          revision: null,
          requireRevision: false,
          requireWebVersion: false,
          requireWebShell: false,
          requireWebManifest: false,
          requireWebManifestAssets: false,
          requireWebShellReferences: false,
          requireWebRootBaseHref: false,
          requireWebMetadataParity: false,
          requireWebPwaContract: false,
          requireWebPwaIdentity: false,
          requireWebViewport: false,
          requireWebLanguage: false,
          requireWebTitleParity: false,
          requireWebManifestIconMetadata: false,
          requireWebThemeColorParity: false,
          requireWebServiceWorkerContract: false,
          showHelp: true,
          error: null,
        );
      case '--root':
        final error = requiredValue('--root', index);
        if (error != null) return _errorOptions(error);
        rootPath = args[++index];
        break;
      case '--input':
        final error = requiredValue('--input', index);
        if (error != null) return _errorOptions(error);
        inputPath = args[++index];
        break;
      case '--output':
        final error = requiredValue('--output', index);
        if (error != null) return _errorOptions(error);
        outputPath = args[++index];
        break;
      case '--verify':
        final error = requiredValue('--verify', index);
        if (error != null) return _errorOptions(error);
        verifyPath = args[++index];
        break;
      case '--artifact-name':
        final error = requiredValue('--artifact-name', index);
        if (error != null) return _errorOptions(error);
        artifactName = args[++index];
        break;
      case '--revision':
        final error = requiredValue('--revision', index);
        if (error != null) return _errorOptions(error);
        revision = args[++index];
        break;
      case '--require-revision':
        requireRevision = true;
        break;
      case '--require-web-version':
        requireWebVersion = true;
        break;
      case '--require-web-shell':
        requireWebShell = true;
        break;
      case '--require-web-manifest':
        requireWebManifest = true;
        break;
      case '--require-web-manifest-assets':
        requireWebManifestAssets = true;
        break;
      case '--require-web-shell-references':
        requireWebShellReferences = true;
        break;
      case '--require-web-root-base-href':
        requireWebRootBaseHref = true;
        break;
      case '--require-web-metadata-parity':
        requireWebMetadataParity = true;
        break;
      case '--require-web-pwa-contract':
        requireWebPwaContract = true;
        break;
      case '--require-web-pwa-identity':
        requireWebPwaIdentity = true;
        break;
      case '--require-web-viewport':
        requireWebViewport = true;
        break;
      case '--require-web-language':
        requireWebLanguage = true;
        break;
      case '--require-web-title-parity':
        requireWebTitleParity = true;
        break;
      case '--require-web-manifest-icon-metadata':
        requireWebManifestIconMetadata = true;
        break;
      case '--require-web-theme-color-parity':
        requireWebThemeColorParity = true;
        break;
      case '--require-web-service-worker-contract':
        requireWebServiceWorkerContract = true;
        break;
      default:
        return _errorOptions('Unknown argument: ${args[index]}');
    }
  }

  if (inputPath == null) return _errorOptions('--input is required.');
  if (outputPath == null && verifyPath == null) {
    return _errorOptions('one of --output or --verify is required.');
  }
  if (artifactName == null || artifactName.trim().isEmpty) {
    artifactName = _basename(inputPath);
  }
  return _Options(
    rootPath: rootPath,
    inputPath: inputPath,
    outputPath: outputPath,
    verifyPath: verifyPath,
    artifactName: artifactName,
    revision: revision,
    requireRevision: requireRevision,
    requireWebVersion: requireWebVersion,
    requireWebShell: requireWebShell,
    requireWebManifest: requireWebManifest,
    requireWebManifestAssets: requireWebManifestAssets,
    requireWebShellReferences: requireWebShellReferences,
    requireWebRootBaseHref: requireWebRootBaseHref,
    requireWebMetadataParity: requireWebMetadataParity,
    requireWebPwaContract: requireWebPwaContract,
    requireWebPwaIdentity: requireWebPwaIdentity,
    requireWebViewport: requireWebViewport,
    requireWebLanguage: requireWebLanguage,
    requireWebTitleParity: requireWebTitleParity,
    requireWebManifestIconMetadata: requireWebManifestIconMetadata,
    requireWebThemeColorParity: requireWebThemeColorParity,
    requireWebServiceWorkerContract: requireWebServiceWorkerContract,
    showHelp: false,
    error: null,
  );
}

_Options _errorOptions(String message) {
  return _Options(
    rootPath: '.',
    inputPath: null,
    outputPath: null,
    verifyPath: null,
    artifactName: null,
    revision: null,
    requireRevision: false,
    requireWebVersion: false,
    requireWebShell: false,
    requireWebManifest: false,
    requireWebManifestAssets: false,
    requireWebShellReferences: false,
    requireWebRootBaseHref: false,
    requireWebMetadataParity: false,
    requireWebPwaContract: false,
    requireWebPwaIdentity: false,
    requireWebViewport: false,
    requireWebLanguage: false,
    requireWebTitleParity: false,
    requireWebManifestIconMetadata: false,
    requireWebThemeColorParity: false,
    requireWebServiceWorkerContract: false,
    showHelp: false,
    error: message,
  );
}

String? _readFile(String path, List<String> failures) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add('Missing required file: ${_displayPath(path)}.');
    return null;
  }
  return file.readAsStringSync();
}

void _checkWebShell(String input, List<String> failures) {
  const requiredFiles = [
    'index.html',
    'flutter_bootstrap.js',
    'main.dart.js',
    'manifest.json',
  ];
  for (final relativePath in requiredFiles) {
    final path = _join(input, relativePath);
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      failures.add(
        'Web artifact is missing required shell file "$relativePath".',
      );
    } else if (type != FileSystemEntityType.file) {
      failures.add(
        'Web artifact shell path "$relativePath" must be a regular file.',
      );
    }
  }
}

void _checkWebManifest(
  String input,
  String packageName,
  List<String> failures,
) {
  final path = _join(input, 'manifest.json');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing manifest.json required for Web identity.',
    );
    return;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('Web artifact manifest.json is not valid JSON: $error');
    return;
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact manifest.json: $error');
    return;
  }
  if (decoded is! Map) {
    failures.add('Web artifact manifest.json root must be a JSON object.');
    return;
  }

  final actual = Map<String, dynamic>.from(decoded);
  for (final key in const ['name', 'short_name']) {
    final actualValue = actual[key]?.toString();
    if (actualValue != packageName) {
      failures.add(
        'Web artifact manifest.json field "$key" differs from pubspec '
        'package metadata (expected=$packageName, actual=$actualValue).',
      );
    }
  }
}

void _checkWebManifestAssets(String input, List<String> failures) {
  final path = _join(input, 'manifest.json');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing manifest.json required for Web icon assets.',
    );
    return;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('Web artifact manifest.json is not valid JSON: $error');
    return;
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact manifest.json: $error');
    return;
  }
  if (decoded is! Map) {
    failures.add('Web artifact manifest.json root must be a JSON object.');
    return;
  }

  final icons = decoded['icons'];
  if (icons is! List || icons.isEmpty) {
    failures.add(
      'Web artifact manifest.json must declare a non-empty icons array for '
      'Web icon assets.',
    );
    return;
  }

  for (var index = 0; index < icons.length; index++) {
    final entry = icons[index];
    if (entry is! Map) {
      failures.add(
        'Web artifact manifest.json icons entry $index must be a JSON object.',
      );
      continue;
    }
    final sourceValue = entry['src'];
    if (sourceValue is! String || sourceValue.trim().isEmpty) {
      failures.add(
        'Web artifact manifest.json icons entry $index must contain a '
        'non-empty src.',
      );
      continue;
    }
    final source = sourceValue.trim();
    final normalized = source.replaceAll('\\', '/');
    Uri? uri;
    try {
      uri = Uri.parse(source);
    } on FormatException {
      // The path validation below reports the stable user-facing diagnostic.
    }
    final segments = normalized.split('/');
    if (normalized.startsWith('/') ||
        (uri?.isAbsolute ?? false) ||
        segments.contains('..')) {
      failures.add(
        'Web artifact manifest.json icon source "$source" must be a safe '
        'relative path inside the artifact.',
      );
      continue;
    }

    final iconPath = _join(input, normalized);
    final type = FileSystemEntity.typeSync(iconPath, followLinks: false);
    if (type != FileSystemEntityType.file) {
      failures.add(
        'Web artifact manifest.json icon source "$source" must resolve to '
        'a regular file.',
      );
    }
  }
}

void _checkWebPwaContract(String input, List<String> failures) {
  final path = _join(input, 'manifest.json');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing manifest.json required for the PWA contract.',
    );
    return;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('Web artifact manifest.json is not valid JSON: $error');
    return;
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact manifest.json: $error');
    return;
  }
  if (decoded is! Map) {
    failures.add('Web artifact manifest.json root must be a JSON object.');
    return;
  }

  final startUrlValue = decoded['start_url'];
  if (startUrlValue is! String || startUrlValue.trim().isEmpty) {
    failures.add(
      'Web artifact manifest.json start_url must be a non-empty relative '
      'path for the PWA contract.',
    );
  } else {
    final startUrl = startUrlValue.trim();
    final normalized = startUrl.replaceAll('\\', '/');
    Uri? uri;
    try {
      uri = Uri.parse(startUrl);
    } on FormatException {
      // The path validation below reports the stable user-facing diagnostic.
    }
    if (normalized.startsWith('/') ||
        (uri?.isAbsolute ?? false) ||
        normalized.split('/').contains('..')) {
      failures.add(
        'Web artifact manifest.json start_url "$startUrl" must be a safe '
        'relative path inside the deployed app.',
      );
    }
  }

  const allowedDisplays = [
    'browser',
    'fullscreen',
    'minimal-ui',
    'standalone',
    'window-controls-overlay',
  ];
  final displayValue = decoded['display'];
  if (displayValue is! String ||
      !allowedDisplays.contains(displayValue.trim().toLowerCase())) {
    failures.add(
      'Web artifact manifest.json display must be one of '
      '${allowedDisplays.join(', ')}.',
    );
  }

  for (final key in const ['background_color', 'theme_color']) {
    final value = decoded[key];
    if (value is! String || value.trim().isEmpty) {
      failures.add(
        'Web artifact manifest.json $key must be a non-empty color value.',
      );
    }
  }
}

void _checkWebPwaIdentity(String root, String input, List<String> failures) {
  final sourceManifest = File(_join(_join(root, 'web'), 'manifest.json'));
  final artifactManifest = File(_join(input, 'manifest.json'));
  for (final field in const ['id', 'scope']) {
    final canonical = _readManifestStringField(
      sourceManifest,
      'Canonical web/manifest.json',
      field,
      failures,
    );
    if (canonical != null && canonical != '/') {
      failures.add(
        'Canonical web/manifest.json $field must be exactly "/" for the '
        'root PWA identity contract (got "$canonical").',
      );
    }

    final artifact = _readManifestStringField(
      artifactManifest,
      'Web artifact manifest.json',
      field,
      failures,
    );
    if (artifact != null && artifact != '/') {
      failures.add(
        'Web artifact manifest.json $field must be exactly "/" for the root '
        'PWA identity contract (got "$artifact").',
      );
    }
    if (canonical != null && artifact != null && canonical != artifact) {
      failures.add(
        'Web artifact manifest.json $field differs from canonical '
        'web/manifest.json (expected="$canonical", actual="$artifact").',
      );
    }
  }
}

void _checkWebViewport(String root, String input, List<String> failures) {
  const expected = 'width=device-width, initial-scale=1.0';
  final sourcePath = _join(_join(root, 'web'), 'index.html');
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    failures.add('Canonical web/index.html is required for the Web viewport.');
    return;
  }
  String sourceHtml;
  try {
    sourceHtml = sourceFile.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read canonical web/index.html: $error');
    return;
  }
  final sourceValues = _htmlMetaNamedValues(sourceHtml, 'viewport');
  if (sourceValues.length != 1 || sourceValues.single != expected) {
    failures.add(
      'Canonical web/index.html must contain exactly one viewport meta '
      'value "$expected".',
    );
    return;
  }

  final artifactPath = _join(input, 'index.html');
  final artifactFile = File(artifactPath);
  if (!artifactFile.existsSync()) {
    failures.add('Web artifact index.html is required for the Web viewport.');
    return;
  }
  String artifactHtml;
  try {
    artifactHtml = artifactFile.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact index.html: $error');
    return;
  }
  final artifactValues = _htmlMetaNamedValues(artifactHtml, 'viewport');
  if (artifactValues.length != 1 || artifactValues.single != expected) {
    failures.add(
      'Web artifact index.html viewport meta must equal canonical value '
      '"$expected" (found ${artifactValues.length} value(s)).',
    );
  }
}

void _checkWebLanguage(String root, String input, List<String> failures) {
  String? readLanguage(String path, String label) {
    final file = File(path);
    if (!file.existsSync()) {
      failures.add('$label is required for the Web language contract.');
      return null;
    }
    String html;
    try {
      html = file.readAsStringSync();
    } on FileSystemException catch (error) {
      failures.add('Unable to read $label: $error');
      return null;
    }
    final htmlTags = RegExp(
      r'<html\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html).map((match) => match.group(0)!).toList(growable: false);
    if (htmlTags.length != 1) {
      failures.add(
        '$label must contain exactly one html tag for the Web language '
        'contract.',
      );
      return null;
    }
    final language = _htmlAttribute(htmlTags.single, 'lang')?.trim();
    if (language == null || language.toLowerCase() != 'en') {
      failures.add(
        '$label html lang must be exactly "en" for the Web language contract '
        '(got "${language ?? ''}").',
      );
      return null;
    }
    return language.toLowerCase();
  }

  final canonical = readLanguage(
    _join(_join(root, 'web'), 'index.html'),
    'Canonical web/index.html',
  );
  final artifact = readLanguage(
    _join(input, 'index.html'),
    'Web artifact index.html',
  );
  if (canonical != null && artifact != null && canonical != artifact) {
    failures.add(
      'Web artifact index.html html lang differs from canonical web/index.html '
      '(expected="$canonical", actual="$artifact").',
    );
  }
}

void _checkWebTitleParity(String root, String input, List<String> failures) {
  String? readTitle(String path, String label) {
    final file = File(path);
    if (!file.existsSync()) {
      failures.add('$label is required for Web title parity.');
      return null;
    }
    String html;
    try {
      html = file.readAsStringSync();
    } on FileSystemException catch (error) {
      failures.add('Unable to read $label: $error');
      return null;
    }
    final titles = RegExp(
      r'<title\b[^>]*>(.*?)</title\s*>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html).map((match) => match.group(1)!.trim()).toList();
    if (titles.length != 1 || titles.single.isEmpty) {
      failures.add(
        '$label must contain exactly one non-empty <title> for Web title '
        'parity (found ${titles.length} value(s)).',
      );
      return null;
    }
    return titles.single;
  }

  final canonical = readTitle(
    _join(_join(root, 'web'), 'index.html'),
    'Canonical web/index.html',
  );
  final artifact = readTitle(
    _join(input, 'index.html'),
    'Web artifact index.html',
  );
  if (canonical != null && artifact != null && canonical != artifact) {
    failures.add(
      'Web artifact index.html title differs from canonical web/index.html '
      '(expected="$canonical", actual="$artifact").',
    );
  }
}

void _checkWebManifestIconMetadata(String input, List<String> failures) {
  final path = _join(input, 'manifest.json');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing manifest.json required for icon metadata.',
    );
    return;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('Web artifact manifest.json is not valid JSON: $error');
    return;
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact manifest.json: $error');
    return;
  }
  if (decoded is! Map) {
    failures.add('Web artifact manifest.json root must be a JSON object.');
    return;
  }

  final icons = decoded['icons'];
  if (icons is! List || icons.isEmpty) {
    failures.add(
      'Web artifact manifest.json must declare a non-empty icons array for '
      'icon metadata.',
    );
    return;
  }

  const allowedTypes = {
    'image/avif',
    'image/gif',
    'image/jpeg',
    'image/png',
    'image/svg+xml',
    'image/webp',
  };
  const allowedPurposes = {'any', 'maskable', 'monochrome'};
  final sizePattern = RegExp(
    r'^(?:any|[1-9][0-9]*x[1-9][0-9]*)$',
    caseSensitive: false,
  );
  for (var index = 0; index < icons.length; index++) {
    final entry = icons[index];
    if (entry is! Map) {
      failures.add(
        'Web artifact manifest.json icons entry $index must be a JSON object.',
      );
      continue;
    }

    final sizes = entry['sizes'];
    if (sizes is! String ||
        sizes.trim().isEmpty ||
        sizes
            .trim()
            .split(RegExp(r'\s+'))
            .any((value) => !sizePattern.hasMatch(value))) {
      failures.add(
        'Web artifact manifest.json icons entry $index sizes must contain '
        'positive WIDTHxHEIGHT values or "any".',
      );
    }

    final type = entry['type'];
    if (type is! String || !allowedTypes.contains(type.trim().toLowerCase())) {
      failures.add(
        'Web artifact manifest.json icons entry $index type must be a '
        'supported image MIME type.',
      );
    }

    final purpose = entry['purpose'];
    if (purpose != null) {
      if (purpose is! String ||
          purpose.trim().isEmpty ||
          purpose
              .trim()
              .split(RegExp(r'\s+'))
              .any((value) => !allowedPurposes.contains(value.toLowerCase()))) {
        failures.add(
          'Web artifact manifest.json icons entry $index purpose must use '
          'only any, maskable, or monochrome.',
        );
      }
    }
  }
}

void _checkWebThemeColorParity(
  String root,
  String input,
  List<String> failures,
) {
  final sourceIndexFile = File(_join(_join(root, 'web'), 'index.html'));
  if (!sourceIndexFile.existsSync()) {
    failures.add(
      'Canonical web/index.html is required for theme-color parity.',
    );
    return;
  }
  String sourceHtml;
  try {
    sourceHtml = sourceIndexFile.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read canonical web/index.html: $error');
    return;
  }
  final sourceValues = _htmlMetaNamedValues(sourceHtml, 'theme-color');
  if (sourceValues.length != 1 || sourceValues.single.isEmpty) {
    failures.add(
      'Canonical web/index.html must contain exactly one non-empty theme-color '
      'meta value.',
    );
    return;
  }
  final canonicalColor = sourceValues.single;

  final canonicalManifestColor = _readManifestStringField(
    File(_join(_join(root, 'web'), 'manifest.json')),
    'Canonical web/manifest.json',
    'theme_color',
    failures,
  );
  if (canonicalManifestColor == null) return;
  if (canonicalManifestColor != canonicalColor) {
    failures.add(
      'Canonical web/manifest.json theme_color differs from canonical '
      'web/index.html theme-color meta value.',
    );
    return;
  }

  final artifactIndexFile = File(_join(input, 'index.html'));
  if (!artifactIndexFile.existsSync()) {
    failures.add('Web artifact index.html is required for theme-color parity.');
    return;
  }
  String artifactHtml;
  try {
    artifactHtml = artifactIndexFile.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact index.html: $error');
    return;
  }
  final artifactValues = _htmlMetaNamedValues(artifactHtml, 'theme-color');
  if (artifactValues.length != 1 || artifactValues.single.isEmpty) {
    failures.add(
      'Web artifact index.html must contain exactly one non-empty theme-color '
      'meta value.',
    );
    return;
  }
  final artifactColor = artifactValues.single;
  if (artifactColor != canonicalColor) {
    failures.add(
      'Web artifact index.html theme-color differs from canonical '
      'web/index.html (expected="$canonicalColor", actual="$artifactColor").',
    );
  }

  final artifactManifestColor = _readManifestStringField(
    File(_join(input, 'manifest.json')),
    'Web artifact manifest.json',
    'theme_color',
    failures,
  );
  if (artifactManifestColor == null) return;
  if (artifactManifestColor != canonicalColor) {
    failures.add(
      'Web artifact manifest.json theme_color differs from canonical '
      'web/index.html theme-color meta value.',
    );
  }
}

void _checkWebServiceWorkerContract(String input, List<String> failures) {
  final bootstrapPath = _join(input, 'flutter_bootstrap.js');
  final bootstrapType = FileSystemEntity.typeSync(
    bootstrapPath,
    followLinks: false,
  );
  if (bootstrapType != FileSystemEntityType.file) {
    failures.add(
      'Web artifact flutter_bootstrap.js must be a regular file for the '
      'service-worker contract.',
    );
  }

  final workerPath = _join(input, 'flutter_service_worker.js');
  final workerType = FileSystemEntity.typeSync(workerPath, followLinks: false);
  if (workerType != FileSystemEntityType.file) {
    failures.add(
      'Web artifact flutter_service_worker.js must be a regular file for the '
      'service-worker contract.',
    );
  }
  if (bootstrapType != FileSystemEntityType.file ||
      workerType != FileSystemEntityType.file) {
    return;
  }

  String bootstrap;
  try {
    bootstrap = File(bootstrapPath).readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact flutter_bootstrap.js: $error');
    return;
  }
  final versions = RegExp(
    r'''\bserviceWorkerVersion\s*:\s*["']([^"']*)["']''',
  ).allMatches(bootstrap).map((match) => match.group(1)!.trim()).toList();
  if (versions.length != 1 || versions.single.isEmpty) {
    failures.add(
      'Web artifact flutter_bootstrap.js must contain exactly one non-empty '
      'serviceWorkerVersion for cache-busting registration.',
    );
  } else if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(versions.single)) {
    failures.add(
      'Web artifact serviceWorkerVersion "${versions.single}" must be a '
      'safe cache-busting token.',
    );
  }

  String worker;
  try {
    worker = File(workerPath).readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add(
      'Unable to read Web artifact flutter_service_worker.js: $error',
    );
    return;
  }
  if (!RegExp(
    r'''addEventListener\s*\(\s*["']install["']''',
    caseSensitive: false,
  ).hasMatch(worker)) {
    failures.add(
      'Web artifact flutter_service_worker.js must handle install to make '
      'the worker lifecycle explicit.',
    );
  }
  if (!RegExp(
    r'\bself\.skipWaiting\s*\(',
    caseSensitive: false,
  ).hasMatch(worker)) {
    failures.add(
      'Web artifact flutter_service_worker.js must call self.skipWaiting() '
      'during install.',
    );
  }
  if (!RegExp(
    r'''addEventListener\s*\(\s*["']activate["']''',
    caseSensitive: false,
  ).hasMatch(worker)) {
    failures.add(
      'Web artifact flutter_service_worker.js must handle activate to make '
      'the worker lifecycle explicit.',
    );
  }
  if (!RegExp(
    r'\bself\.registration\.unregister\s*\(',
    caseSensitive: false,
  ).hasMatch(worker)) {
    failures.add(
      'Web artifact flutter_service_worker.js must unregister itself so the '
      'deprecated worker cannot retain stale caches.',
    );
  }
  if (RegExp(r'\bcaches\s*\.', caseSensitive: false).hasMatch(worker)) {
    failures.add(
      'Web artifact flutter_service_worker.js must not access CacheStorage; '
      'this release uses a cleanup-only worker policy.',
    );
  }
  if (RegExp(
    r'''addEventListener\s*\(\s*["']fetch["']''',
    caseSensitive: false,
  ).hasMatch(worker)) {
    failures.add(
      'Web artifact flutter_service_worker.js must not intercept fetch '
      'requests under the cleanup-only worker policy.',
    );
  }
}

void _checkWebShellReferences(String input, List<String> failures) {
  final path = _join(input, 'index.html');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing index.html required for shell references.',
    );
    return;
  }

  String html;
  try {
    html = file.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact index.html: $error');
    return;
  }

  final scriptTags = RegExp(
    r'<script\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html).map((match) => match.group(0)!).toList(growable: false);
  final linkTags = RegExp(
    r'<link\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html).map((match) => match.group(0)!).toList(growable: false);

  final hasBootstrap = scriptTags.any(
    (tag) => _htmlAttribute(tag, 'src') == 'flutter_bootstrap.js',
  );
  if (!hasBootstrap) {
    failures.add(
      'Web artifact index.html must reference flutter_bootstrap.js from a '
      'script tag.',
    );
  } else {
    _checkWebReferencePath(
      input,
      'flutter_bootstrap.js',
      'Web artifact bootstrap script',
      failures,
    );
  }

  final hasManifest = linkTags.any(
    (tag) =>
        _htmlAttribute(tag, 'href') == 'manifest.json' &&
        _hasHtmlRelToken(_htmlAttribute(tag, 'rel'), 'manifest'),
  );
  if (!hasManifest) {
    failures.add(
      'Web artifact index.html must reference manifest.json with a manifest '
      'link.',
    );
  } else {
    _checkWebReferencePath(
      input,
      'manifest.json',
      'Web artifact manifest link',
      failures,
    );
  }

  final hasFavicon = linkTags.any(
    (tag) =>
        _htmlAttribute(tag, 'href') == 'favicon.png' &&
        _hasHtmlRelToken(_htmlAttribute(tag, 'rel'), 'icon'),
  );
  if (!hasFavicon) {
    failures.add(
      'Web artifact index.html must reference favicon.png with an icon link.',
    );
  } else {
    _checkWebReferencePath(
      input,
      'favicon.png',
      'Web artifact favicon link',
      failures,
    );
  }

  final hasAppleTouchIcon = linkTags.any(
    (tag) =>
        _htmlAttribute(tag, 'href') == 'icons/Icon-192.png' &&
        _hasHtmlRelToken(_htmlAttribute(tag, 'rel'), 'apple-touch-icon'),
  );
  if (!hasAppleTouchIcon) {
    failures.add(
      'Web artifact index.html must reference icons/Icon-192.png with an '
      'apple-touch-icon link.',
    );
  } else {
    _checkWebReferencePath(
      input,
      'icons/Icon-192.png',
      'Web artifact Apple touch icon link',
      failures,
    );
  }
}

void _checkWebRootBaseHref(String input, List<String> failures) {
  final path = _join(input, 'index.html');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing index.html required for the root base-href '
      'contract.',
    );
    return;
  }

  String html;
  try {
    html = file.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact index.html: $error');
    return;
  }
  final baseTags = RegExp(
    r'<base\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html).map((match) => match.group(0)!).toList(growable: false);
  if (baseTags.length != 1) {
    failures.add(
      'Web artifact index.html must contain exactly one base tag for the '
      'root base-href contract.',
    );
    return;
  }
  final baseHref = _htmlAttribute(baseTags.single, 'href')?.trim();
  if (baseHref != '/') {
    failures.add(
      'Web artifact index.html base href must be exactly "/" for the '
      'root deployment contract (got "${baseHref ?? ''}").',
    );
  }
}

void _checkWebMetadataParity(String root, String input, List<String> failures) {
  final sourceIndexPath = _join(_join(root, 'web'), 'index.html');
  final sourceIndex = File(sourceIndexPath);
  if (!sourceIndex.existsSync()) {
    failures.add(
      'Canonical web/index.html is required for Web metadata parity.',
    );
    return;
  }

  String sourceHtml;
  try {
    sourceHtml = sourceIndex.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read canonical web/index.html: $error');
    return;
  }
  final sourceIndexDescriptions = _htmlMetaDescriptionValues(sourceHtml);
  if (sourceIndexDescriptions.length != 1 ||
      sourceIndexDescriptions.single.isEmpty) {
    failures.add(
      'Canonical web/index.html must contain exactly one non-empty meta '
      'description for Web metadata parity.',
    );
    return;
  }
  final canonicalDescription = sourceIndexDescriptions.single;

  final sourceManifestPath = _join(_join(root, 'web'), 'manifest.json');
  final canonicalManifestDescription = _readManifestDescription(
    File(sourceManifestPath),
    'Canonical web/manifest.json',
    failures,
  );
  if (canonicalManifestDescription == null) return;
  if (canonicalManifestDescription != canonicalDescription) {
    failures.add(
      'Canonical web/manifest.json description differs from canonical '
      'web/index.html meta description.',
    );
    return;
  }

  final artifactIndexPath = _join(input, 'index.html');
  final artifactIndex = File(artifactIndexPath);
  if (!artifactIndex.existsSync()) {
    failures.add(
      'Web artifact index.html is required for Web metadata parity.',
    );
    return;
  }
  String artifactHtml;
  try {
    artifactHtml = artifactIndex.readAsStringSync();
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact index.html: $error');
    return;
  }
  final artifactDescriptions = _htmlMetaDescriptionValues(artifactHtml);
  if (artifactDescriptions.length != 1 || artifactDescriptions.single.isEmpty) {
    failures.add(
      'Web artifact index.html must contain exactly one non-empty meta '
      'description for Web metadata parity.',
    );
    return;
  }
  final artifactDescription = artifactDescriptions.single;
  if (artifactDescription != canonicalDescription) {
    failures.add(
      'Web artifact index.html meta description differs from canonical '
      'web/index.html (expected="$canonicalDescription", '
      'actual="$artifactDescription").',
    );
  }

  final artifactManifestDescription = _readManifestDescription(
    File(_join(input, 'manifest.json')),
    'Web artifact manifest.json',
    failures,
  );
  if (artifactManifestDescription == null) return;
  if (artifactManifestDescription != canonicalDescription) {
    failures.add(
      'Web artifact manifest.json description differs from canonical '
      'web/index.html meta description.',
    );
  }
}

List<String> _htmlMetaDescriptionValues(String html) {
  return _htmlMetaNamedValues(html, 'description');
}

List<String> _htmlMetaNamedValues(String html, String name) {
  final tags = RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html).map((match) => match.group(0)!).toList(growable: false);
  return tags
      .where(
        (tag) =>
            _htmlAttribute(tag, 'name')?.trim().toLowerCase() ==
            name.toLowerCase(),
      )
      .map((tag) => _htmlAttribute(tag, 'content')?.trim() ?? '')
      .toList(growable: false);
}

String? _readManifestDescription(
  File file,
  String label,
  List<String> failures,
) {
  return _readManifestStringField(file, label, 'description', failures);
}

String? _readManifestStringField(
  File file,
  String label,
  String field,
  List<String> failures,
) {
  if (!file.existsSync()) {
    failures.add('$label is required for Web metadata parity.');
    return null;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('$label is not valid JSON: $error');
    return null;
  } on FileSystemException catch (error) {
    failures.add('Unable to read $label: $error');
    return null;
  }
  if (decoded is! Map) {
    failures.add('$label root must be a JSON object.');
    return null;
  }
  final value = decoded[field];
  if (value is! String || value.trim().isEmpty) {
    failures.add('$label must contain a non-empty $field.');
    return null;
  }
  return value.trim();
}

String? _htmlAttribute(String tag, String attribute) {
  final pattern = RegExp(
    RegExp.escape(attribute) + r'''\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(tag);
  return match?.group(1) ?? match?.group(2);
}

bool _hasHtmlRelToken(String? value, String expected) {
  if (value == null) return false;
  return value
      .split(RegExp(r'\s+'))
      .any((token) => token.toLowerCase() == expected.toLowerCase());
}

void _checkWebReferencePath(
  String input,
  String source,
  String label,
  List<String> failures,
) {
  final normalized = source.replaceAll('\\', '/');
  Uri? uri;
  try {
    uri = Uri.parse(source);
  } on FormatException {
    // The path validation below reports the stable user-facing diagnostic.
  }
  if (normalized.startsWith('/') ||
      (uri?.isAbsolute ?? false) ||
      normalized.split('/').contains('..')) {
    failures.add(
      '$label "$source" must be a safe relative path inside the artifact.',
    );
    return;
  }

  final referencePath = _join(input, normalized);
  final type = FileSystemEntity.typeSync(referencePath, followLinks: false);
  if (type != FileSystemEntityType.file) {
    failures.add('$label "$source" must resolve to a regular file.');
  }
}

void _checkWebVersionFile(
  String input,
  String packageName,
  String version,
  List<String> failures,
) {
  final path = _join(input, 'version.json');
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Web artifact is missing version.json required for release provenance.',
    );
    return;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('Web artifact version.json is not valid JSON: $error');
    return;
  } on FileSystemException catch (error) {
    failures.add('Unable to read Web artifact version.json: $error');
    return;
  }
  if (decoded is! Map) {
    failures.add('Web artifact version.json root must be a JSON object.');
    return;
  }

  final actual = Map<String, dynamic>.from(decoded);
  final versionParts = version.split('+');
  final expected = <String, String>{
    'app_name': packageName,
    'package_name': packageName,
    'version': versionParts.first,
    'build_number': versionParts.last,
  };
  for (final entry in expected.entries) {
    final actualValue = actual[entry.key]?.toString();
    if (actualValue != entry.value) {
      failures.add(
        'Web artifact version.json field "${entry.key}" differs from '
        'pubspec metadata (expected=${entry.value}, actual=$actualValue).',
      );
    }
  }
}

String? _topLevelScalar(String contents, String key, List<String> failures) {
  final pattern = RegExp(
    '^${RegExp.escape(key)}:\\s*(.*?)\\s*\$',
    multiLine: true,
  );
  final matches = pattern
      .allMatches(contents)
      .map((match) => _unquote(match.group(1)!))
      .toList(growable: false);
  if (matches.length != 1 || matches.first.isEmpty) {
    failures.add(
      'pubspec.yaml must contain exactly one non-empty top-level $key field.',
    );
    return null;
  }
  return matches.first;
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith("'") && value.endsWith("'")) ||
          (value.startsWith('"') && value.endsWith('"')))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

String _resolvePath(Directory root, String path) {
  if (Directory(path).isAbsolute) return Directory(path).absolute.path;
  return _join(root.path, path);
}

String _resolvePathForContainment(String path) {
  final absolute = Directory(path).absolute.path;
  final type = FileSystemEntity.typeSync(absolute, followLinks: false);
  if (type != FileSystemEntityType.notFound) {
    return switch (type) {
      FileSystemEntityType.directory => Directory(
        absolute,
      ).resolveSymbolicLinksSync(),
      FileSystemEntityType.file => File(absolute).resolveSymbolicLinksSync(),
      FileSystemEntityType.link => Link(absolute).resolveSymbolicLinksSync(),
      _ => absolute,
    };
  }

  final parent = Directory(absolute).parent.path;
  if (parent == absolute) {
    return absolute;
  }
  return _join(_resolvePathForContainment(parent), _basename(absolute));
}

String? _safeResolvePathForContainment(
  String path,
  List<String> failures,
  String label,
) {
  try {
    return _resolvePathForContainment(path);
  } on FileSystemException catch (error) {
    failures.add('$label could not be resolved safely: $error.');
    return null;
  }
}

bool _isWithin(String candidate, String parent) {
  final separator = Platform.pathSeparator;
  final normalizedParent = parent.endsWith(separator)
      ? parent.substring(0, parent.length - 1)
      : parent;
  return candidate == normalizedParent ||
      candidate.startsWith('$normalizedParent$separator');
}

String _relativePath(String root, String path) {
  final separator = Platform.pathSeparator;
  final prefix = root.endsWith(separator) ? root : '$root$separator';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length).replaceAll(separator, '/');
  }
  return path.replaceAll(separator, '/');
}

String _join(String root, String relative) {
  return '$root${Platform.pathSeparator}$relative';
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/')..removeWhere((part) => part.isEmpty);
  return parts.isEmpty ? 'artifact' : parts.last;
}

String _displayPath(String path) {
  final current = Directory.current.absolute.path;
  final prefix = '$current${Platform.pathSeparator}';
  if (path.startsWith(prefix)) return path.substring(prefix.length);
  return path;
}

void _verifyManifest(
  String path,
  Map<String, Object> expected,
  List<String> failures,
) {
  final file = File(path);
  if (!file.existsSync()) {
    failures.add(
      'Missing provenance manifest to verify: ${_displayPath(path)}.',
    );
    return;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    failures.add('Provenance manifest is not valid JSON: $error');
    return;
  } on FileSystemException catch (error) {
    failures.add('Unable to read provenance manifest: $error');
    return;
  }
  if (decoded is! Map) {
    failures.add('Provenance manifest root must be a JSON object.');
    return;
  }
  final actual = Map<String, dynamic>.from(decoded);
  final expectedKeys = <String>{
    'schemaVersion',
    'artifact',
    'package',
    'version',
    'fileCount',
    'totalBytes',
    'files',
    if (expected.containsKey('sourceRevision')) 'sourceRevision',
  };
  if (actual.length != expectedKeys.length ||
      !actual.keys.every(expectedKeys.contains)) {
    failures.add(
      'Provenance manifest root fields must exactly match the generated '
      'schema (expected=${expectedKeys.toList()}).',
    );
  }
  for (final key in const [
    'schemaVersion',
    'artifact',
    'package',
    'version',
    'fileCount',
    'totalBytes',
  ]) {
    if (actual[key] != expected[key]) {
      failures.add(
        'Provenance manifest field "$key" differs from the artifact '
        'snapshot (expected=${expected[key]}, actual=${actual[key]}).',
      );
    }
  }

  final expectedFiles = expected['files'] as List<Map<String, Object>>;
  final actualFiles = actual['files'];
  if (actualFiles is! List) {
    failures.add('Provenance manifest files must be a JSON array.');
  } else if (actualFiles.length != expectedFiles.length) {
    failures.add(
      'Provenance manifest file count differs from the artifact snapshot '
      '(expected=${expectedFiles.length}, actual=${actualFiles.length}).',
    );
  } else {
    for (var index = 0; index < expectedFiles.length; index++) {
      final actualFile = actualFiles[index];
      final expectedFile = expectedFiles[index];
      if (actualFile is! Map) {
        failures.add('Provenance manifest entry $index is not a JSON object.');
        continue;
      }
      const expectedFileKeys = {'path', 'bytes', 'sha256'};
      if (actualFile.length != expectedFileKeys.length ||
          !actualFile.keys.every(expectedFileKeys.contains)) {
        failures.add(
          'Provenance manifest entry $index fields must exactly match the '
          'generated file schema.',
        );
      }
      for (final key in const ['path', 'bytes', 'sha256']) {
        if (actualFile[key] != expectedFile[key]) {
          failures.add(
            'Provenance manifest entry $index field "$key" differs '
            '(expected=${expectedFile[key]}, actual=${actualFile[key]}).',
          );
        }
      }
    }
  }
  if (expected.containsKey('sourceRevision') &&
      actual['sourceRevision'] != expected['sourceRevision']) {
    failures.add(
      'Provenance manifest sourceRevision differs '
      '(expected=${expected['sourceRevision']}, '
      'actual=${actual['sourceRevision']}).',
    );
  }
}

String _sha256Hex(List<int> input) {
  const mask = 0xffffffff;
  const initial = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  const roundConstants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  final padded = <int>[...input, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  final bitLength = input.length * 8;
  for (var shift = 56; shift >= 0; shift -= 8) {
    padded.add((bitLength >> shift) & 0xff);
  }

  final hash = [...initial];
  int rotateRight(int value, int bits) {
    return ((value >> bits) | (value << (32 - bits))) & mask;
  }

  for (var offset = 0; offset < padded.length; offset += 64) {
    final words = List<int>.filled(64, 0);
    for (var index = 0; index < 16; index++) {
      final base = offset + index * 4;
      words[index] =
          ((padded[base] << 24) |
              (padded[base + 1] << 16) |
              (padded[base + 2] << 8) |
              padded[base + 3]) &
          mask;
    }
    for (var index = 16; index < 64; index++) {
      final value15 = words[index - 15];
      final value2 = words[index - 2];
      final small0 =
          rotateRight(value15, 7) ^ rotateRight(value15, 18) ^ (value15 >> 3);
      final small1 =
          rotateRight(value2, 17) ^ rotateRight(value2, 19) ^ (value2 >> 10);
      words[index] =
          (words[index - 16] + small0 + words[index - 7] + small1) & mask;
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var index = 0; index < 64; index++) {
      final big1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
      final choose = (e & f) ^ ((~e) & g);
      final temp1 =
          (h + big1 + choose + roundConstants[index] + words[index]) & mask;
      final big0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (big0 + majority) & mask;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & mask;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & mask;
    }
    hash[0] = (hash[0] + a) & mask;
    hash[1] = (hash[1] + b) & mask;
    hash[2] = (hash[2] + c) & mask;
    hash[3] = (hash[3] + d) & mask;
    hash[4] = (hash[4] + e) & mask;
    hash[5] = (hash[5] + f) & mask;
    hash[6] = (hash[6] + g) & mask;
    hash[7] = (hash[7] + h) & mask;
  }

  return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
}

Never _reportFailures(List<String> failures) {
  stderr.writeln('release provenance manifest failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exit(1);
}

const _usage = '''Usage: dart tool/build_release_provenance.dart [options]

Creates a deterministic JSON manifest for a built artifact. The manifest
contains sorted relative paths, byte counts, and SHA-256 digests; it never
copies artifact contents.

Options:
  --root <path>             Project root (default: .).
  --input <path>            Artifact directory to hash (required).
  --output <path>           Manifest path, outside --input.
  --verify <path>           Verify an existing manifest against --input.
  --artifact-name <name>    Stable artifact label (default: input basename).
  --revision <sha>          Source revision recorded as provenance.
  --require-revision        Require a non-empty --revision value.
  --require-web-version     Require Flutter version.json to match pubspec.
  --require-web-shell        Require core Flutter Web shell files.
  --require-web-shell-references  Require index.html shell references.
  --require-web-root-base-href  Require root deployment base href "/".
  --require-web-metadata-parity  Match generated Web descriptions to source.
  --require-web-pwa-contract  Require safe start/display/color manifest fields.
  --require-web-pwa-identity  Match root PWA id/scope in source and artifact.
  --require-web-viewport      Match responsive viewport metadata.
  --require-web-language      Match canonical/generated HTML lang="en".
  --require-web-title-parity  Match canonical/generated HTML title text.
  --require-web-manifest-icon-metadata  Require valid icon sizes/types/purpose.
  --require-web-theme-color-parity  Match theme color across Web metadata.
  --require-web-service-worker-contract  Require versioned cleanup-only worker.
  --require-web-manifest     Require manifest.json identity to match pubspec.
  --require-web-manifest-assets  Require manifest icon sources to be files.
  -h, --help                Show this help.
''';
