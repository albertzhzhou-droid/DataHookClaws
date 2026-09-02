// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/sqlite_food_repository.dart';
import 'package:data_hook_claws/src/domain/food_quality_service.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_identity.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_query.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqflite_logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  sqfliteFfiInit();

  group('SQLite bulk merge-review derivation', () {
    test(
      'matches the per-food hydration oracle for semantics and paging',
      () async {
        final harness = await _SqliteHarness.create();
        addTearDown(harness.dispose);
        await harness.repository.upsertFoods([
          _food(
            id: 'canada:salmon-base',
            name: 'Atlantic Salmon',
            category: 'Seafood',
            protein: 20,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          _food(
            id: 'uk:salmon-reuse',
            name: 'Atlantic Salmon',
            category: 'Seafood',
            protein: 2,
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
          _food(
            id: 'usda:salmon-oil',
            name: 'Atlantic Salmon',
            category: 'Oil',
            protein: 5,
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        ]);

        final referenceIssues = await _deriveReviewIssuesPerFood(
          harness.repository,
        );
        final fullQuery = MergeReviewIssueQuery(limit: 100);
        final expectedFull = MergeReviewIssuePage.fromIssues(
          issues: referenceIssues,
          query: fullQuery,
        );
        final actualFull = await harness.repository.queryMergeReviewIssues(
          fullQuery,
        );

        expect(_signatures(actualFull.items), _signatures(expectedFull.items));
        expect(actualFull.totalCount, expectedFull.totalCount);
        expect(actualFull.matchingCount, expectedFull.matchingCount);
        expect(
          actualFull.items.map((issue) => issue.type).toSet(),
          containsAll(MergeReviewIssueType.values),
        );

        final filteredQuery = MergeReviewIssueQuery(
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
          offset: 1,
          limit: 1,
        );
        final expectedFiltered = MergeReviewIssuePage.fromIssues(
          issues: referenceIssues,
          query: filteredQuery,
        );
        final actualFiltered = await harness.repository.queryMergeReviewIssues(
          filteredQuery,
        );

        expect(expectedFiltered.matchingCount, greaterThanOrEqualTo(2));
        expect(
          _signatures(actualFiltered.items),
          _signatures(expectedFiltered.items),
        );
        expect(actualFiltered.totalCount, expectedFiltered.totalCount);
        expect(actualFiltered.matchingCount, expectedFiltered.matchingCount);
        expect(actualFiltered.offset, 1);
        expect(actualFiltered.limit, 1);
        expect(actualFiltered.hasPrevious, isTrue);
      },
    );

    test(
      'matches Memory versioned identities despite different hydration order',
      () async {
        final foods = [
          _food(
            id: 'zeta:salmon-base',
            name: 'Atlantic Salmon',
            category: 'Seafood',
            protein: 20,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          _food(
            id: 'alpha:salmon-reuse',
            name: 'Atlantic Salmon',
            category: 'Seafood',
            protein: 2,
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
          _food(
            id: 'mu:salmon-oil',
            name: 'Atlantic Salmon',
            category: 'Oil',
            protein: 5,
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        ];
        final memory = MemoryFoodRepository();
        final harness = await _SqliteHarness.create();
        addTearDown(harness.dispose);

        await memory.upsertFoods(foods);
        await harness.repository.upsertFoods(foods);
        final memoryIssues = await memory.getMergeReviewIssues();
        final sqliteIssues = await harness.repository.getMergeReviewIssues();
        final memoryIds = memoryIssues.map((issue) => issue.id).toList()
          ..sort();
        final sqliteIds = sqliteIssues.map((issue) => issue.id).toList()
          ..sort();

        expect(memoryIds, sqliteIds);
        expect(memoryIds.toSet(), hasLength(memoryIds.length));
        expect(sqliteIds.toSet(), hasLength(sqliteIds.length));
        expect(
          memoryIssues.map((issue) => issue.type).toSet(),
          containsAll(MergeReviewIssueType.values),
        );
        expect(
          memoryIds.map(MergeReviewIssueIdentity.tryDecode),
          everyElement(isNotNull),
        );
      },
    );

    test(
      'uses a fixed SELECT budget inside one transaction snapshot',
      () async {
        final harness = await _SqliteHarness.create();
        addTearDown(harness.dispose);
        await harness.repository.upsertFoods([
          for (var index = 0; index < 2; index++)
            _uniqueFood(index, prefix: 'small'),
        ]);

        harness.events.clear();
        await harness.repository.queryMergeReviewIssues(
          MergeReviewIssueQuery(limit: 100),
        );
        final smallTrace = _SqlTrace.fromEvents(harness.events);

        await harness.repository.upsertFoods([
          for (var index = 0; index < 30; index++)
            _uniqueFood(index, prefix: 'large'),
        ]);
        harness.events.clear();
        await harness.repository.queryMergeReviewIssues(
          MergeReviewIssueQuery(limit: 100),
        );
        final largeTrace = _SqlTrace.fromEvents(harness.events);

        expect(smallTrace.selects, isNotEmpty);
        expect(largeTrace.selects.length, smallTrace.selects.length);
        expect(largeTrace.selects.length, lessThanOrEqualTo(8));
        _expectSingleTransactionSnapshot(smallTrace);
        _expectSingleTransactionSnapshot(largeTrace);
      },
    );

    test(
      'handles more than 999 canonicals, sources, audits, and candidates',
      () async {
        const rowCount = 1005;
        final harness = await _SqliteHarness.create();
        addTearDown(harness.dispose);
        final writer = await harness.openUnloggedConnection();
        try {
          final batch = writer.batch();
          for (var index = 0; index < rowCount; index++) {
            final suffix = index.toString().padLeft(4, '0');
            final canonicalId = 'canonical-limit-$suffix';
            final sourceId = 'source-limit-$suffix';
            final auditId = 'audit-limit-$suffix';
            final createdAt = DateTime.utc(
              2026,
              1,
              1,
            ).add(Duration(seconds: index));
            batch.insert('canonical_food', {
              'id': canonicalId,
              'display_name': 'Limit Food $suffix',
              'canonical_category': 'Test',
              'canonical_country_hint': 'Testland',
              'description': 'parameter-limit fixture',
              'serving_basis': 'Per 100 g',
              'last_aggregated_at': createdAt.toIso8601String(),
            });
            batch.insert('foods', {
              'id': canonicalId,
              'name': 'Limit Food $suffix',
              'category': 'Test',
              'country': 'Testland',
              'source_name': 'Fixture',
              'description': 'parameter-limit fixture',
              'serving_basis': 'Per 100 g',
              'last_updated': createdAt.toIso8601String(),
            });
            batch.insert('source_record', {
              'id': sourceId,
              'canonical_food_id': canonicalId,
              'importer_id': 'fixture',
              'source_name': 'Fixture',
              'source_record_id': sourceId,
              'country': 'Testland',
              'record_title': 'Limit Food $suffix',
              'record_description': 'parameter-limit fixture',
              'fetched_at': createdAt.toIso8601String(),
              'source_updated_at': createdAt.toIso8601String(),
            });
            batch.insert(
              'merge_audit',
              _auditRow(
                id: auditId,
                sourceId: sourceId,
                canonicalId: canonicalId,
                reason: 'bulk-limit-$suffix',
                createdAt: createdAt,
              ),
            );
            batch.insert('merge_audit_candidate', {
              'id': 'candidate-row-$suffix',
              'merge_audit_id': auditId,
              'candidate_canonical_food_id': 'candidate-$suffix',
              'alias_matched': 0,
              'category_matched': 1,
              'serving_matched': 1,
              'nutrient_similarity': 0.5,
              'accepted': 0,
              'reason': 'Alias key mismatch.',
            });
          }
          await batch.commit(noResult: true);
        } finally {
          await writer.close();
        }

        final page = await harness.repository.queryMergeReviewIssues(
          MergeReviewIssueQuery(
            filter: const MergeReviewFilter(
              severity: MergeReviewSeverity.warning,
              type: MergeReviewIssueType.lowConfidenceReuse,
            ),
            offset: 1000,
            limit: 10,
          ),
        );

        expect(page.totalCount, rowCount);
        expect(page.matchingCount, rowCount);
        expect(page.items, hasLength(5));
        expect(page.items.first.sourceRecordId, 'source-limit-0004');
        expect(page.items.first.reason, 'bulk-limit-0004');
      },
    );

    test(
      'duplicate audits choose latest then greatest id on equal time',
      () async {
        final harness = await _SqliteHarness.create();
        addTearDown(harness.dispose);
        await harness.repository.upsertFoods([
          _food(
            id: 'fixture:duplicate-source',
            name: 'Duplicate Audit Food',
            category: 'Test',
            protein: 10,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        ]);
        final canonicalId = (await harness.repository.getAllFoods()).single.id;
        final equalCreatedAt = DateTime.utc(2099, 1, 2);
        final writer = await harness.openUnloggedConnection();
        try {
          await writer.insert(
            'merge_audit',
            _auditRow(
              id: 'duplicate-a',
              sourceId: 'fixture:duplicate-source',
              canonicalId: canonicalId,
              reason: 'equal-time-a-loses',
              createdAt: equalCreatedAt,
            ),
          );
          await writer.insert(
            'merge_audit',
            _auditRow(
              id: 'duplicate-z',
              sourceId: 'fixture:duplicate-source',
              canonicalId: canonicalId,
              reason: 'equal-time-z-wins',
              createdAt: equalCreatedAt,
            ),
          );
          await writer.insert(
            'merge_audit',
            _auditRow(
              id: 'duplicate-newer-than-original-but-older-than-tie',
              sourceId: 'fixture:duplicate-source',
              canonicalId: canonicalId,
              reason: 'older-loses',
              createdAt: DateTime.utc(2099, 1, 1),
            ),
          );
        } finally {
          await writer.close();
        }

        final query = MergeReviewIssueQuery(
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
            type: MergeReviewIssueType.lowConfidenceReuse,
          ),
          limit: 10,
        );
        final first = await harness.repository.queryMergeReviewIssues(query);
        final second = await harness.repository.queryMergeReviewIssues(query);

        expect(first.matchingCount, 1);
        expect(first.items.single.reason, 'equal-time-z-wins');
        expect(first.items.single.createdAt, equalCreatedAt);
        expect(_signatures(second.items), _signatures(first.items));
      },
    );
  });
}

Future<List<MergeReviewIssue>> _deriveReviewIssuesPerFood(
  SqliteFoodRepository repository,
) async {
  final qualityService = FoodQualityService();
  final issues = <MergeReviewIssue>[];
  for (final food in await repository.getAllFoods()) {
    final details = await repository.getFoodDetails(food.id);
    if (details != null) {
      issues.addAll(qualityService.reviewIssuesForDetails(details));
    }
  }
  return issues;
}

void _expectSingleTransactionSnapshot(_SqlTrace trace) {
  expect(trace.beginCount, 1);
  expect(trace.commitCount, 1);
  expect(trace.rollbackCount, 0);
  final transactionIds = trace.selects
      .map((event) => event.transactionId)
      .toSet();
  expect(transactionIds, hasLength(1));
  expect(transactionIds.single, isNotNull);
}

List<String> _signatures(Iterable<MergeReviewIssue> issues) {
  return issues
      .map(
        (issue) => [
          issue.id,
          issue.canonicalFoodId,
          issue.sourceRecordId,
          issue.type.name,
          issue.severity.name,
          issue.reason,
          issue.candidateSummary,
          issue.createdAt.toIso8601String(),
          issue.suggestedCanonicalFoodId ?? '',
        ].join('\u001f'),
      )
      .toList(growable: false);
}

FoodItem _food({
  required String id,
  required String name,
  required String category,
  required double protein,
  required DateTime updatedAt,
}) {
  return FoodItem(
    id: id,
    name: name,
    category: category,
    country: 'Testland',
    sourceName: id.split(':').first,
    description: 'Fixture for $name',
    servingBasis: 'Per 100 g',
    tags: const [],
    nutrients: [Nutrient(label: 'Protein', amount: protein, unit: 'g')],
    lastUpdated: updatedAt,
  );
}

FoodItem _uniqueFood(int index, {required String prefix}) {
  return _food(
    id: '$prefix:food-$index',
    name: '$prefix Unique Food $index',
    category: 'Test',
    protein: 10 + index.toDouble(),
    updatedAt: DateTime.utc(2026, 2, 1).add(Duration(minutes: index)),
  );
}

Map<String, Object?> _auditRow({
  required String id,
  required String sourceId,
  required String canonicalId,
  required String reason,
  required DateTime createdAt,
}) {
  return {
    'id': id,
    'source_record_id': sourceId,
    'canonical_food_id': canonicalId,
    'action': 'reuse',
    'confidence': 0.5,
    'matched_by': 'test-fixture',
    'reason': reason,
    'item_alias_key': '',
    'item_category_key': '',
    'item_serving_key': '',
    'created_at': createdAt.toIso8601String(),
  };
}

class _SqlTrace {
  const _SqlTrace({
    required this.selects,
    required this.beginCount,
    required this.commitCount,
    required this.rollbackCount,
  });

  factory _SqlTrace.fromEvents(Iterable<SqfliteLoggerEvent> events) {
    final sqlEvents = events.whereType<SqfliteLoggerSqlEvent<dynamic>>().toList(
      growable: false,
    );
    final selects = sqlEvents
        .where((event) => event.type == SqliteSqlCommandType.query)
        .toList(growable: false);
    final statements = sqlEvents
        .map((event) => event.sql.trim().toUpperCase())
        .toList(growable: false);
    return _SqlTrace(
      selects: selects,
      beginCount: statements.where((sql) => sql.startsWith('BEGIN')).length,
      commitCount: statements.where((sql) => sql == 'COMMIT').length,
      rollbackCount: statements.where((sql) => sql == 'ROLLBACK').length,
    );
  }

  final List<SqfliteLoggerSqlEvent<dynamic>> selects;
  final int beginCount;
  final int commitCount;
  final int rollbackCount;
}

class _SqliteHarness {
  const _SqliteHarness({
    required this.directory,
    required this.databasePath,
    required this.repository,
    required this.events,
  });

  static Future<_SqliteHarness> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'sqlite-merge-review-bulk',
    );
    const databaseFileName = 'data_hook_claws.db';
    final events = <SqfliteLoggerEvent>[];
    // ignore: experimental_member_use
    final loggingFactory = SqfliteDatabaseFactoryLogger(
      databaseFactoryFfi,
      options: SqfliteLoggerOptions(
        type: SqfliteDatabaseFactoryLoggerType.all,
        log: events.add,
      ),
    );
    final repository = SqliteFoodRepository(
      documentsDirectoryResolver: () async => directory,
      databaseFileName: databaseFileName,
      databaseFactory: loggingFactory,
    );
    await repository.initialize();
    return _SqliteHarness(
      directory: directory,
      databasePath: p.join(directory.path, databaseFileName),
      repository: repository,
      events: events,
    );
  }

  final Directory directory;
  final String databasePath;
  final SqliteFoodRepository repository;
  final List<SqfliteLoggerEvent> events;

  Future<Database> openUnloggedConnection() {
    return databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
  }

  Future<void> dispose() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
