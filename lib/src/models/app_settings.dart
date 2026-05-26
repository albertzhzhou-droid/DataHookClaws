import 'dart:convert';

import '../domain/storage_budget_manager.dart';

class AppSettings {
  const AppSettings({
    this.ollamaEndpoint = 'http://127.0.0.1:11434',
    this.ollamaModel = 'llama3',
    this.modelMaxCallsPerMinute = 6,
    this.modelTimeoutSeconds = 3,
    this.modelMaxTokens = 256,
    this.exportDirectory = '',
    this.databaseBudgetBytes = 512 * 1024 * 1024,
    this.artifactBudgetBytes = 2 * 1024 * 1024 * 1024,
    this.exportBudgetBytes = 1024 * 1024 * 1024,
    this.cacheBudgetBytes = 512 * 1024 * 1024,
    this.sourceEnabled = const {},
  });

  final String ollamaEndpoint;
  final String ollamaModel;
  final int modelMaxCallsPerMinute;
  final int modelTimeoutSeconds;
  final int modelMaxTokens;
  final String exportDirectory;
  final int databaseBudgetBytes;
  final int artifactBudgetBytes;
  final int exportBudgetBytes;
  final int cacheBudgetBytes;
  final Map<String, bool> sourceEnabled;

  StorageBudgetLimits get storageLimits => StorageBudgetLimits(
    databaseBytes: databaseBudgetBytes,
    artifactBytes: artifactBudgetBytes,
    exportBytes: exportBudgetBytes,
    cacheBytes: cacheBudgetBytes,
  );

  Set<String> get disabledSourceIds => sourceEnabled.entries
      .where((entry) => !entry.value)
      .map((entry) => entry.key)
      .toSet();

  AppSettings copyWith({
    String? ollamaEndpoint,
    String? ollamaModel,
    int? modelMaxCallsPerMinute,
    int? modelTimeoutSeconds,
    int? modelMaxTokens,
    String? exportDirectory,
    int? databaseBudgetBytes,
    int? artifactBudgetBytes,
    int? exportBudgetBytes,
    int? cacheBudgetBytes,
    Map<String, bool>? sourceEnabled,
  }) {
    return AppSettings(
      ollamaEndpoint: ollamaEndpoint ?? this.ollamaEndpoint,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      modelMaxCallsPerMinute:
          modelMaxCallsPerMinute ?? this.modelMaxCallsPerMinute,
      modelTimeoutSeconds: modelTimeoutSeconds ?? this.modelTimeoutSeconds,
      modelMaxTokens: modelMaxTokens ?? this.modelMaxTokens,
      exportDirectory: exportDirectory ?? this.exportDirectory,
      databaseBudgetBytes: databaseBudgetBytes ?? this.databaseBudgetBytes,
      artifactBudgetBytes: artifactBudgetBytes ?? this.artifactBudgetBytes,
      exportBudgetBytes: exportBudgetBytes ?? this.exportBudgetBytes,
      cacheBudgetBytes: cacheBudgetBytes ?? this.cacheBudgetBytes,
      sourceEnabled: sourceEnabled ?? this.sourceEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'ollamaEndpoint': ollamaEndpoint,
      'ollamaModel': ollamaModel,
      'modelMaxCallsPerMinute': modelMaxCallsPerMinute,
      'modelTimeoutSeconds': modelTimeoutSeconds,
      'modelMaxTokens': modelMaxTokens,
      'exportDirectory': exportDirectory,
      'databaseBudgetBytes': databaseBudgetBytes,
      'artifactBudgetBytes': artifactBudgetBytes,
      'exportBudgetBytes': exportBudgetBytes,
      'cacheBudgetBytes': cacheBudgetBytes,
      'sourceEnabled': sourceEnabled,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static AppSettings fromJsonString(String value) {
    final decoded = jsonDecode(value) as Map<String, dynamic>;
    return AppSettings.fromJson(decoded);
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      ollamaEndpoint:
          (json['ollamaEndpoint'] as String?) ?? 'http://127.0.0.1:11434',
      ollamaModel: (json['ollamaModel'] as String?) ?? 'llama3',
      modelMaxCallsPerMinute: _intValue(json['modelMaxCallsPerMinute'], 6),
      modelTimeoutSeconds: _intValue(json['modelTimeoutSeconds'], 3),
      modelMaxTokens: _intValue(json['modelMaxTokens'], 256),
      exportDirectory: (json['exportDirectory'] as String?) ?? '',
      databaseBudgetBytes: _intValue(
        json['databaseBudgetBytes'],
        512 * 1024 * 1024,
      ),
      artifactBudgetBytes: _intValue(
        json['artifactBudgetBytes'],
        2 * 1024 * 1024 * 1024,
      ),
      exportBudgetBytes: _intValue(
        json['exportBudgetBytes'],
        1024 * 1024 * 1024,
      ),
      cacheBudgetBytes: _intValue(json['cacheBudgetBytes'], 512 * 1024 * 1024),
      sourceEnabled: _boolMap(json['sourceEnabled']),
    );
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, bool> _boolMap(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, value) => MapEntry(key.toString(), value == true));
  }
}
