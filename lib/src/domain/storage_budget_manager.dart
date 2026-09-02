import 'dart:io';

import '../data/food_repository.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/storage_paths.dart';

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

class _SizeMeasurement {
  const _SizeMeasurement(this.bytes, {this.complete = true});

  final int bytes;
  final bool complete;
}

class StorageBudgetFileSystem {
  const StorageBudgetFileSystem({
    this.entityTypeSync,
    this.fileExistsSync,
    this.fileLengthSync,
    this.directoryExistsSync,
    this.directoryListSync,
  });

  final FileSystemEntityType Function(String path)? entityTypeSync;
  final bool Function(String path)? fileExistsSync;
  final int Function(String path)? fileLengthSync;
  final bool Function(String path)? directoryExistsSync;
  final List<FileSystemEntity> Function(String path)? directoryListSync;

  FileSystemEntityType typeSync(String path) {
    return entityTypeSync?.call(path) ?? FileSystemEntity.typeSync(path);
  }

  bool fileExists(String path) {
    return fileExistsSync?.call(path) ?? File(path).existsSync();
  }

  int fileLength(String path) {
    return fileLengthSync?.call(path) ?? File(path).lengthSync();
  }

  bool directoryExists(String path) {
    return directoryExistsSync?.call(path) ?? Directory(path).existsSync();
  }

  List<FileSystemEntity> directoryList(String path) {
    return directoryListSync?.call(path) ??
        Directory(path).listSync(recursive: true);
  }
}

class StorageBudgetManager {
  const StorageBudgetManager({
    required FoodRepository repository,
    this.limits = const StorageBudgetLimits(),
    this.fileSystem = const StorageBudgetFileSystem(),
  }) : _repository = repository;

  final FoodRepository _repository;
  final StorageBudgetLimits limits;
  final StorageBudgetFileSystem fileSystem;

  Future<StorageBudgetSnapshot> snapshot() async {
    final warnings = <String>[];
    late final StoragePaths paths;
    try {
      paths = await _repository.getStoragePaths();
    } catch (_) {
      // Storage paths are observability metadata. Keep the budget card
      // renderable, but expose that the resulting zero metrics are unknown.
      paths = const StoragePaths(
        databasePath: '',
        documentsPath: '',
        exportsPath: '',
        cachePath: '',
      );
      warnings.add('Storage path metadata unavailable');
    }

    late final List<DatasetArtifactEntry> artifacts;
    try {
      artifacts = await _repository.getDatasetArtifacts(limit: 1000);
    } catch (_) {
      // Artifact inventory is independent from filesystem measurements. A
      // transient inventory read must not hide the other budget metrics.
      artifacts = const <DatasetArtifactEntry>[];
      warnings.add('Dataset artifact inventory unavailable');
    }

    final database = _fileSize(paths.databasePath);
    final artifact = _artifactSize(artifacts);
    final exports = _directorySize(paths.exportsPath);
    final cache = _directorySize(paths.cachePath);
    warnings.addAll([
      if (!database.complete) 'Database size measurement unavailable',
      if (!artifact.complete) 'Artifact size measurement incomplete',
      if (!exports.complete) 'Export size measurement incomplete',
      if (!cache.complete) 'Cache size measurement incomplete',
      if (database.bytes > limits.databaseBytes) 'Database budget exceeded',
      if (artifact.bytes > limits.artifactBytes) 'Artifact budget exceeded',
      if (exports.bytes > limits.exportBytes) 'Export budget exceeded',
      if (cache.bytes > limits.cacheBytes) 'Cache budget exceeded',
    ]);

    return StorageBudgetSnapshot(
      databaseBytes: database.bytes,
      artifactBytes: artifact.bytes,
      exportBytes: exports.bytes,
      cacheBytes: cache.bytes,
      limits: limits,
      warnings: warnings,
    );
  }

  _SizeMeasurement _artifactSize(List<DatasetArtifactEntry> artifacts) {
    var total = 0;
    var complete = true;
    for (final artifact in artifacts) {
      if (artifact.status == 'removed') {
        continue;
      }
      final measurement = _pathSize(artifact.localPath);
      total += measurement.bytes;
      complete = complete && measurement.complete;
    }
    return _SizeMeasurement(total, complete: complete);
  }

  _SizeMeasurement _pathSize(String path) {
    if (path.trim().isEmpty) {
      return const _SizeMeasurement(0);
    }
    try {
      final type = fileSystem.typeSync(path);
      return switch (type) {
        FileSystemEntityType.file => _fileSize(path),
        FileSystemEntityType.directory => _directorySize(path),
        _ => const _SizeMeasurement(0),
      };
    } on Object {
      return const _SizeMeasurement(0, complete: false);
    }
  }

  _SizeMeasurement _fileSize(String path) {
    if (path.trim().isEmpty) {
      return const _SizeMeasurement(0);
    }
    try {
      if (!fileSystem.fileExists(path)) {
        return const _SizeMeasurement(0);
      }
      return _SizeMeasurement(fileSystem.fileLength(path));
    } on Object {
      return const _SizeMeasurement(0, complete: false);
    }
  }

  _SizeMeasurement _directorySize(String path) {
    if (path.trim().isEmpty) {
      return const _SizeMeasurement(0);
    }
    var total = 0;
    var complete = true;
    try {
      if (!fileSystem.directoryExists(path)) {
        return const _SizeMeasurement(0);
      }
      for (final entity in fileSystem.directoryList(path)) {
        if (entity is File) {
          final measurement = _fileSize(entity.path);
          total += measurement.bytes;
          complete = complete && measurement.complete;
        }
      }
    } on Object {
      return _SizeMeasurement(total, complete: false);
    }
    return _SizeMeasurement(total, complete: complete);
  }
}
