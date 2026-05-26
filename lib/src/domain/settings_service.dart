import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/food_repository.dart';
import '../models/app_settings.dart';
import 'source_capability_registry.dart';

class SettingsService {
  SettingsService({
    required FoodRepository repository,
    required SourceCapabilityRegistry sourceCapabilities,
  }) : _repository = repository,
       _sourceCapabilities = sourceCapabilities;

  static const settingsKey = 'app_settings';

  final FoodRepository _repository;
  final SourceCapabilityRegistry _sourceCapabilities;

  Future<AppSettings> load() async {
    final stored = await _repository.getAppMeta(settingsKey);
    if (stored == null || stored.trim().isEmpty) {
      final defaults = defaultSettings();
      await save(defaults);
      return defaults;
    }
    try {
      return _sanitize(AppSettings.fromJsonString(stored));
    } catch (_) {
      final defaults = defaultSettings();
      await save(defaults);
      return defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    await _repository.setAppMeta(
      settingsKey,
      _sanitize(settings).toJsonString(),
    );
  }

  AppSettings defaultSettings() {
    return AppSettings(sourceEnabled: _defaultSourceEnabledMap());
  }

  Future<String> effectiveExportDirectory(AppSettings settings) async {
    if (settings.exportDirectory.trim().isNotEmpty) {
      return settings.exportDirectory.trim();
    }
    final paths = await _repository.getStoragePaths();
    if (paths.exportsPath.trim().isNotEmpty) {
      return paths.exportsPath;
    }
    return p.join(Directory.current.path, 'exports');
  }

  AppSettings _sanitize(AppSettings settings) {
    final defaults = _defaultSourceEnabledMap();
    final sanitized = <String, bool>{...defaults};
    for (final entry in settings.sourceEnabled.entries) {
      final capability = _sourceCapabilities.byImporterId(entry.key);
      if (capability == null) {
        continue;
      }
      sanitized[entry.key] = capability.isBlocked ? false : entry.value;
    }
    for (final capability in _sourceCapabilities.all) {
      if (capability.isBlocked) {
        sanitized[capability.importerId] = false;
      }
    }
    return settings.copyWith(sourceEnabled: sanitized);
  }

  Map<String, bool> _defaultSourceEnabledMap() {
    return {
      for (final capability in _sourceCapabilities.all)
        capability.importerId: capability.isIntegrated && !capability.isBlocked,
    };
  }
}
