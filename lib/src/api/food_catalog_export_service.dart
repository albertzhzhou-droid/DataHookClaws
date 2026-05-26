import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/food_repository.dart';
import '../domain/ai_assist_services.dart';
import '../domain/settings_service.dart';
import '../models/export_history_entry.dart';
import '../models/food_details.dart';
import 'export_models.dart';
import 'food_api_dto.dart';

typedef ExportDirectoryResolver = Future<Directory> Function();
typedef ExportDirectoryPathResolver = Future<String> Function();

class FoodCatalogExportService {
  FoodCatalogExportService({
    required FoodRepository repository,
    ExportDirectoryResolver? documentsDirectoryResolver,
    ExportDirectoryPathResolver? exportDirectoryPathResolver,
    ExportSummaryService? exportSummaryService,
    DateTime Function()? clock,
  }) : _repository = repository,
       _documentsDirectoryResolver =
           documentsDirectoryResolver ?? getApplicationDocumentsDirectory,
       _exportDirectoryPathResolver = exportDirectoryPathResolver,
       _exportSummaryService = exportSummaryService,
       _clock = clock ?? DateTime.now;

  FoodCatalogExportService.withSettings({
    required FoodRepository repository,
    required SettingsService settingsService,
    ExportSummaryService? exportSummaryService,
    DateTime Function()? clock,
  }) : this(
         repository: repository,
         exportDirectoryPathResolver: () async {
           final settings = await settingsService.load();
           return settingsService.effectiveExportDirectory(settings);
         },
         exportSummaryService: exportSummaryService,
         clock: clock,
       );

  final FoodRepository _repository;
  final ExportDirectoryResolver _documentsDirectoryResolver;
  final ExportDirectoryPathResolver? _exportDirectoryPathResolver;
  final ExportSummaryService? _exportSummaryService;
  final DateTime Function() _clock;

  Future<ExportArtifact> exportSearchResults({
    required String query,
    required ExportFormat format,
    required ExportDetailLevel detailLevel,
    int limit = 200,
  }) async {
    if (format == ExportFormat.sqliteSnapshot) {
      throw UnsupportedError(
        'Search-result export does not support sqlite snapshot format.',
      );
    }

    final summaries = await _repository.searchFoodSummaries(
      query,
      limit: limit,
    );
    final summaryDtos = summaries
        .map(FoodSummaryDto.fromSummary)
        .toList(growable: false);
    final details = detailLevel == ExportDetailLevel.detailed
        ? await _loadDetails(summaryDtos)
        : const <FoodDetails>[];
    return _writeExport(
      format: format,
      detailLevel: detailLevel,
      scopeType: 'search',
      scopeValue: query.trim().isEmpty ? 'all-local-foods' : query.trim(),
      summaries: summaryDtos,
      details: details,
    );
  }

  Future<ExportArtifact> exportCountrySlice({
    required String country,
    required ExportFormat format,
    required ExportDetailLevel detailLevel,
    int limit = 1000,
  }) async {
    if (format == ExportFormat.sqliteSnapshot) {
      throw UnsupportedError(
        'Country-slice export does not support sqlite snapshot format.',
      );
    }

    final summaries = await _repository.searchFoodSummariesByCountry(
      country,
      limit: limit,
    );
    final summaryDtos = summaries
        .map(FoodSummaryDto.fromSummary)
        .toList(growable: false);
    final details = detailLevel == ExportDetailLevel.detailed
        ? await _loadDetails(summaryDtos)
        : const <FoodDetails>[];
    return _writeExport(
      format: format,
      detailLevel: detailLevel,
      scopeType: 'country',
      scopeValue: country.trim(),
      summaries: summaryDtos,
      details: details,
    );
  }

  Future<ExportArtifact> exportDatabaseSnapshot() async {
    final now = _clock();
    final exportDir = await _ensureExportDirectory();
    final filePath = p.join(
      exportDir.path,
      'data-hook-claws-snapshot-${_fileTimestamp(now)}.db',
    );
    await _repository.copyDatabaseSnapshot(destinationPath: filePath);
    final artifact = ExportArtifact(
      path: filePath,
      format: ExportFormat.sqliteSnapshot,
      detailLevel: ExportDetailLevel.detailed,
      recordCount: await _repository.countFoods(),
      createdAt: now,
      scopeLabel: 'database-snapshot',
      mimeType: 'application/octet-stream',
    );
    await _recordExportHistory(artifact);
    return artifact;
  }

  Future<List<FoodDetails>> _loadDetails(List<FoodSummaryDto> summaries) async {
    final details = <FoodDetails>[];
    for (final summary in summaries) {
      final detail = await _repository.getFoodDetails(summary.id);
      if (detail != null) {
        details.add(detail);
      }
    }
    return details;
  }

  Future<ExportArtifact> _writeExport({
    required ExportFormat format,
    required ExportDetailLevel detailLevel,
    required String scopeType,
    required String scopeValue,
    required List<FoodSummaryDto> summaries,
    required List<FoodDetails> details,
  }) async {
    final now = _clock();
    final exportDir = await _ensureExportDirectory();
    final scopeSlug = _slug(scopeValue);
    final detailSlug = detailLevel.name;
    final extension = format == ExportFormat.json ? 'json' : 'csv';
    final filePath = p.join(
      exportDir.path,
      '$scopeType-$scopeSlug-$detailSlug-${_fileTimestamp(now)}.$extension',
    );

    final file = File(filePath);
    if (format == ExportFormat.json) {
      final payload = _jsonPayload(
        scopeType: scopeType,
        scopeValue: scopeValue,
        detailLevel: detailLevel,
        exportedAt: now,
        summaries: summaries,
        details: details,
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
    } else {
      final rows = _csvRows(
        detailLevel: detailLevel,
        summaries: summaries,
        details: details,
      );
      await file.writeAsString(csv.encode(rows), flush: true);
    }

    final artifact = ExportArtifact(
      path: filePath,
      format: format,
      detailLevel: detailLevel,
      recordCount: detailLevel == ExportDetailLevel.summary
          ? summaries.length
          : details.length,
      createdAt: now,
      scopeLabel: '$scopeType:$scopeValue',
      mimeType: format == ExportFormat.json ? 'application/json' : 'text/csv',
    );
    await _recordExportHistory(artifact);
    return artifact;
  }

  Map<String, Object?> _jsonPayload({
    required String scopeType,
    required String scopeValue,
    required ExportDetailLevel detailLevel,
    required DateTime exportedAt,
    required List<FoodSummaryDto> summaries,
    required List<FoodDetails> details,
  }) {
    return {
      'scope': scopeType,
      scopeType == 'country' ? 'country' : 'query': scopeValue,
      'detailLevel': detailLevel.name,
      'exportedAt': exportedAt.toIso8601String(),
      'recordCount': detailLevel == ExportDetailLevel.summary
          ? summaries.length
          : details.length,
      'foods': detailLevel == ExportDetailLevel.summary
          ? summaries.map((summary) => summary.toJson()).toList(growable: false)
          : details
                .map((detail) => FoodDetailsDto.fromDetails(detail).toJson())
                .toList(growable: false),
    };
  }

  List<List<Object?>> _csvRows({
    required ExportDetailLevel detailLevel,
    required List<FoodSummaryDto> summaries,
    required List<FoodDetails> details,
  }) {
    if (detailLevel == ExportDetailLevel.summary) {
      return [
        const [
          'id',
          'name',
          'category',
          'country',
          'sourceSummary',
          'description',
          'servingBasis',
          'lastUpdated',
        ],
        ...summaries.map(
          (summary) => [
            summary.id,
            summary.name,
            summary.category,
            summary.country,
            summary.sourceSummary,
            summary.description,
            summary.servingBasis,
            summary.lastUpdatedIso,
          ],
        ),
      ];
    }

    return [
      const [
        'id',
        'name',
        'category',
        'country',
        'sourceSummary',
        'description',
        'servingBasis',
        'lastUpdated',
        'aliasList',
        'sourceCount',
        'sourceNames',
        'sourceCountries',
        'mergeActions',
        'aggregatedNutrientsJson',
        'observationsJson',
        'mergeAuditJson',
      ],
      ...details.map((detail) {
        final dto = FoodDetailsDto.fromDetails(detail);
        return [
          dto.id,
          dto.displayName,
          dto.category,
          dto.countryHint,
          dto.sources.length > 1
              ? 'Merged official sources'
              : (dto.sources.isEmpty ? '' : dto.sources.first.sourceName),
          dto.description,
          dto.servingBasis,
          dto.lastAggregatedAtIso,
          dto.aliases.join('|'),
          dto.sources.length,
          dto.sources.map((source) => source.sourceName).join('|'),
          dto.sources.map((source) => source.country).toSet().join('|'),
          dto.sources
              .map((source) => source.mergeAudit?.action ?? '')
              .where((action) => action.isNotEmpty)
              .join('|'),
          jsonEncode(
            dto.aggregatedNutrients
                .map((nutrient) => nutrient.toJson())
                .toList(growable: false),
          ),
          jsonEncode(
            dto.observationsBySource.map(
              (key, value) => MapEntry(
                key,
                value.map((entry) => entry.toJson()).toList(growable: false),
              ),
            ),
          ),
          jsonEncode(
            dto.sources
                .where((source) => source.mergeAudit != null)
                .map((source) => source.mergeAudit!.toJson())
                .toList(growable: false),
          ),
        ];
      }),
    ];
  }

  Future<Directory> _ensureExportDirectory() async {
    final configuredPath = await _exportDirectoryPathResolver?.call();
    if (configuredPath != null && configuredPath.trim().isNotEmpty) {
      final configured = Directory(configuredPath.trim());
      if (!configured.existsSync()) {
        await configured.create(recursive: true);
      }
      return configured;
    }
    final documentsDirectory = await _documentsDirectoryResolver();
    final exportDirectory = Directory(
      p.join(documentsDirectory.path, 'exports'),
    );
    if (!exportDirectory.existsSync()) {
      await exportDirectory.create(recursive: true);
    }
    return exportDirectory;
  }

  Future<void> _recordExportHistory(ExportArtifact artifact) async {
    final summaryService = _exportSummaryService;
    final summary = summaryService == null
        ? 'Exported ${artifact.recordCount} records for ${artifact.scopeLabel}.'
        : await summaryService.summarize(
            scopeLabel: artifact.scopeLabel,
            format: artifact.format.name,
            detailLevel: artifact.detailLevel.name,
            recordCount: artifact.recordCount,
          );
    await _repository.addExportHistory(
      ExportHistoryEntry(
        id: 'export-${artifact.createdAt.microsecondsSinceEpoch}',
        path: artifact.path,
        format: artifact.format,
        detailLevel: artifact.detailLevel,
        recordCount: artifact.recordCount,
        scopeLabel: artifact.scopeLabel,
        createdAt: artifact.createdAt,
        status: 'success',
        summary: summary,
      ),
    );
  }

  String _fileTimestamp(DateTime value) {
    final iso = value.toIso8601String();
    return iso.replaceAll(':', '-');
  }

  String _slug(String value) {
    final cleaned = value.trim().toLowerCase();
    if (cleaned.isEmpty) {
      return 'all-local-foods';
    }
    final normalized = cleaned.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return normalized.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
