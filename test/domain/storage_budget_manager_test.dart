import 'dart:io';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/storage_budget_manager.dart';
import 'package:data_hook_claws/src/models/dataset_artifact_entry.dart';
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
}
