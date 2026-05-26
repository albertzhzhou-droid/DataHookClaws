import 'dart:io';

import '../data/food_repository.dart';
import '../models/dataset_artifact_entry.dart';

class StorageBudgetLimits {
  const StorageBudgetLimits({
    this.databaseBytes = 512 * 1024 * 1024,
    this.artifactBytes = 2 * 1024 * 1024 * 1024,
    this.exportBytes = 1024 * 1024 * 1024,
    this.cacheBytes = 512 * 1024 * 1024,
  });

  final int databaseBytes;
  final int artifactBytes;
  final int exportBytes;
  final int cacheBytes;
}

class StorageBudgetSnapshot {
  const StorageBudgetSnapshot({
    required this.databaseBytes,
    required this.artifactBytes,
    required this.exportBytes,
    required this.cacheBytes,
    required this.limits,
    required this.warnings,
  });

  final int databaseBytes;
  final int artifactBytes;
  final int exportBytes;
  final int cacheBytes;
  final StorageBudgetLimits limits;
  final List<String> warnings;
}

class StorageBudgetManager {
  const StorageBudgetManager({
    required FoodRepository repository,
    this.limits = const StorageBudgetLimits(),
  }) : _repository = repository;

  final FoodRepository _repository;
  final StorageBudgetLimits limits;

  Future<StorageBudgetSnapshot> snapshot() async {
    final paths = await _repository.getStoragePaths();
    final artifacts = await _repository.getDatasetArtifacts(limit: 1000);
    final databaseBytes = _fileSize(paths.databasePath);
    final artifactBytes = _artifactSize(artifacts);
    final exportBytes = _directorySize(paths.exportsPath);
    final cacheBytes = _directorySize(paths.cachePath);
    final warnings = <String>[
      if (databaseBytes > limits.databaseBytes) 'Database budget exceeded',
      if (artifactBytes > limits.artifactBytes) 'Artifact budget exceeded',
      if (exportBytes > limits.exportBytes) 'Export budget exceeded',
      if (cacheBytes > limits.cacheBytes) 'Cache budget exceeded',
    ];

    return StorageBudgetSnapshot(
      databaseBytes: databaseBytes,
      artifactBytes: artifactBytes,
      exportBytes: exportBytes,
      cacheBytes: cacheBytes,
      limits: limits,
      warnings: warnings,
    );
  }

  int _artifactSize(List<DatasetArtifactEntry> artifacts) {
    var total = 0;
    for (final artifact in artifacts) {
      if (artifact.status == 'removed') {
        continue;
      }
      total += _pathSize(artifact.localPath);
    }
    return total;
  }

  int _pathSize(String path) {
    if (path.trim().isEmpty) {
      return 0;
    }
    final type = FileSystemEntity.typeSync(path);
    return switch (type) {
      FileSystemEntityType.file => _fileSize(path),
      FileSystemEntityType.directory => _directorySize(path),
      _ => 0,
    };
  }

  int _fileSize(String path) {
    if (path.trim().isEmpty) {
      return 0;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return 0;
    }
    try {
      return file.lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  int _directorySize(String path) {
    if (path.trim().isEmpty) {
      return 0;
    }
    final directory = Directory(path);
    if (!directory.existsSync()) {
      return 0;
    }
    var total = 0;
    try {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is File) {
          try {
            total += entity.lengthSync();
          } on FileSystemException {
            continue;
          }
        }
      }
    } on FileSystemException {
      return total;
    }
    return total;
  }
}
