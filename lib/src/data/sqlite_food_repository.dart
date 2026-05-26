import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../api/export_models.dart';
import '../domain/canonical_merge_service.dart';
import '../domain/food_quality_service.dart';
import '../domain/normalization/text_normalizer.dart';
import '../models/ai_suggestion_log_entry.dart';
import '../models/dataset_artifact_entry.dart';
import '../models/export_history_entry.dart';
import '../models/fetch_job_entry.dart';
import '../models/food_details.dart';
import '../models/food_search_query.dart';
import '../models/food_item.dart';
import '../models/food_summary.dart';
import '../models/import_log_entry.dart';
import '../models/manual_governance.dart';
import '../models/merge_review_issue.dart';
import '../models/nutrient.dart';
import '../models/storage_paths.dart';
import 'food_repository.dart';

typedef DocumentsDirectoryResolver = Future<Directory> Function();

class SqliteFoodRepository implements FoodRepository {
  SqliteFoodRepository({
    DocumentsDirectoryResolver? documentsDirectoryResolver,
    String? databaseFileName,
  }) : _documentsDirectoryResolver =
           documentsDirectoryResolver ?? getApplicationDocumentsDirectory,
       _databaseFileName = databaseFileName ?? 'data_hook_claws.db';

  final DocumentsDirectoryResolver _documentsDirectoryResolver;
  final String _databaseFileName;
  final TextNormalizer _textNormalizer = const TextNormalizer();
  final CanonicalMergeService _mergeService = const CanonicalMergeService();
  final FoodQualityService _qualityService = FoodQualityService();

  Database? _database;
  String? _databasePath;

  @override
  Future<void> initialize() async {
    if (_database != null) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await _documentsDirectoryResolver();
    final databasePath = p.join(directory.path, _databaseFileName);
    _databasePath = databasePath;

    _database = await openDatabase(
      databasePath,
      version: 7,
      onCreate: (db, version) async {
        await _createLegacyTables(db);
        await _createProvenanceTables(db);
        await _createAppMetaTable(db);
        await _createExportHistoryTable(db);
        await _createManualGovernanceTables(db);
        await _setCanonicalMergeVersion(db, 1);
        await _setMergeAuditVersion(db, 1);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createImportLogsTable(db);
        }
        if (oldVersion < 3) {
          await _createProvenanceTables(db);
          await _backfillProvenanceTables(db);
        }
        if (oldVersion < 4) {
          await _createAppMetaTable(db);
        }
        if (oldVersion < 5) {
          await _createMergeAuditTables(db);
        }
        if (oldVersion < 6) {
          await _createExportHistoryTable(db);
        }
        if (oldVersion < 7) {
          await _createManualGovernanceTables(db);
        }
      },
      onOpen: (db) async {
        await _createExportHistoryTable(db);
        await _createManualGovernanceTables(db);
        await _backfillProvenanceTables(db);
        await _ensureCanonicalMergeState(db);
        await _ensureMergeAuditState(db);
      },
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('Repository used before initialize().');
    }
    return database;
  }

  @override
  Future<List<FoodItem>> getAllFoods() async {
    final foodRows = await _db.query(
      'foods',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return _hydrateFoods(foodRows);
  }

  @override
  Future<List<FoodItem>> searchFoods(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return getAllFoods();
    }

    final rows = await _db.rawQuery('''
      SELECT DISTINCT f.*
      FROM foods f
      LEFT JOIN food_tags t ON t.food_id = f.id
      LEFT JOIN food_alias a ON a.canonical_food_id = f.id
      WHERE lower(f.name) LIKE ?
         OR lower(f.category) LIKE ?
         OR lower(f.country) LIKE ?
         OR lower(f.source_name) LIKE ?
         OR lower(f.description) LIKE ?
         OR lower(IFNULL(t.tag, '')) LIKE ?
         OR lower(IFNULL(a.alias, '')) LIKE ?
      ORDER BY f.name COLLATE NOCASE ASC
      ''', List<String>.filled(7, '%$normalizedQuery%'));

    return _hydrateFoods(rows);
  }

  @override
  Future<List<FoodItem>> searchFoodsAdvanced(
    FoodSearchQuery query, {
    int limit = 100,
  }) async {
    final candidates = await _candidateFoodsForAdvancedSearch(query);
    final matched = <FoodItem>[];
    for (final item in candidates) {
      final details = await getFoodDetails(item.id);
      if (_qualityService.matchesAdvancedQuery(
        item: item,
        details: details,
        query: query,
      )) {
        matched.add(item);
      }
      if (matched.length >= limit) {
        break;
      }
    }
    return matched;
  }

  Future<List<FoodItem>> _candidateFoodsForAdvancedSearch(
    FoodSearchQuery query,
  ) async {
    if (query.text.trim().isEmpty) {
      return getAllFoods();
    }
    final normalizedQuery = _textNormalizer
        .aliasKey(query.text)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    final like = '%$normalizedQuery%';
    final rows = await _db.rawQuery('''
      SELECT DISTINCT f.*
      FROM foods f
      LEFT JOIN food_tags t ON t.food_id = f.id
      LEFT JOIN food_alias a ON a.canonical_food_id = f.id
      LEFT JOIN source_record s ON s.canonical_food_id = f.id
      WHERE lower(f.name) LIKE ?
         OR lower(f.category) LIKE ?
         OR lower(f.country) LIKE ?
         OR lower(f.source_name) LIKE ?
         OR lower(f.description) LIKE ?
         OR lower(IFNULL(t.tag, '')) LIKE ?
         OR lower(IFNULL(a.alias, '')) LIKE ?
         OR lower(IFNULL(s.record_title, '')) LIKE ?
         OR lower(IFNULL(s.record_description, '')) LIKE ?
      ORDER BY f.name COLLATE NOCASE ASC
      ''', List<String>.filled(9, like));
    return _hydrateFoods(rows);
  }

  @override
  Future<List<FoodSummary>> searchFoodSummaries(
    String query, {
    int limit = 20,
  }) async {
    final items = await searchFoods(query);
    return items
        .take(limit)
        .map(
          (item) => FoodSummary(
            id: item.id,
            name: item.name,
            category: item.category,
            country: item.country,
            sourceSummary: item.sourceName,
            description: item.description,
            servingBasis: item.servingBasis,
            lastUpdated: item.lastUpdated,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FoodSummary>> searchFoodSummariesAdvanced(
    FoodSearchQuery query, {
    int limit = 100,
  }) async {
    final items = await searchFoodsAdvanced(query, limit: limit);
    return items.map(_qualityService.summaryFromItem).toList(growable: false);
  }

  @override
  Future<List<FoodSummary>> searchFoodSummariesByCountry(
    String country, {
    int limit = 1000,
  }) async {
    final normalizedCountry = country.trim().toLowerCase();
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT f.*
      FROM foods f
      LEFT JOIN source_record s ON s.canonical_food_id = f.id
      WHERE lower(f.country) = ?
         OR lower(IFNULL(s.country, '')) = ?
      ORDER BY f.name COLLATE NOCASE ASC
      LIMIT ?
    ''',
      [normalizedCountry, normalizedCountry, limit],
    );

    return rows
        .map(
          (row) => FoodSummary(
            id: row['id']! as String,
            name: row['name']! as String,
            category: row['category']! as String,
            country: row['country']! as String,
            sourceSummary: row['source_name']! as String,
            description: row['description']! as String,
            servingBasis: row['serving_basis']! as String,
            lastUpdated: DateTime.parse(row['last_updated']! as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<FoodDetails?> getFoodDetails(String canonicalFoodId) async {
    final canonicalRows = await _db.query(
      'canonical_food',
      where: 'id = ?',
      whereArgs: [canonicalFoodId],
      limit: 1,
    );
    if (canonicalRows.isEmpty) {
      return null;
    }

    final canonical = canonicalRows.first;
    final sourceRows = await _db.query(
      'source_record',
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalFoodId],
      orderBy: 'fetched_at DESC',
    );
    final aliasRows = await _db.query(
      'food_alias',
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalFoodId],
      orderBy: 'alias COLLATE NOCASE ASC',
    );
    final foodRows = await _db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [canonicalFoodId],
      limit: 1,
    );

    final sourceIds = sourceRows.map((row) => row['id']! as String).toList();
    final mergeAuditsBySource = await _loadMergeAuditsBySource(sourceIds);
    final observations = <NutrientObservationView>[];
    if (sourceIds.isNotEmpty) {
      final placeholders = List<String>.filled(
        sourceIds.length,
        '?',
      ).join(', ');
      final observationRows = await _db.rawQuery(
        'SELECT * FROM nutrient_observation WHERE source_record_id IN ($placeholders) ORDER BY canonical_label COLLATE NOCASE ASC',
        sourceIds,
      );
      for (final row in observationRows) {
        observations.add(
          NutrientObservationView(
            sourceRecordId: row['source_record_id']! as String,
            label: row['label']! as String,
            canonicalLabel: row['canonical_label']! as String,
            amount: (row['amount']! as num).toDouble(),
            unit: row['unit']! as String,
            originalUnit: row['original_unit']! as String,
          ),
        );
      }
    }

    final aggregatedNutrients = foodRows.isEmpty
        ? const <Nutrient>[]
        : (await _hydrateFoods(foodRows)).single.nutrients;

    return FoodDetails(
      id: canonicalFoodId,
      displayName: canonical['display_name']! as String,
      category: canonical['canonical_category']! as String,
      countryHint: canonical['canonical_country_hint']! as String,
      description: canonical['description']! as String,
      servingBasis: canonical['serving_basis']! as String,
      lastAggregatedAt: DateTime.parse(
        canonical['last_aggregated_at']! as String,
      ),
      aliases: aliasRows
          .map((row) => row['alias']! as String)
          .toSet()
          .toList(growable: false),
      sourceRecords: sourceRows
          .map(
            (row) => SourceRecordView(
              id: row['id']! as String,
              importerId: row['importer_id']! as String,
              sourceName: row['source_name']! as String,
              sourceRecordId: row['source_record_id']! as String,
              country: row['country']! as String,
              recordTitle: row['record_title']! as String,
              recordDescription: row['record_description']! as String,
              fetchedAt: DateTime.parse(row['fetched_at']! as String),
              sourceUpdatedAt: DateTime.parse(
                row['source_updated_at']! as String,
              ),
              mergeAudit: mergeAuditsBySource[row['id']! as String],
            ),
          )
          .toList(growable: false),
      aggregatedNutrients: aggregatedNutrients,
      nutrientObservations: observations,
    );
  }

  @override
  Future<List<MergeReviewIssue>> getMergeReviewIssues({int limit = 100}) async {
    final foods = await getAllFoods();
    final issues = <MergeReviewIssue>[];
    for (final food in foods) {
      final details = await getFoodDetails(food.id);
      if (details == null) {
        continue;
      }
      issues.addAll(_qualityService.reviewIssuesForDetails(details));
    }
    issues.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return issues.take(limit).toList(growable: false);
  }

  @override
  Future<void> mergeSourceRecord({
    required String sourceRecordId,
    required String targetCanonicalFoodId,
    required String note,
  }) async {
    await _db.transaction((txn) async {
      final source = await _sourceRecordById(txn, sourceRecordId);
      if (source == null) {
        throw StateError('Source record not found: $sourceRecordId');
      }
      final targetRows = await txn.query(
        'canonical_food',
        where: 'id = ?',
        whereArgs: [targetCanonicalFoodId],
        limit: 1,
      );
      if (targetRows.isEmpty) {
        throw StateError(
          'Target canonical food not found: $targetCanonicalFoodId',
        );
      }
      final fromCanonicalId = source['canonical_food_id']! as String;
      if (fromCanonicalId == targetCanonicalFoodId) {
        return;
      }
      await txn.update(
        'source_record',
        {'canonical_food_id': targetCanonicalFoodId},
        where: 'id = ?',
        whereArgs: [sourceRecordId],
      );
      await _upsertAliasForSource(txn, targetCanonicalFoodId, source);
      await _upsertManualMergeAudit(
        txn,
        sourceRecordId: sourceRecordId,
        canonicalId: targetCanonicalFoodId,
        action: 'reuse',
        reason: note,
      );
      await _recordManualGovernance(
        txn,
        action: 'merge',
        sourceRecordId: sourceRecordId,
        fromCanonicalFoodId: fromCanonicalId,
        toCanonicalFoodId: targetCanonicalFoodId,
        note: note,
      );
      await _refreshCanonicalSnapshot(txn, targetCanonicalFoodId);
      await _cleanupOrRefreshCanonical(txn, fromCanonicalId);
    });
  }

  @override
  Future<void> splitSourceRecord({
    required String sourceRecordId,
    required String note,
  }) async {
    await _db.transaction((txn) async {
      final source = await _sourceRecordById(txn, sourceRecordId);
      if (source == null) {
        throw StateError('Source record not found: $sourceRecordId');
      }
      final fromCanonicalId = source['canonical_food_id']! as String;
      final fromCanonical = await _canonicalById(txn, fromCanonicalId);
      if (fromCanonical == null) {
        throw StateError('Canonical food not found: $fromCanonicalId');
      }
      final newCanonicalId = 'manual-split:$sourceRecordId';
      await txn.insert('canonical_food', {
        'id': newCanonicalId,
        'display_name': source['record_title']! as String,
        'canonical_category': fromCanonical['canonical_category']! as String,
        'canonical_country_hint': source['country']! as String,
        'description': source['record_description']! as String,
        'serving_basis': fromCanonical['serving_basis']! as String,
        'last_aggregated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update(
        'source_record',
        {'canonical_food_id': newCanonicalId},
        where: 'id = ?',
        whereArgs: [sourceRecordId],
      );
      await _upsertAliasForSource(txn, newCanonicalId, source);
      await _upsertManualMergeAudit(
        txn,
        sourceRecordId: sourceRecordId,
        canonicalId: newCanonicalId,
        action: 'create',
        reason: note,
      );
      await _recordManualGovernance(
        txn,
        action: 'split',
        sourceRecordId: sourceRecordId,
        fromCanonicalFoodId: fromCanonicalId,
        toCanonicalFoodId: newCanonicalId,
        note: note,
      );
      await _refreshCanonicalSnapshot(txn, newCanonicalId);
      await _cleanupOrRefreshCanonical(txn, fromCanonicalId);
    });
  }

  @override
  Future<void> overrideCanonicalFood({
    required String canonicalFoodId,
    required CanonicalOverrideFields fields,
    required String note,
  }) async {
    if (fields.isEmpty) {
      return;
    }
    await _db.transaction((txn) async {
      final canonical = await _canonicalById(txn, canonicalFoodId);
      if (canonical == null) {
        throw StateError('Canonical food not found: $canonicalFoodId');
      }
      await txn.insert('manual_canonical_override', {
        'canonical_food_id': canonicalFoodId,
        'display_name': fields.displayName,
        'canonical_category': fields.category,
        'canonical_country_hint': fields.countryHint,
        'description': fields.description,
        'serving_basis': fields.servingBasis,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _recordManualGovernance(
        txn,
        action: 'override',
        sourceRecordId: '',
        fromCanonicalFoodId: canonicalFoodId,
        toCanonicalFoodId: canonicalFoodId,
        note: note,
      );
      await _refreshCanonicalSnapshot(txn, canonicalFoodId);
    });
  }

  @override
  Future<List<ManualGovernanceLogEntry>> getManualGovernanceLogs({
    int limit = 50,
  }) async {
    final rows = await _db.query(
      'manual_governance_log',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_mapManualGovernanceLog).toList(growable: false);
  }

  @override
  Future<int> countFoods() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS count FROM foods');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> upsertFoods(List<FoodItem> incomingItems) async {
    await _db.transaction((txn) async {
      for (final item in incomingItems) {
        await _mergeAndUpsertItem(txn, item);
      }
    });
  }

  @override
  Future<void> addImportLog(ImportLogEntry entry) async {
    await _db.insert('import_logs', {
      'id': entry.id,
      'importer_id': entry.importerId,
      'source_name': entry.sourceName,
      'status': entry.status,
      'imported_count': entry.importedCount,
      'query': entry.query,
      'message': entry.message,
      'created_at': entry.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ImportLogEntry>> getImportLogs({int limit = 20}) async {
    final rows = await _db.query(
      'import_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => ImportLogEntry(
            id: row['id']! as String,
            importerId: row['importer_id']! as String,
            sourceName: row['source_name']! as String,
            status: row['status']! as String,
            importedCount: row['imported_count']! as int,
            query: row['query']! as String,
            message: row['message']! as String,
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsertFetchJob(FetchJobEntry entry) async {
    await _db.insert('fetch_job', {
      'id': entry.id,
      'query': entry.query,
      'phase': entry.phase,
      'status': entry.status,
      'importer_id': entry.importerId,
      'started_at': entry.startedAt.toIso8601String(),
      'finished_at': entry.finishedAt?.toIso8601String(),
      'message': entry.message,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<FetchJobEntry>> getRecentFetchJobs({
    String? query,
    String? phase,
    String? importerId,
    String? status,
    int limit = 20,
  }) async {
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (query != null) {
      where.add('query = ?');
      whereArgs.add(query);
    }
    if (phase != null) {
      where.add('phase = ?');
      whereArgs.add(phase);
    }
    if (importerId != null) {
      where.add('importer_id = ?');
      whereArgs.add(importerId);
    }
    if (status != null) {
      where.add('status = ?');
      whereArgs.add(status);
    }

    final rows = await _db.query(
      'fetch_job',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(_mapFetchJob).toList(growable: false);
  }

  @override
  Future<FetchJobEntry?> getLatestFetchJobForQuery({
    required String query,
    required String phase,
  }) async {
    final rows = await getRecentFetchJobs(query: query, phase: phase, limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  @override
  Future<void> addAiSuggestionLog(AiSuggestionLogEntry entry) async {
    await _db.insert('ai_suggestion_log', {
      'id': entry.id,
      'query': entry.query,
      'suggestion_type': entry.suggestionType,
      'input_payload': entry.inputPayload,
      'output_payload': entry.outputPayload,
      'model_name': entry.modelName,
      'created_at': entry.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<AiSuggestionLogEntry>> getAiSuggestionLogs({
    int limit = 20,
  }) async {
    final rows = await _db.query(
      'ai_suggestion_log',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (row) => AiSuggestionLogEntry(
            id: row['id']! as String,
            query: row['query']! as String,
            suggestionType: row['suggestion_type']! as String,
            inputPayload: row['input_payload']! as String,
            outputPayload: row['output_payload']! as String,
            modelName: row['model_name']! as String,
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String?> getAppMeta(String key) async {
    final rows = await _db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value']! as String;
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    await _db.insert('app_meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> upsertDatasetArtifact(DatasetArtifactEntry entry) async {
    await _db.insert('dataset_artifact', {
      'id': entry.id,
      'importer_id': entry.importerId,
      'artifact_type': entry.artifactType,
      'local_path': entry.localPath,
      'source_url': entry.sourceUrl,
      'source_version': entry.sourceVersion,
      'fetched_at': entry.fetchedAt.toIso8601String(),
      'status': entry.status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<DatasetArtifactEntry>> getDatasetArtifacts({
    int limit = 50,
  }) async {
    final rows = await _db.query(
      'dataset_artifact',
      orderBy: 'fetched_at DESC',
      limit: limit,
    );
    return rows.map(_mapDatasetArtifact).toList(growable: false);
  }

  @override
  Future<void> markDatasetArtifactRemoved(String id) async {
    await _db.update(
      'dataset_artifact',
      {'status': 'removed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<StoragePaths> getStoragePaths() async {
    final documents = await _documentsDirectoryResolver();
    return StoragePaths(
      databasePath: _databasePath ?? '',
      documentsPath: documents.path,
      exportsPath: p.join(documents.path, 'exports'),
      cachePath: p.join(documents.path, 'cache'),
    );
  }

  @override
  Future<void> copyDatabaseSnapshot({required String destinationPath}) async {
    final sourcePath = _databasePath;
    if (sourcePath == null) {
      throw StateError('Database path is unavailable before initialize().');
    }
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw StateError('Database snapshot source does not exist.');
    }

    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    await sourceFile.copy(destinationFile.path);
  }

  @override
  Future<void> addExportHistory(ExportHistoryEntry entry) async {
    await _db.insert('export_history', {
      'id': entry.id,
      'path': entry.path,
      'format': entry.format.name,
      'detail_level': entry.detailLevel.name,
      'record_count': entry.recordCount,
      'scope_label': entry.scopeLabel,
      'created_at': entry.createdAt.toIso8601String(),
      'status': entry.status,
      'summary': entry.summary,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ExportHistoryEntry>> getExportHistory({int limit = 20}) async {
    final rows = await _db.query(
      'export_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_mapExportHistory).toList(growable: false);
  }

  DatasetArtifactEntry _mapDatasetArtifact(Map<String, Object?> row) {
    return DatasetArtifactEntry(
      id: row['id']! as String,
      importerId: row['importer_id']! as String,
      artifactType: row['artifact_type']! as String,
      localPath: row['local_path']! as String,
      sourceUrl: row['source_url']! as String,
      sourceVersion: row['source_version']! as String,
      fetchedAt: DateTime.parse(row['fetched_at']! as String),
      status: row['status']! as String,
    );
  }

  ExportHistoryEntry _mapExportHistory(Map<String, Object?> row) {
    return ExportHistoryEntry(
      id: row['id']! as String,
      path: row['path']! as String,
      format: ExportFormat.values.byName(row['format']! as String),
      detailLevel: ExportDetailLevel.values.byName(
        row['detail_level']! as String,
      ),
      recordCount: row['record_count']! as int,
      scopeLabel: row['scope_label']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      status: row['status']! as String,
      summary: row['summary']! as String,
    );
  }

  ManualGovernanceLogEntry _mapManualGovernanceLog(Map<String, Object?> row) {
    return ManualGovernanceLogEntry(
      id: row['id']! as String,
      action: row['action']! as String,
      sourceRecordId: row['source_record_id']! as String,
      fromCanonicalFoodId: row['from_canonical_food_id']! as String,
      toCanonicalFoodId: row['to_canonical_food_id']! as String,
      note: row['note']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }

  Future<void> _createLegacyTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE foods(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        country TEXT NOT NULL,
        source_name TEXT NOT NULL,
        description TEXT NOT NULL,
        serving_basis TEXT NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_tags(
        food_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY(food_id, tag)
      )
    ''');

    await db.execute('''
      CREATE TABLE nutrients(
        food_id TEXT NOT NULL,
        label TEXT NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        PRIMARY KEY(food_id, label)
      )
    ''');

    await _createImportLogsTable(db);
  }

  Future<void> _createImportLogsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_logs(
        id TEXT PRIMARY KEY,
        importer_id TEXT NOT NULL,
        source_name TEXT NOT NULL,
        status TEXT NOT NULL,
        imported_count INTEGER NOT NULL,
        query TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createProvenanceTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS canonical_food(
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        canonical_category TEXT NOT NULL,
        canonical_country_hint TEXT NOT NULL,
        description TEXT NOT NULL,
        serving_basis TEXT NOT NULL,
        last_aggregated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS source_record(
        id TEXT PRIMARY KEY,
        canonical_food_id TEXT NOT NULL,
        importer_id TEXT NOT NULL,
        source_name TEXT NOT NULL,
        source_record_id TEXT NOT NULL,
        country TEXT NOT NULL,
        record_title TEXT NOT NULL,
        record_description TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        source_updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS nutrient_observation(
        id TEXT PRIMARY KEY,
        source_record_id TEXT NOT NULL,
        label TEXT NOT NULL,
        canonical_label TEXT NOT NULL,
        amount REAL NOT NULL,
        unit TEXT NOT NULL,
        original_unit TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_alias(
        id TEXT PRIMARY KEY,
        canonical_food_id TEXT NOT NULL,
        alias TEXT NOT NULL,
        alias_key TEXT NOT NULL,
        locale TEXT NOT NULL,
        source TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dataset_artifact(
        id TEXT PRIMARY KEY,
        importer_id TEXT NOT NULL,
        artifact_type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        source_url TEXT NOT NULL,
        source_version TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fetch_job(
        id TEXT PRIMARY KEY,
        query TEXT NOT NULL,
        phase TEXT NOT NULL,
        status TEXT NOT NULL,
        importer_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        message TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_suggestion_log(
        id TEXT PRIMARY KEY,
        query TEXT NOT NULL,
        suggestion_type TEXT NOT NULL,
        input_payload TEXT NOT NULL,
        output_payload TEXT NOT NULL,
        model_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _createMergeAuditTables(db);
  }

  Future<void> _createMergeAuditTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS merge_audit(
        id TEXT PRIMARY KEY,
        source_record_id TEXT NOT NULL,
        canonical_food_id TEXT NOT NULL,
        action TEXT NOT NULL,
        confidence REAL NOT NULL,
        matched_by TEXT NOT NULL,
        reason TEXT NOT NULL,
        item_alias_key TEXT NOT NULL,
        item_category_key TEXT NOT NULL,
        item_serving_key TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS merge_audit_candidate(
        id TEXT PRIMARY KEY,
        merge_audit_id TEXT NOT NULL,
        candidate_canonical_food_id TEXT NOT NULL,
        alias_matched INTEGER NOT NULL,
        category_matched INTEGER NOT NULL,
        serving_matched INTEGER NOT NULL,
        nutrient_similarity REAL NOT NULL,
        accepted INTEGER NOT NULL,
        reason TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAppMetaTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_meta(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createExportHistoryTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS export_history(
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        format TEXT NOT NULL,
        detail_level TEXT NOT NULL,
        record_count INTEGER NOT NULL,
        scope_label TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        summary TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createManualGovernanceTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS manual_governance_log(
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        source_record_id TEXT NOT NULL,
        from_canonical_food_id TEXT NOT NULL,
        to_canonical_food_id TEXT NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS manual_canonical_override(
        canonical_food_id TEXT PRIMARY KEY,
        display_name TEXT,
        canonical_category TEXT,
        canonical_country_hint TEXT,
        description TEXT,
        serving_basis TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _backfillProvenanceTables(DatabaseExecutor db) async {
    final existing = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM canonical_food',
    );
    if ((Sqflite.firstIntValue(existing) ?? 0) > 0) {
      return;
    }

    final foodRows = await db.query('foods');
    if (foodRows.isEmpty) {
      return;
    }

    final nutrientRows = await db.query('nutrients');
    final tagRows = await db.query('food_tags');

    final nutrientsByFood = <String, List<Map<String, Object?>>>{};
    for (final row in nutrientRows) {
      final foodId = row['food_id']! as String;
      nutrientsByFood.putIfAbsent(foodId, () => []).add(row);
    }

    final tagsByFood = <String, List<String>>{};
    for (final row in tagRows) {
      final foodId = row['food_id']! as String;
      tagsByFood.putIfAbsent(foodId, () => []).add(row['tag']! as String);
    }

    final batch = db.batch();
    for (final row in foodRows) {
      final foodId = row['id']! as String;
      batch.insert('canonical_food', {
        'id': foodId,
        'display_name': row['name']! as String,
        'canonical_category': row['category']! as String,
        'canonical_country_hint': row['country']! as String,
        'description': row['description']! as String,
        'serving_basis': row['serving_basis']! as String,
        'last_aggregated_at': row['last_updated']! as String,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      final sourceRecordId = '$foodId:legacy';
      batch.insert('source_record', {
        'id': sourceRecordId,
        'canonical_food_id': foodId,
        'importer_id': foodId.split(':').first,
        'source_name': row['source_name']! as String,
        'source_record_id': foodId,
        'country': row['country']! as String,
        'record_title': row['name']! as String,
        'record_description': row['description']! as String,
        'fetched_at': row['last_updated']! as String,
        'source_updated_at': row['last_updated']! as String,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      for (final nutrient in nutrientsByFood[foodId] ?? const []) {
        final label = nutrient['label']! as String;
        batch.insert('nutrient_observation', {
          'id': '$sourceRecordId:$label',
          'source_record_id': sourceRecordId,
          'label': label,
          'canonical_label': label,
          'amount': nutrient['amount']! as num,
          'unit': nutrient['unit']! as String,
          'original_unit': nutrient['unit']! as String,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final aliases = <String>{
        row['name']! as String,
        ...tagsByFood[foodId] ?? const [],
      };
      for (final alias in aliases) {
        batch.insert('food_alias', {
          'id': '$foodId:${_textNormalizer.aliasKey(alias)}',
          'canonical_food_id': foodId,
          'alias': alias,
          'alias_key': _textNormalizer.aliasKey(alias),
          'locale': 'und',
          'source': 'migration',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> _ensureCanonicalMergeState(DatabaseExecutor db) async {
    await _createAppMetaTable(db);
    final version = await _getCanonicalMergeVersion(db);
    if (version >= 1) {
      return;
    }

    try {
      await _rebuildCanonicalState(db);
      await _setCanonicalMergeVersion(db, 1);
    } catch (error) {
      stderr.writeln('Canonical rebuild failed: $error');
    }
  }

  Future<void> _ensureMergeAuditState(DatabaseExecutor db) async {
    await _createMergeAuditTables(db);
    final version = await _getMergeAuditVersion(db);
    if (version >= 1) {
      return;
    }

    try {
      await _rebuildMergeAudits(db);
      await _setMergeAuditVersion(db, 1);
    } catch (error) {
      stderr.writeln('Merge audit rebuild failed: $error');
    }
  }

  Future<int> _getCanonicalMergeVersion(DatabaseExecutor db) async {
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['canonical_merge_version'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return 0;
    }
    return int.tryParse(rows.first['value']! as String) ?? 0;
  }

  Future<void> _setCanonicalMergeVersion(
    DatabaseExecutor db,
    int version,
  ) async {
    await db.insert('app_meta', {
      'key': 'canonical_merge_version',
      'value': '$version',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> _getMergeAuditVersion(DatabaseExecutor db) async {
    final rows = await db.query(
      'app_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['merge_audit_version'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return 0;
    }
    return int.tryParse(rows.first['value']! as String) ?? 0;
  }

  Future<void> _setMergeAuditVersion(DatabaseExecutor db, int version) async {
    await db.insert('app_meta', {
      'key': 'merge_audit_version',
      'value': '$version',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _rebuildCanonicalState(DatabaseExecutor db) async {
    final existingFoods = await _hydrateFoodsWithDb(
      db,
      await db.query('foods'),
    );
    if (db is! Database) {
      throw StateError('Canonical rebuild requires a database instance.');
    }

    await db.transaction((txn) async {
      await txn.delete('canonical_food');
      await txn.delete('source_record');
      await txn.delete('nutrient_observation');
      await txn.delete('food_alias');
      await txn.delete('merge_audit');
      await txn.delete('merge_audit_candidate');
      await txn.delete('foods');
      await txn.delete('food_tags');
      await txn.delete('nutrients');

      for (final item in existingFoods) {
        await _mergeAndUpsertItem(txn, item);
      }
    });
  }

  Future<void> _rebuildMergeAudits(DatabaseExecutor db) async {
    final sourceRows = await db.query(
      'source_record',
      orderBy: 'fetched_at ASC, id ASC',
    );
    if (sourceRows.isEmpty) {
      return;
    }

    final sourceIds = sourceRows.map((row) => row['id']! as String).toList();
    final aliasRows = await db.query(
      'food_alias',
      orderBy: 'alias COLLATE NOCASE ASC',
    );
    final aliasByCanonical = <String, Set<String>>{};
    for (final row in aliasRows) {
      final canonicalId = row['canonical_food_id']! as String;
      aliasByCanonical
          .putIfAbsent(canonicalId, () => <String>{})
          .add(row['alias']! as String);
    }

    final observationsBySource = <String, List<Nutrient>>{};
    if (sourceIds.isNotEmpty) {
      final placeholders = List<String>.filled(
        sourceIds.length,
        '?',
      ).join(', ');
      final observationRows = await db.rawQuery(
        'SELECT * FROM nutrient_observation WHERE source_record_id IN ($placeholders) ORDER BY canonical_label COLLATE NOCASE ASC',
        sourceIds,
      );
      for (final row in observationRows) {
        final sourceId = row['source_record_id']! as String;
        observationsBySource
            .putIfAbsent(sourceId, () => <Nutrient>[])
            .add(
              Nutrient(
                label: row['canonical_label']! as String,
                amount: (row['amount']! as num).toDouble(),
                unit: row['unit']! as String,
              ),
            );
      }
    }

    await db.delete('merge_audit_candidate');
    await db.delete('merge_audit');

    final replayed = <String, _ReplayCanonicalCandidate>{};
    for (final row in sourceRows) {
      final sourceId = row['id']! as String;
      final item = FoodItem(
        id: sourceId,
        name: row['record_title']! as String,
        category: await _canonicalCategoryForSource(db, row),
        country: row['country']! as String,
        sourceName: row['source_name']! as String,
        description: row['record_description']! as String,
        servingBasis: await _servingBasisForSource(db, row),
        tags:
            aliasByCanonical[row['canonical_food_id']! as String]
                ?.where((alias) => alias != row['record_title']! as String)
                .toList(growable: false) ??
            const <String>[],
        nutrients: observationsBySource[sourceId] ?? const <Nutrient>[],
        lastUpdated: DateTime.parse(row['source_updated_at']! as String),
      );
      final audit = _mergeService.decide(
        item: item,
        candidates: replayed.values
            .map(
              (candidate) => CanonicalMergeCandidate(
                canonicalFoodId: candidate.canonicalFoodId,
                categoryKey: candidate.categoryKey,
                servingKey: candidate.servingKey,
                aliasKeys: candidate.aliasKeys,
                nutrients: candidate.nutrients,
              ),
            )
            .toList(growable: false),
      );
      final canonicalId = row['canonical_food_id']! as String;
      await _upsertMergeAudit(
        db,
        sourceRecordId: sourceId,
        canonicalId: canonicalId,
        audit: CanonicalMergeAudit(
          decision: CanonicalMergeDecision(
            action: audit.decision.action,
            canonicalFoodId: canonicalId,
            confidence: audit.decision.confidence,
            matchedBy: audit.decision.matchedBy,
            reason: audit.decision.reason,
          ),
          itemAliasKey: audit.itemAliasKey,
          itemCategoryKey: audit.itemCategoryKey,
          itemServingKey: audit.itemServingKey,
          candidateEvaluations: audit.candidateEvaluations
              .map(
                (evaluation) => evaluation.copyWith(
                  reason:
                      evaluation.canonicalFoodId == canonicalId &&
                          audit.decision.action == CanonicalMergeAction.reuse
                      ? audit.decision.reason
                      : evaluation.reason,
                ),
              )
              .toList(growable: false),
        ),
      );
      final replayCandidate = replayed.putIfAbsent(
        canonicalId,
        () => _ReplayCanonicalCandidate(
          canonicalFoodId: canonicalId,
          categoryKey: _mergeService.categoryKey(item.category),
          servingKey: _mergeService.servingKey(item.servingBasis),
          aliasKeys: <String>{},
          nutrients: item.nutrients,
        ),
      );
      replayCandidate.aliasKeys.add(_mergeService.aliasKey(item.name));
      for (final tag in item.tags) {
        replayCandidate.aliasKeys.add(_mergeService.aliasKey(tag));
      }
      replayCandidate.nutrients = item.nutrients;
    }
  }

  Future<String> _canonicalCategoryForSource(
    DatabaseExecutor db,
    Map<String, Object?> sourceRow,
  ) async {
    final canonicalRows = await db.query(
      'canonical_food',
      columns: ['canonical_category'],
      where: 'id = ?',
      whereArgs: [sourceRow['canonical_food_id']! as String],
      limit: 1,
    );
    if (canonicalRows.isEmpty) {
      return '';
    }
    return canonicalRows.single['canonical_category']! as String;
  }

  Future<String> _servingBasisForSource(
    DatabaseExecutor db,
    Map<String, Object?> sourceRow,
  ) async {
    final canonicalRows = await db.query(
      'canonical_food',
      columns: ['serving_basis'],
      where: 'id = ?',
      whereArgs: [sourceRow['canonical_food_id']! as String],
      limit: 1,
    );
    if (canonicalRows.isEmpty) {
      return '';
    }
    return canonicalRows.single['serving_basis']! as String;
  }

  Future<Map<String, MergeAuditView>> _loadMergeAuditsBySource(
    List<String> sourceIds,
  ) async {
    if (sourceIds.isEmpty) {
      return const {};
    }

    final placeholders = List<String>.filled(sourceIds.length, '?').join(', ');
    final auditRows = await _db.rawQuery(
      'SELECT * FROM merge_audit WHERE source_record_id IN ($placeholders) ORDER BY created_at DESC',
      sourceIds,
    );
    if (auditRows.isEmpty) {
      return const {};
    }

    final auditIds = auditRows.map((row) => row['id']! as String).toList();
    final candidatePlaceholders = List<String>.filled(
      auditIds.length,
      '?',
    ).join(', ');
    final candidateRows = await _db.rawQuery(
      'SELECT * FROM merge_audit_candidate WHERE merge_audit_id IN ($candidatePlaceholders) ORDER BY id ASC',
      auditIds,
    );
    final candidatesByAudit = <String, List<MergeCandidateEvaluationView>>{};
    for (final row in candidateRows) {
      final auditId = row['merge_audit_id']! as String;
      candidatesByAudit
          .putIfAbsent(auditId, () => <MergeCandidateEvaluationView>[])
          .add(
            MergeCandidateEvaluationView(
              candidateCanonicalFoodId:
                  row['candidate_canonical_food_id']! as String,
              aliasMatched: (row['alias_matched']! as int) == 1,
              categoryMatched: (row['category_matched']! as int) == 1,
              servingMatched: (row['serving_matched']! as int) == 1,
              nutrientSimilarity: (row['nutrient_similarity']! as num)
                  .toDouble(),
              accepted: (row['accepted']! as int) == 1,
              reason: row['reason']! as String,
            ),
          );
    }

    final result = <String, MergeAuditView>{};
    for (final row in auditRows) {
      final sourceId = row['source_record_id']! as String;
      final auditId = row['id']! as String;
      result[sourceId] = MergeAuditView(
        sourceRecordId: sourceId,
        action: row['action']! as String,
        confidence: (row['confidence']! as num).toDouble(),
        matchedBy: row['matched_by']! as String,
        reason: row['reason']! as String,
        itemAliasKey: row['item_alias_key']! as String,
        itemCategoryKey: row['item_category_key']! as String,
        itemServingKey: row['item_serving_key']! as String,
        candidateEvaluations:
            candidatesByAudit[auditId] ??
            const <MergeCandidateEvaluationView>[],
        createdAt: DateTime.parse(row['created_at']! as String),
      );
    }
    return result;
  }

  Future<void> _mergeAndUpsertItem(DatabaseExecutor db, FoodItem item) async {
    final audit = await _resolveCanonicalDecision(db, item);
    final canonicalId = audit.decision.canonicalFoodId;
    await _ensureCanonicalBase(db, canonicalId, item);
    await _upsertSourceRecord(db, canonicalId, item);
    await _upsertObservations(db, item);
    await _upsertAliases(db, canonicalId, item);
    await _upsertMergeAudit(
      db,
      sourceRecordId: item.id,
      canonicalId: canonicalId,
      audit: audit,
    );
    await _refreshCanonicalSnapshot(db, canonicalId);
  }

  Future<void> _ensureCanonicalBase(
    DatabaseExecutor db,
    String canonicalId,
    FoodItem item,
  ) async {
    final rows = await db.query(
      'canonical_food',
      where: 'id = ?',
      whereArgs: [canonicalId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return;
    }
    await db.insert('canonical_food', {
      'id': canonicalId,
      'display_name': item.name,
      'canonical_category': item.category,
      'canonical_country_hint': item.country,
      'description': item.description,
      'serving_basis': item.servingBasis,
      'last_aggregated_at': item.lastUpdated.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CanonicalMergeAudit> _resolveCanonicalDecision(
    DatabaseExecutor db,
    FoodItem item,
  ) async {
    final itemAliasKey = _mergeService.aliasKey(item.name);
    final aliasRows = await db.query(
      'food_alias',
      where: 'alias_key = ?',
      whereArgs: [itemAliasKey],
    );
    final canonicalIds = aliasRows
        .map((row) => row['canonical_food_id']! as String)
        .toSet()
        .toList(growable: false);

    final candidates = <CanonicalMergeCandidate>[];
    for (final canonicalId in canonicalIds) {
      final foodRows = await db.query(
        'foods',
        where: 'id = ?',
        whereArgs: [canonicalId],
        limit: 1,
      );
      if (foodRows.isEmpty) {
        continue;
      }
      final aliases = await db.query(
        'food_alias',
        columns: ['alias'],
        where: 'canonical_food_id = ?',
        whereArgs: [canonicalId],
      );
      final snapshot = (await _hydrateFoodsWithDb(db, foodRows)).single;
      candidates.add(
        CanonicalMergeCandidate(
          canonicalFoodId: canonicalId,
          categoryKey: _mergeService.categoryKey(snapshot.category),
          servingKey: _mergeService.servingKey(snapshot.servingBasis),
          aliasKeys: aliases
              .map((row) => _mergeService.aliasKey(row['alias']! as String))
              .toSet(),
          nutrients: snapshot.nutrients,
        ),
      );
    }

    return _mergeService.decide(item: item, candidates: candidates);
  }

  Future<void> _upsertMergeAudit(
    DatabaseExecutor db, {
    required String sourceRecordId,
    required String canonicalId,
    required CanonicalMergeAudit audit,
  }) async {
    final auditId = 'merge-audit:$sourceRecordId';
    final existingRows = await db.query(
      'merge_audit',
      columns: ['id'],
      where: 'source_record_id = ?',
      whereArgs: [sourceRecordId],
    );
    final staleIds = existingRows
        .map((row) => row['id']! as String)
        .where((id) => id != auditId)
        .toList(growable: false);
    for (final staleId in staleIds) {
      await db.delete(
        'merge_audit_candidate',
        where: 'merge_audit_id = ?',
        whereArgs: [staleId],
      );
      await db.delete('merge_audit', where: 'id = ?', whereArgs: [staleId]);
    }

    await db.delete(
      'merge_audit_candidate',
      where: 'merge_audit_id = ?',
      whereArgs: [auditId],
    );
    await db.insert('merge_audit', {
      'id': auditId,
      'source_record_id': sourceRecordId,
      'canonical_food_id': canonicalId,
      'action': audit.decision.action.name,
      'confidence': audit.decision.confidence,
      'matched_by': audit.decision.matchedBy,
      'reason': audit.decision.reason,
      'item_alias_key': audit.itemAliasKey,
      'item_category_key': audit.itemCategoryKey,
      'item_serving_key': audit.itemServingKey,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (var index = 0; index < audit.candidateEvaluations.length; index++) {
      final candidate = audit.candidateEvaluations[index];
      await db.insert('merge_audit_candidate', {
        'id': '$auditId:$index',
        'merge_audit_id': auditId,
        'candidate_canonical_food_id': candidate.canonicalFoodId,
        'alias_matched': candidate.aliasMatched ? 1 : 0,
        'category_matched': candidate.categoryMatched ? 1 : 0,
        'serving_matched': candidate.servingMatched ? 1 : 0,
        'nutrient_similarity': candidate.nutrientSimilarity,
        'accepted': candidate.accepted ? 1 : 0,
        'reason': candidate.reason,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _upsertManualMergeAudit(
    DatabaseExecutor db, {
    required String sourceRecordId,
    required String canonicalId,
    required String action,
    required String reason,
  }) async {
    final auditId = 'merge-audit:$sourceRecordId';
    await db.delete(
      'merge_audit_candidate',
      where: 'merge_audit_id = ?',
      whereArgs: [auditId],
    );
    await db.insert('merge_audit', {
      'id': auditId,
      'source_record_id': sourceRecordId,
      'canonical_food_id': canonicalId,
      'action': action,
      'confidence': 1.0,
      'matched_by': 'manual-governance',
      'reason': reason,
      'item_alias_key': '',
      'item_category_key': '',
      'item_serving_key': '',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> _sourceRecordById(
    DatabaseExecutor db,
    String sourceRecordId,
  ) async {
    final rows = await db.query(
      'source_record',
      where: 'id = ?',
      whereArgs: [sourceRecordId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<Map<String, Object?>?> _canonicalById(
    DatabaseExecutor db,
    String canonicalId,
  ) async {
    final rows = await db.query(
      'canonical_food',
      where: 'id = ?',
      whereArgs: [canonicalId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> _upsertAliasForSource(
    DatabaseExecutor db,
    String canonicalId,
    Map<String, Object?> source,
  ) async {
    final alias = source['record_title']! as String;
    if (alias.trim().isEmpty) {
      return;
    }
    await db.insert('food_alias', {
      'id': '$canonicalId:${_textNormalizer.aliasKey(alias)}',
      'canonical_food_id': canonicalId,
      'alias': alias,
      'alias_key': _textNormalizer.aliasKey(alias),
      'locale': 'und',
      'source': 'manual-governance',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _recordManualGovernance(
    DatabaseExecutor db, {
    required String action,
    required String sourceRecordId,
    required String fromCanonicalFoodId,
    required String toCanonicalFoodId,
    required String note,
  }) async {
    final now = DateTime.now();
    await db.insert('manual_governance_log', {
      'id': 'manual-${now.microsecondsSinceEpoch}',
      'action': action,
      'source_record_id': sourceRecordId,
      'from_canonical_food_id': fromCanonicalFoodId,
      'to_canonical_food_id': toCanonicalFoodId,
      'note': note,
      'created_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _cleanupOrRefreshCanonical(
    DatabaseExecutor db,
    String canonicalId,
  ) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) AS count FROM source_record WHERE canonical_food_id = ?',
        [canonicalId],
      ),
    );
    if ((count ?? 0) > 0) {
      await _refreshCanonicalSnapshot(db, canonicalId);
      return;
    }
    await db.delete(
      'manual_canonical_override',
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalId],
    );
    await db.delete(
      'food_alias',
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalId],
    );
    await db.delete(
      'canonical_food',
      where: 'id = ?',
      whereArgs: [canonicalId],
    );
    await db.delete('foods', where: 'id = ?', whereArgs: [canonicalId]);
    await db.delete(
      'food_tags',
      where: 'food_id = ?',
      whereArgs: [canonicalId],
    );
    await db.delete(
      'nutrients',
      where: 'food_id = ?',
      whereArgs: [canonicalId],
    );
  }

  Future<void> _upsertSourceRecord(
    DatabaseExecutor db,
    String canonicalId,
    FoodItem item,
  ) async {
    await db.insert('source_record', {
      'id': item.id,
      'canonical_food_id': canonicalId,
      'importer_id': item.id.split(':').first,
      'source_name': item.sourceName,
      'source_record_id': item.id,
      'country': item.country,
      'record_title': item.name,
      'record_description': item.description,
      'fetched_at': DateTime.now().toIso8601String(),
      'source_updated_at': item.lastUpdated.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertObservations(DatabaseExecutor db, FoodItem item) async {
    await db.delete(
      'nutrient_observation',
      where: 'source_record_id = ?',
      whereArgs: [item.id],
    );
    for (final nutrient in item.nutrients) {
      await db.insert('nutrient_observation', {
        'id': '${item.id}:${nutrient.label}',
        'source_record_id': item.id,
        'label': nutrient.label,
        'canonical_label': nutrient.label,
        'amount': nutrient.amount,
        'unit': nutrient.unit,
        'original_unit': nutrient.unit,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _upsertAliases(
    DatabaseExecutor db,
    String canonicalId,
    FoodItem item,
  ) async {
    for (final alias in {item.name, ...item.tags}) {
      await db.insert('food_alias', {
        'id': '$canonicalId:${_textNormalizer.aliasKey(alias)}',
        'canonical_food_id': canonicalId,
        'alias': alias,
        'alias_key': _textNormalizer.aliasKey(alias),
        'locale': 'und',
        'source': 'runtime',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _refreshCanonicalSnapshot(
    DatabaseExecutor db,
    String canonicalId,
  ) async {
    final sourceRows = await db.query(
      'source_record',
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalId],
      orderBy: 'fetched_at DESC',
    );
    if (sourceRows.isEmpty) {
      return;
    }

    final sourceIds = sourceRows.map((row) => row['id']! as String).toList();
    final aliasRows = await db.query(
      'food_alias',
      columns: ['alias'],
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalId],
      orderBy: 'alias COLLATE NOCASE ASC',
    );
    final placeholders = List<String>.filled(sourceIds.length, '?').join(', ');
    final observationRows = sourceIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await db.rawQuery(
            'SELECT * FROM nutrient_observation WHERE source_record_id IN ($placeholders) ORDER BY canonical_label COLLATE NOCASE ASC',
            sourceIds,
          );

    final firstSource = sourceRows.last;
    final latestSource = sourceRows.first;
    final countries = sourceRows
        .map((row) => row['country']! as String)
        .where((value) => value.trim().isNotEmpty)
        .toSet();

    final sourceFetchedAt = {
      for (final row in sourceRows)
        row['id']! as String: DateTime.parse(row['fetched_at']! as String),
    };
    final groupedObservations = <String, List<Map<String, Object?>>>{};
    for (final row in observationRows) {
      final canonicalLabel = row['canonical_label']! as String;
      groupedObservations.putIfAbsent(canonicalLabel, () => []).add(row);
    }

    final aggregatedNutrients = <Nutrient>[];
    for (final entry in groupedObservations.entries) {
      final ordered = entry.value.toList(growable: false)
        ..sort((left, right) {
          final leftFetched =
              sourceFetchedAt[left['source_record_id']! as String] ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final rightFetched =
              sourceFetchedAt[right['source_record_id']! as String] ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return rightFetched.compareTo(leftFetched);
        });
      final selected = ordered.first;
      aggregatedNutrients.add(
        Nutrient(
          label: selected['canonical_label']! as String,
          amount: (selected['amount']! as num).toDouble(),
          unit: selected['unit']! as String,
        ),
      );
    }
    aggregatedNutrients.sort(
      (left, right) => left.label.compareTo(right.label),
    );

    final canonicalRows = await db.query(
      'canonical_food',
      where: 'id = ?',
      whereArgs: [canonicalId],
      limit: 1,
    );
    final canonicalRow = canonicalRows.single;
    final overrideRows = await db.query(
      'manual_canonical_override',
      where: 'canonical_food_id = ?',
      whereArgs: [canonicalId],
      limit: 1,
    );
    final override = overrideRows.isEmpty ? null : overrideRows.single;
    final displayName = _overrideValue(
      override?['display_name'],
      canonicalRow['display_name']! as String,
    );
    final latestDescription =
        (latestSource['record_description']! as String).trim().isNotEmpty
        ? latestSource['record_description']! as String
        : firstSource['record_description']! as String;
    final servingBasis = _overrideValue(
      override?['serving_basis'],
      canonicalRow['serving_basis']! as String,
    );
    final category = _overrideValue(
      override?['canonical_category'],
      canonicalRow['canonical_category']! as String,
    );
    final computedCountry = countries.length > 1
        ? 'Multi-source'
        : (countries.isEmpty ? '' : countries.first);
    final country = _overrideValue(
      override?['canonical_country_hint'],
      computedCountry,
    );
    final computedDescription = latestDescription.isNotEmpty
        ? latestDescription
        : canonicalRow['description']! as String;
    final description = _overrideValue(
      override?['description'],
      computedDescription,
    );

    await db.insert('canonical_food', {
      'id': canonicalId,
      'display_name': displayName,
      'canonical_category': category,
      'canonical_country_hint': country,
      'description': description,
      'serving_basis': servingBasis,
      'last_aggregated_at': latestSource['source_updated_at']! as String,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final snapshot = FoodItem(
      id: canonicalId,
      name: displayName,
      category: category,
      country: country,
      sourceName: sourceRows.length > 1
          ? 'Merged official sources'
          : latestSource['source_name']! as String,
      description: description,
      servingBasis: servingBasis,
      tags: aliasRows
          .map((row) => row['alias']! as String)
          .toList(growable: false),
      nutrients: aggregatedNutrients,
      lastUpdated: DateTime.parse(latestSource['source_updated_at']! as String),
    );
    await _writeLegacySnapshot(db, snapshot);
  }

  String _overrideValue(Object? overrideValue, String fallback) {
    final value = overrideValue?.toString().trim();
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return value;
  }

  Future<void> _writeLegacySnapshot(DatabaseExecutor db, FoodItem item) async {
    await db.insert('foods', {
      'id': item.id,
      'name': item.name,
      'category': item.category,
      'country': item.country,
      'source_name': item.sourceName,
      'description': item.description,
      'serving_basis': item.servingBasis,
      'last_updated': item.lastUpdated.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.delete('food_tags', where: 'food_id = ?', whereArgs: [item.id]);
    await db.delete('nutrients', where: 'food_id = ?', whereArgs: [item.id]);

    for (final tag in item.tags) {
      await db.insert('food_tags', {
        'food_id': item.id,
        'tag': tag,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final nutrient in item.nutrients) {
      await db.insert('nutrients', {
        'food_id': item.id,
        'label': nutrient.label,
        'amount': nutrient.amount,
        'unit': nutrient.unit,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<FoodItem>> _hydrateFoods(
    List<Map<String, Object?>> foodRows,
  ) async {
    return _hydrateFoodsWithDb(_db, foodRows);
  }

  Future<List<FoodItem>> _hydrateFoodsWithDb(
    DatabaseExecutor db,
    List<Map<String, Object?>> foodRows,
  ) async {
    if (foodRows.isEmpty) {
      return const [];
    }

    final foodIds = foodRows.map((row) => row['id']! as String).toList();
    final placeholders = List<String>.filled(foodIds.length, '?').join(', ');

    final nutrientRows = await db.rawQuery(
      'SELECT * FROM nutrients WHERE food_id IN ($placeholders) ORDER BY label COLLATE NOCASE ASC',
      foodIds,
    );
    final tagRows = await db.rawQuery(
      'SELECT * FROM food_tags WHERE food_id IN ($placeholders) ORDER BY tag COLLATE NOCASE ASC',
      foodIds,
    );

    final nutrientsByFood = <String, List<Nutrient>>{};
    for (final row in nutrientRows) {
      final foodId = row['food_id']! as String;
      nutrientsByFood.putIfAbsent(foodId, () => []);
      nutrientsByFood[foodId]!.add(
        Nutrient(
          label: row['label']! as String,
          amount: (row['amount']! as num).toDouble(),
          unit: row['unit']! as String,
        ),
      );
    }

    final tagsByFood = <String, List<String>>{};
    for (final row in tagRows) {
      final foodId = row['food_id']! as String;
      tagsByFood.putIfAbsent(foodId, () => []);
      tagsByFood[foodId]!.add(row['tag']! as String);
    }

    return foodRows
        .map((row) {
          final id = row['id']! as String;
          return FoodItem(
            id: id,
            name: row['name']! as String,
            category: row['category']! as String,
            country: row['country']! as String,
            sourceName: row['source_name']! as String,
            description: row['description']! as String,
            servingBasis: row['serving_basis']! as String,
            tags: tagsByFood[id] ?? const [],
            nutrients: nutrientsByFood[id] ?? const [],
            lastUpdated: DateTime.parse(row['last_updated']! as String),
          );
        })
        .toList(growable: false);
  }

  FetchJobEntry _mapFetchJob(Map<String, Object?> row) {
    return FetchJobEntry(
      id: row['id']! as String,
      query: row['query']! as String,
      phase: row['phase']! as String,
      status: row['status']! as String,
      importerId: row['importer_id']! as String,
      startedAt: DateTime.parse(row['started_at']! as String),
      finishedAt: row['finished_at'] == null
          ? null
          : DateTime.parse(row['finished_at']! as String),
      message: row['message']! as String,
    );
  }
}

class _ReplayCanonicalCandidate {
  _ReplayCanonicalCandidate({
    required this.canonicalFoodId,
    required this.categoryKey,
    required this.servingKey,
    required this.aliasKeys,
    required this.nutrients,
  });

  final String canonicalFoodId;
  final String categoryKey;
  final String servingKey;
  final Set<String> aliasKeys;
  List<Nutrient> nutrients;
}
