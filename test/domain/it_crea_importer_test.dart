import 'dart:convert';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/normalization/food_record_normalizer.dart';
import 'package:data_hook_claws/src/domain/sync_food_catalog_use_case.dart';
import 'package:data_hook_claws/src/importers/it_crea_importer.dart';
import 'package:data_hook_claws/src/models/dataset_artifact_entry.dart';
import 'package:data_hook_claws/src/models/import_log_entry.dart';
import 'package:data_hook_claws/src/models/import_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ItCreaImporter', () {
    test('filters the official index and parses detail nutrients', () async {
      final importer = ItCreaImporter(client: _fakeClient());
      final foods = await importer.importFoods(
        const ImportRequest(query: 'pane', limit: 5),
      );

      expect(foods, hasLength(1));
      expect(foods.single.sourceRecordId, '000500');
      expect(foods.single.name, 'Pane al malto');
      expect(foods.single.category, 'Cereali e derivati');
      expect(
        foods.single.nutrients
            .firstWhere((nutrient) => nutrient.label == 'Protein')
            .amount,
        8.3,
      );
      expect(
        foods.single.nutrients
            .firstWhere((nutrient) => nutrient.label == 'Vitamin A')
            .amount,
        0,
      );
    });

    test('runs through sync use case and persists normalized result', () async {
      final repository = MemoryFoodRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [ItCreaImporter(client: _fakeClient())],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'it-crea',
        request: const ImportRequest(query: 'pane', limit: 5),
      );

      final results = await repository.searchFoods('pane');
      expect(summary.importedCount, 1);
      expect(results.single.country, 'Italy');
    });

    test('returns imported foods when success log persistence fails', () async {
      final repository = _FailingImportLogRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [ItCreaImporter(client: _fakeClient())],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'it-crea',
        request: const ImportRequest(query: 'pane', limit: 5),
      );

      expect(summary.importedCount, 1);
      expect(await repository.searchFoods('pane'), hasLength(1));
      expect(repository.logWriteAttempts, 1);
    });

    test('returns imported foods when artifact persistence fails', () async {
      final repository = _FailingDatasetArtifactRepository();
      final useCase = SyncFoodCatalogUseCase(
        repository: repository,
        importers: [ItCreaImporter(client: _fakeClient())],
        normalizer: const FoodRecordNormalizer(),
      );

      final summary = await useCase.syncSource(
        importerId: 'it-crea',
        request: const ImportRequest(
          query: 'pane',
          limit: 5,
          datasetPath: '/manual/it-crea-export.html',
        ),
      );

      expect(summary.importedCount, 1);
      expect(await repository.searchFoods('pane'), hasLength(1));
      expect(repository.artifactWriteAttempts, 1);
      expect((await repository.getImportLogs()).single.status, 'success');
    });

    test(
      'preserves the original import failure when failure log persistence fails',
      () async {
        final repository = _FailingImportLogRepository();
        final useCase = SyncFoodCatalogUseCase(
          repository: repository,
          importers: [
            ItCreaImporter(
              client: MockClient(
                (_) async => http.Response('upstream unavailable', 503),
              ),
            ),
          ],
          normalizer: const FoodRecordNormalizer(),
        );

        await expectLater(
          useCase.syncSource(
            importerId: 'it-crea',
            request: const ImportRequest(query: 'pane', limit: 5),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('status 503'),
            ),
          ),
        );
        expect(repository.logWriteAttempts, 1);
      },
    );
  });
}

class _FailingImportLogRepository extends MemoryFoodRepository {
  int logWriteAttempts = 0;

  @override
  Future<void> addImportLog(ImportLogEntry entry) async {
    logWriteAttempts += 1;
    throw StateError('import log unavailable');
  }
}

class _FailingDatasetArtifactRepository extends MemoryFoodRepository {
  int artifactWriteAttempts = 0;

  @override
  Future<void> upsertDatasetArtifact(DatasetArtifactEntry entry) async {
    artifactWriteAttempts += 1;
    throw StateError('dataset artifact unavailable');
  }
}

http.Client _fakeClient() {
  return MockClient((request) async {
    final url = request.url.toString();
    if (url.endsWith('/tabelle-nutrizionali/ricerca-per-alimento')) {
      return _utf8Response(_indexHtml);
    }
    if (url.endsWith('/tabelle-nutrizionali/000500')) {
      return _utf8Response(_paneHtml);
    }
    return http.Response('not found', 404);
  });
}

http.Response _utf8Response(String body) {
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

const _indexHtml = '''
<html>
  <body>
    <h2>Ricerca Dati Per Alimento</h2>
    <table>
      <tr><td><a href="/tabelle-nutrizionali/000500">Pane al malto</a></td></tr>
      <tr><td><a href="/tabelle-nutrizionali/103200">Salmone</a></td></tr>
    </table>
  </body>
</html>
''';

const _paneHtml = '''
<html>
  <body>
    <h1>Tabelle di Composizione degli Alimenti</h1>
    <h2>Pane al malto</h2>
    <table>
      <tr><td>Categoria</td><td>Cereali e derivati</td></tr>
      <tr><td>Codice Alimento</td><td>000500</td></tr>
      <tr><td>English Name</td><td>Malted bread</td></tr>
      <tr><td>Parte Edibile</td><td>100 %</td></tr>
      <tr><td>Porzione</td><td>50 g</td></tr>
    </table>
    <h3>MACRO NUTRIENTI</h3>
    <table>
      <tr>
        <th>Descrizione Nutriente</th>
        <th>Unità di Misura</th>
        <th>Valore per 100 g</th>
      </tr>
      <tr><td>Acqua (g)</td><td>g</td><td>26,0</td></tr>
      <tr><td>Proteine (g)</td><td>g (N x 6,25)</td><td>8,3</td></tr>
      <tr><td>Carboidrati disponibili (g)</td><td>g</td><td>56,6</td></tr>
      <tr><td>Fibra totale (g)</td><td>g</td><td>5,5</td></tr>
    </table>
    <h3>MINERALI</h3>
    <table>
      <tr>
        <th>Descrizione Nutriente</th>
        <th>Unità di Misura</th>
        <th>Valore per 100 g</th>
      </tr>
      <tr><td>Sodio (mg)</td><td>mg</td><td>280</td></tr>
    </table>
    <h3>VITAMINE</h3>
    <table>
      <tr>
        <th>Descrizione Nutriente</th>
        <th>Unità di Misura</th>
        <th>Valore per 100 g</th>
      </tr>
      <tr><td>Vitamina A retinolo equivalente (μg)</td><td>μg</td><td>tr</td></tr>
    </table>
    <p>Ultimo aggiornamento: Dicembre 2019</p>
  </body>
</html>
''';
