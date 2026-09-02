import 'dart:io';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/storage_budget_manager.dart';
import 'package:data_hook_claws/src/models/dataset_artifact_entry.dart';
import 'package:data_hook_claws/src/models/storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'soft delete marks artifact removed without deleting local file',
    () async {
      final repository = MemoryFoodRepository();
      final temp = await Directory.systemTemp.createTemp('dhc-storage-test-');
      final file = File('${temp.path}/artifact.txt');
      await file.writeAsString('official data');
      await repository.upsertDatasetArtifact(
        DatasetArtifactEntry(
          id: 'artifact-1',
          importerId: 'canada-cnf',
          artifactType: 'dataset-path',
          localPath: file.path,
          sourceUrl: '',
          sourceVersion: '',
          fetchedAt: DateTime(2026),
          status: 'ready',
        ),
      );

      await repository.markDatasetArtifactRemoved('artifact-1');
      final artifacts = await repository.getDatasetArtifacts();
      final budget = await StorageBudgetManager(
        repository: repository,
      ).snapshot();

      expect(artifacts.single.status, 'removed');
      expect(file.existsSync(), isTrue);
      expect(budget.artifactBytes, 0);
    },
  );

  test('reports budget warnings when limits are exceeded', () async {
    final repository = MemoryFoodRepository();
    final temp = await Directory.systemTemp.createTemp('dhc-budget-test-');
    final file = File('${temp.path}/artifact.txt');
    await file.writeAsString('official data');
    await repository.upsertDatasetArtifact(
      DatasetArtifactEntry(
        id: 'artifact-1',
        importerId: 'canada-cnf',
        artifactType: 'dataset-path',
        localPath: file.path,
        sourceUrl: '',
        sourceVersion: '',
        fetchedAt: DateTime(2026),
        status: 'ready',
      ),
    );

    final budget = await StorageBudgetManager(
      repository: repository,
      limits: const StorageBudgetLimits(artifactBytes: 1),
    ).snapshot();

    expect(budget.warnings, contains('Artifact budget exceeded'));
  });

  test(
    'keeps budget snapshot available when storage paths cannot be read',
    () async {
      final repository = _FailingBudgetRepository()..failStoragePaths = true;

      final budget = await StorageBudgetManager(
        repository: repository,
      ).snapshot();

      expect(budget.databaseBytes, 0);
      expect(budget.exportBytes, 0);
      expect(budget.cacheBytes, 0);
      expect(budget.warnings, contains('Storage path metadata unavailable'));
    },
  );

  test(
    'keeps filesystem metrics when dataset artifact inventory cannot be read',
    () async {
      final temp = await Directory.systemTemp.createTemp('dhc-budget-paths-');
      final exportFile = File('${temp.path}/export.json');
      await exportFile.writeAsString('exported data');
      addTearDown(() async {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      });

      final repository = _FailingBudgetRepository(
        storagePaths: StoragePaths(
          databasePath: '',
          documentsPath: temp.path,
          exportsPath: temp.path,
          cachePath: '',
        ),
      )..failArtifacts = true;

      final budget = await StorageBudgetManager(
        repository: repository,
      ).snapshot();

      expect(budget.exportBytes, greaterThan(0));
      expect(
        budget.warnings,
        contains('Dataset artifact inventory unavailable'),
      );
    },
  );

  test(
    'keeps the snapshot available and warns when a filesystem path is invalid',
    () async {
      final invalidPath =
          '${Directory.systemTemp.path}/${List.filled(5000, 'x').join()}';
      final repository = _FailingBudgetRepository(
        storagePaths: StoragePaths(
          databasePath: invalidPath,
          documentsPath: '',
          exportsPath: '',
          cachePath: '',
        ),
      );
      final fileSystem = StorageBudgetFileSystem(
        fileExistsSync: (_) => throw StateError('database measurement failed'),
      );

      final budget = await StorageBudgetManager(
        repository: repository,
        fileSystem: fileSystem,
      ).snapshot();

      expect(budget.databaseBytes, 0);
      expect(
        budget.warnings,
        contains('Database size measurement unavailable'),
      );
    },
  );

  test(
    'marks artifact size incomplete while preserving measurable artifacts',
    () async {
      final temp = await Directory.systemTemp.createTemp('dhc-budget-mixed-');
      final validFile = File('${temp.path}/valid.txt');
      final invalidPath = '${temp.path}/${List.filled(5000, 'x').join()}';
      await validFile.writeAsString('known artifact');
      addTearDown(() async {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      });

      final repository = _FailingBudgetRepository();
      await repository.upsertDatasetArtifact(
        DatasetArtifactEntry(
          id: 'valid-artifact',
          importerId: 'canada-cnf',
          artifactType: 'dataset-path',
          localPath: validFile.path,
          sourceUrl: '',
          sourceVersion: '',
          fetchedAt: DateTime(2026),
          status: 'ready',
        ),
      );
      await repository.upsertDatasetArtifact(
        DatasetArtifactEntry(
          id: 'invalid-artifact',
          importerId: 'canada-cnf',
          artifactType: 'dataset-path',
          localPath: invalidPath,
          sourceUrl: '',
          sourceVersion: '',
          fetchedAt: DateTime(2026),
          status: 'ready',
        ),
      );
      final fileSystem = StorageBudgetFileSystem(
        entityTypeSync: (path) {
          if (path == invalidPath) {
            throw StateError('artifact measurement failed');
          }
          return FileSystemEntity.typeSync(path);
        },
      );

      final budget = await StorageBudgetManager(
        repository: repository,
        fileSystem: fileSystem,
      ).snapshot();

      expect(budget.artifactBytes, greaterThan(0));
      expect(budget.warnings, contains('Artifact size measurement incomplete'));
    },
  );
}

class _FailingBudgetRepository extends MemoryFoodRepository {
  _FailingBudgetRepository({this.storagePaths});

  final StoragePaths? storagePaths;
  bool failStoragePaths = false;
  bool failArtifacts = false;

  @override
  Future<StoragePaths> getStoragePaths() async {
    if (failStoragePaths) {
      throw StateError('storage paths unavailable');
    }
    return storagePaths ?? super.getStoragePaths();
  }

  @override
  Future<List<DatasetArtifactEntry>> getDatasetArtifacts({
    int limit = 50,
  }) async {
    if (failArtifacts) {
      throw StateError('artifact inventory unavailable');
    }
    return super.getDatasetArtifacts(limit: limit);
  }
}
