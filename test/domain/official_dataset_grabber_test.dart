import 'dart:io';

import 'package:archive/archive.dart';
import 'package:data_hook_claws/src/data/official_dataset_grabber.dart';
import 'package:data_hook_claws/src/data/official_dataset_manifest.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('official dataset grabber', () {
    test('keeps explicit local dataset path unchanged', () async {
      final grabber = OfficialDatasetGrabber(
        transport: _FakeDatasetTransport(),
        packagePreparer: _FakePackagePreparer(),
      );

      final request = await grabber.prepareRequest(
        importerId: 'uk-mccance',
        request: const ImportRequest(
          query: 'salmon',
          limit: 10,
          datasetPath: '/manual/cofid.xlsx',
        ),
      );

      expect(request.datasetPath, '/manual/cofid.xlsx');
    });

    test('downloads official workbook when manifest entry exists', () async {
      final transport = _FakeDatasetTransport();
      final testRoot = await Directory.systemTemp.createTemp('grabber-root');
      addTearDown(() async {
        if (testRoot.existsSync()) {
          await testRoot.delete(recursive: true);
        }
      });
      final grabber = OfficialDatasetGrabber(
        transport: transport,
        packagePreparer: _FakePackagePreparer(),
        rootResolver: () async => testRoot,
        manifest: const {
          'uk-mccance': OfficialDatasetManifestEntry(
            importerId: 'uk-mccance',
            sourcePageUrl: 'https://example.com/cofid',
            sourceLabel: 'UK dataset',
            packaging: OfficialDatasetPackaging.singleFile,
            downloads: [
              OfficialDatasetDownload.direct(
                suggestedFileName: 'uk.xlsx',
                directUrl: 'https://example.com/cofid.xlsx',
              ),
            ],
          ),
        },
      );

      final request = await grabber.prepareRequest(
        importerId: 'uk-mccance',
        request: const ImportRequest(query: 'salmon', limit: 10),
      );

      expect(request.datasetPath, endsWith('/downloaded/uk-mccance/uk.xlsx'));
      expect(transport.lastUrl.toString(), 'https://example.com/cofid.xlsx');
    });

    test(
      'leaves request untouched for importers without manifest entries',
      () async {
        final grabber = OfficialDatasetGrabber(
          transport: _FakeDatasetTransport(),
          packagePreparer: _FakePackagePreparer(),
        );

        final request = await grabber.prepareRequest(
          importerId: 'unknown-source',
          request: const ImportRequest(query: 'beans', limit: 10),
        );

        expect(request.datasetPath, isNull);
      },
    );

    test('preparer extracts zip packages into an importer directory', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'dataset-preparer-test',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final zipFile = File(p.join(tempDirectory.path, 'cnf.zip'));
      await zipFile.writeAsBytes(_tinyZipBytes(), flush: true);

      final preparer = DatasetPackagePreparer(
        rootResolver: () async => tempDirectory,
      );
      final datasetPath = await preparer.prepare(
        importerId: 'canada-cnf',
        packaging: OfficialDatasetPackaging.zipDirectory,
        downloadedFiles: [zipFile.path],
      );

      expect(File(p.join(datasetPath, 'Food name.csv')).existsSync(), isTrue);
      expect(
        File(p.join(datasetPath, 'Nutrient amount.csv')).existsSync(),
        isTrue,
      );
    });

    test('ships a direct single-file manifest for France CIQUAL', () {
      final entry = officialDatasetManifest['fr-ciqual'];

      expect(entry, isNotNull);
      expect(entry!.packaging, OfficialDatasetPackaging.singleFile);
      expect(entry.downloads.single.suggestedFileName, contains('ciqual'));
      expect(
        entry.downloads.single.directUrl,
        contains('Table%20Ciqual%202025_ENG_2025_11_03.xlsx'),
      );
    });
  });
}

class _FakeDatasetTransport implements DatasetTransport {
  Uri? lastUrl;

  @override
  Future<Directory> datasetRoot(String importerId) async {
    return Directory(
      p.join(Directory.systemTemp.path, 'fake-dataset-transport', importerId),
    );
  }

  @override
  Future<String> download({
    required Uri url,
    required String suggestedFileName,
    required String importerId,
  }) async {
    lastUrl = url;
    return '/downloaded/$importerId/$suggestedFileName';
  }

  @override
  Future<Uri> discoverUrl({
    required Uri sourcePageUrl,
    required PageLinkDiscovery discovery,
  }) async {
    return sourcePageUrl.resolve(
      '/resolved/${discovery.containsAll.first}.xlsx',
    );
  }
}

class _FakePackagePreparer extends DatasetPackagePreparer {
  @override
  Future<String> prepare({
    required String importerId,
    required OfficialDatasetPackaging packaging,
    required List<String> downloadedFiles,
  }) async {
    return '/prepared/${downloadedFiles.first}';
  }
}

List<int> _tinyZipBytes() {
  final archive = Archive()
    ..addFile(
      ArchiveFile('Food name.csv', 23, 'FoodID,FoodDescription\n'.codeUnits),
    )
    ..addFile(
      ArchiveFile(
        'Nutrient amount.csv',
        21,
        'FoodID,NutrientValue\n'.codeUnits,
      ),
    );
  return ZipEncoder().encode(archive)!;
}
