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
    String? stored;
    try {
      stored = await _repository.getAppMeta(settingsKey);
    } catch (_) {
      // Settings are optional at startup; keep the app usable when storage is
      // temporarily unavailable.
      return defaultSettings();
    }
    if (stored == null || stored.trim().isEmpty) {
      final defaults = defaultSettings();
      await _saveBestEffort(defaults);
      return defaults;
    }
    try {
      return _sanitize(AppSettings.fromJsonString(stored));
    } catch (_) {
      final defaults = defaultSettings();
      await _saveBestEffort(defaults);
      return defaults;
    }
  }

  Future<void> _saveBestEffort(AppSettings settings) async {
    try {
      await save(settings);
    } catch (_) {
      // A repair write must not turn a recoverable settings read into a
      // startup failure.
    }
  }

  Future<AppSettings> save(AppSettings settings) async {
    final sanitized = _sanitize(settings);
    await _repository.setAppMeta(settingsKey, sanitized.toJsonString());
    return sanitized;
  }

  AppSettings defaultSettings() {
    return AppSettings(sourceEnabled: _defaultSourceEnabledMap());
  }

  Future<String> effectiveExportDirectory(AppSettings settings) async {
    if (settings.exportDirectory.trim().isNotEmpty) {
      return settings.exportDirectory.trim();
    }
    try {
      final paths = await _repository.getStoragePaths();
      final exportsPath = paths.exportsPath.trim();
      if (exportsPath.isNotEmpty) {
        return exportsPath;
      }
    } catch (_) {
      // Storage-path metadata is supplemental to export itself. If the
      // repository is temporarily unavailable, use the deterministic local
      // fallback below rather than blocking a user-requested export.
    }
    return p.join(Directory.current.path, 'exports');
  }

  AppSettings _sanitize(AppSettings settings) {
    const numericDefaults = AppSettings();
    final sourceDefaults = _defaultSourceEnabledMap();
    final sanitizedSources = <String, bool>{...sourceDefaults};
    for (final entry in settings.sourceEnabled.entries) {
      final capability = _sourceCapabilities.byImporterId(entry.key);
      if (capability == null) {
        continue;
      }
      sanitizedSources[entry.key] = capability.isBlocked ? false : entry.value;
    }
    for (final capability in _sourceCapabilities.all) {
      if (capability.isBlocked) {
        sanitizedSources[capability.importerId] = false;
      }
    }
    return settings.copyWith(
      // A zero model-call budget is retained as an explicit AI disable switch;
      // all other model controls must remain usable positive values.
      modelMaxCallsPerMinute: _nonNegativeOrDefault(
        settings.modelMaxCallsPerMinute,
        numericDefaults.modelMaxCallsPerMinute,
      ),
      modelTimeoutSeconds: _positiveOrDefault(
        settings.modelTimeoutSeconds,
        numericDefaults.modelTimeoutSeconds,
      ),
      modelMaxTokens: _positiveOrDefault(
        settings.modelMaxTokens,
        numericDefaults.modelMaxTokens,
      ),
      databaseBudgetBytes: _positiveOrDefault(
        settings.databaseBudgetBytes,
        numericDefaults.databaseBudgetBytes,
      ),
      artifactBudgetBytes: _positiveOrDefault(
        settings.artifactBudgetBytes,
        numericDefaults.artifactBudgetBytes,
      ),
      exportBudgetBytes: _positiveOrDefault(
        settings.exportBudgetBytes,
        numericDefaults.exportBudgetBytes,
      ),
      cacheBudgetBytes: _positiveOrDefault(
        settings.cacheBudgetBytes,
        numericDefaults.cacheBudgetBytes,
      ),
      sourceEnabled: sanitizedSources,
    );
  }

  int _nonNegativeOrDefault(int value, int fallback) {
    return value < 0 ? fallback : value;
  }

  int _positiveOrDefault(int value, int fallback) {
    return value <= 0 ? fallback : value;
  }

  Map<String, bool> _defaultSourceEnabledMap() {
    return {
      for (final capability in _sourceCapabilities.all)
        capability.importerId: capability.isIntegrated && !capability.isBlocked,
    };
  }
}
