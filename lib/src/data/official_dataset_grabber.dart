import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/import_models.dart';
import 'official_dataset_manifest.dart';

class OfficialDatasetGrabber {
  OfficialDatasetGrabber({
    DatasetTransport? transport,
    DatasetPackagePreparer? packagePreparer,
    Map<String, OfficialDatasetManifestEntry>? manifest,
    DatasetRootResolver? rootResolver,
  }) : _transport =
           transport ?? HttpDatasetTransport(rootResolver: rootResolver),
       _packagePreparer =
           packagePreparer ??
           DatasetPackagePreparer(rootResolver: rootResolver),
       _manifest = manifest ?? officialDatasetManifest;

  final DatasetTransport _transport;
  final DatasetPackagePreparer _packagePreparer;
  final Map<String, OfficialDatasetManifestEntry> _manifest;

  Future<ImportRequest> prepareRequest({
    required String importerId,
    required ImportRequest request,
  }) async {
    final existingPath = request.datasetPath?.trim() ?? '';
    if (existingPath.isNotEmpty) {
      return request;
    }

    final manifestEntry = _manifest[importerId];
    if (manifestEntry == null) {
      return request;
    }

    final rootDirectory = await _datasetRoot(importerId);
    await rootDirectory.create(recursive: true);

    final downloadedFiles = <String>[];
    for (final download in manifestEntry.downloads) {
      final url = await _resolveDownloadUrl(
        sourcePageUrl: manifestEntry.sourcePageUrl,
        download: download,
      );

      downloadedFiles.add(
        await _transport.download(
          url: url,
          suggestedFileName: download.suggestedFileName,
          importerId: importerId,
        ),
      );
    }

    final datasetPath = await _packagePreparer.prepare(
      importerId: importerId,
      packaging: manifestEntry.packaging,
      downloadedFiles: downloadedFiles,
    );

    return request.copyWith(datasetPath: datasetPath);
  }

  Future<Directory> _datasetRoot(String importerId) async =>
      _transport.datasetRoot(importerId);

  Future<Uri> _resolveDownloadUrl({
    required String sourcePageUrl,
    required OfficialDatasetDownload download,
  }) async {
    final directUrl = download.directUrl;
    if (directUrl != null) {
      return Uri.parse(directUrl);
    }

    final discovery = download.discovery;
    if (discovery == null) {
      throw StateError(
        'Dataset download is missing both directUrl and discovery.',
      );
    }

    return _transport.discoverUrl(
      sourcePageUrl: Uri.parse(sourcePageUrl),
      discovery: discovery,
    );
  }
}

abstract class DatasetTransport {
  Future<Directory> datasetRoot(String importerId);

  Future<String> download({
    required Uri url,
    required String suggestedFileName,
    required String importerId,
  });

  Future<Uri> discoverUrl({
    required Uri sourcePageUrl,
    required PageLinkDiscovery discovery,
  });
}

class HttpDatasetTransport implements DatasetTransport {
  HttpDatasetTransport({http.Client? client, DatasetRootResolver? rootResolver})
    : _client = client ?? http.Client(),
      _rootResolver = rootResolver ?? defaultDatasetRootResolver;

  final http.Client _client;
  final DatasetRootResolver _rootResolver;

  @override
  Future<Directory> datasetRoot(String importerId) async {
    final root = await _rootResolver();
    return Directory(p.join(root.path, 'official_datasets', importerId));
  }

  @override
  Future<String> download({
    required Uri url,
    required String suggestedFileName,
    required String importerId,
  }) async {
    final root = await datasetRoot(importerId);
    final targetDirectory = Directory(p.join(root.path, 'downloads'));
    await targetDirectory.create(recursive: true);

    final targetPath = p.join(targetDirectory.path, suggestedFileName);
    final targetFile = File(targetPath);
    if (targetFile.existsSync() && await targetFile.length() > 0) {
      return targetPath;
    }

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw StateError(
        'Dataset download failed with status ${response.statusCode}: $url',
      );
    }

    await targetFile.writeAsBytes(response.bodyBytes, flush: true);
    return targetPath;
  }

  @override
  Future<Uri> discoverUrl({
    required Uri sourcePageUrl,
    required PageLinkDiscovery discovery,
  }) async {
    final response = await _client.get(sourcePageUrl);
    if (response.statusCode != 200) {
      throw StateError(
        'Dataset discovery page failed with status ${response.statusCode}: $sourcePageUrl',
      );
    }

    final html = response.body;
    final anchorMatches = RegExp(
      r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final match in anchorMatches) {
      final href = match.group(1) ?? '';
      final anchorBody = _stripHtml(match.group(2) ?? '');
      final candidateText = '$href $anchorBody'.toLowerCase();
      final extension = discovery.fileExtension?.toLowerCase();
      if (extension != null && !href.toLowerCase().contains(extension)) {
        continue;
      }
      final containsAll = discovery.containsAll.every(
        (pattern) => candidateText.contains(pattern.toLowerCase()),
      );
      if (!containsAll) {
        continue;
      }
      return sourcePageUrl.resolve(href);
    }

    throw StateError(
      'Could not discover a dataset URL on $sourcePageUrl matching ${discovery.containsAll.join(', ')}.',
    );
  }

  String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class DatasetPackagePreparer {
  DatasetPackagePreparer({DatasetRootResolver? rootResolver})
    : _rootResolver = rootResolver ?? defaultDatasetRootResolver;

  final DatasetRootResolver _rootResolver;

  Future<String> prepare({
    required String importerId,
    required OfficialDatasetPackaging packaging,
    required List<String> downloadedFiles,
  }) async {
    if (downloadedFiles.isEmpty) {
      throw StateError('No downloaded files were provided for $importerId.');
    }

    switch (packaging) {
      case OfficialDatasetPackaging.singleFile:
      case OfficialDatasetPackaging.installerFile:
        return downloadedFiles.first;
      case OfficialDatasetPackaging.downloadedDirectory:
        return p.dirname(downloadedFiles.first);
      case OfficialDatasetPackaging.zipDirectory:
        return _extractZipDirectory(
          importerId: importerId,
          zipPath: downloadedFiles.first,
        );
    }
  }

  Future<String> _extractZipDirectory({
    required String importerId,
    required String zipPath,
  }) async {
    final root = await _rootResolver();
    final extractDirectory = Directory(
      p.join(root.path, 'official_datasets', importerId, 'extracted'),
    );

    final sentinel = File(p.join(extractDirectory.path, '.ready'));
    if (sentinel.existsSync()) {
      return extractDirectory.path;
    }

    await extractDirectory.create(recursive: true);
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());

    for (final file in archive) {
      final safePath = p.normalize(p.join(extractDirectory.path, file.name));
      if (!safePath.startsWith(extractDirectory.path)) {
        continue;
      }

      if (file.isFile) {
        final output = File(safePath);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        await Directory(safePath).create(recursive: true);
      }
    }

    await sentinel.writeAsString(jsonEncode({'zipPath': zipPath}), flush: true);
    return extractDirectory.path;
  }
}

typedef DatasetRootResolver = Future<Directory> Function();

Future<Directory> defaultDatasetRootResolver() async {
  return getApplicationDocumentsDirectory();
}
