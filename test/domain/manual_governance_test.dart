import 'dart:io';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/data/sqlite_food_repository.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:data_hook_claws/src/models/manual_governance.dart';
import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_issue_query.dart';
import 'package:data_hook_claws/src/models/nutrient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'manual merge moves a source record into a candidate canonical',
    () async {
      final repository = MemoryFoodRepository();
      await repository.upsertFoods([
        _food(
          id: 'canada-cnf:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
        ),
        _food(
          id: 'uk-mccance:salmon-spread',
          name: 'Atlantic Salmon',
          category: 'Spreads',
          country: 'United Kingdom',
          sourceName: 'CoFID',
        ),
      ]);

      final issues = await repository.getMergeReviewIssues();
      final conflict = issues.firstWhere(
        (issue) => issue.type == MergeReviewIssueType.categoryConflictCandidate,
      );

      await repository.mergeSourceRecord(
        sourceRecordId: conflict.sourceRecordId,
        targetCanonicalFoodId: conflict.suggestedCanonicalFoodId!,
        note: 'Reviewed as same product family.',
      );

      final details = await repository.getFoodDetails(
        conflict.suggestedCanonicalFoodId!,
      );
      final logs = await repository.getManualGovernanceLogs();

      expect(details!.sourceRecords, hasLength(2));
      expect(logs.single.action, 'merge');
      expect(logs.single.note, contains('Reviewed'));
    },
  );

  test('manual split creates a new canonical entry for one source', () async {
    final repository = MemoryFoodRepository();
    await repository.upsertFoods([
      _food(
        id: 'canada-cnf:salmon',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'Canada',
        sourceName: 'CNF',
      ),
      _food(
        id: 'uk-mccance:salmon',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'United Kingdom',
        sourceName: 'CoFID',
      ),
    ]);

    await repository.splitSourceRecord(
      sourceRecordId: 'uk-mccance:salmon',
      note: 'Reviewed as a distinct source concept.',
    );

    final results = await repository.searchFoods('salmon');
    final logs = await repository.getManualGovernanceLogs();

    expect(results, hasLength(2));
    expect(logs.single.action, 'split');
  });

  test('manual canonical override updates the snapshot', () async {
    final repository = MemoryFoodRepository();
    await repository.upsertFoods([
      _food(
        id: 'canada-cnf:salmon',
        name: 'Atlantic Salmon',
        category: 'Seafood',
        country: 'Canada',
        sourceName: 'CNF',
      ),
    ]);
    final original = (await repository.searchFoods('salmon')).single;

    await repository.overrideCanonicalFood(
      canonicalFoodId: original.id,
      fields: const CanonicalOverrideFields(displayName: 'Reviewed Salmon'),
      note: 'Prefer reviewed display label.',
    );

    final updated = (await repository.searchFoods('reviewed')).single;
    expect(updated.name, 'Reviewed Salmon');
    expect(
      (await repository.getManualGovernanceLogs()).single.action,
      'override',
    );
  });

  test(
    'sqlite review query filters before paging and reports full counts',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final tempDirectory = await Directory.systemTemp.createTemp(
        'review-query-sqlite',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final repository = SqliteFoodRepository(
        documentsDirectoryResolver: () async => tempDirectory,
      );
      await repository.initialize();
      await repository.upsertFoods([
        _food(
          id: 'canada-cnf:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
        ),
        _food(
          id: 'uk-mccance:salmon-spread',
          name: 'Atlantic Salmon',
          category: 'Spreads',
          country: 'United Kingdom',
          sourceName: 'CoFID',
        ),
        _food(
          id: 'usda:salmon-oil',
          name: 'Atlantic Salmon',
          category: 'Oil',
          country: 'United States',
          sourceName: 'USDA',
        ),
      ]);

      final allIssues = await repository.getMergeReviewIssues();
      final query = const MergeReviewFilter(
        severity: MergeReviewSeverity.high,
        type: MergeReviewIssueType.categoryConflictCandidate,
      );
      final firstPage = await repository.queryMergeReviewIssues(
        MergeReviewIssueQuery(filter: query, limit: 1),
      );
      final secondPage = await repository.queryMergeReviewIssues(
        MergeReviewIssueQuery(filter: query, offset: 1, limit: 1),
      );

      expect(firstPage.totalCount, allIssues.length);
      expect(firstPage.matchingCount, greaterThan(1));
      expect(secondPage.totalCount, firstPage.totalCount);
      expect(secondPage.matchingCount, firstPage.matchingCount);
      expect(firstPage.items, hasLength(1));
      expect(secondPage.items, hasLength(1));
      expect(secondPage.items.single.id, isNot(firstPage.items.single.id));
      for (final issue in [...firstPage.items, ...secondPage.items]) {
        expect(issue.severity, MergeReviewSeverity.high);
        expect(issue.type, MergeReviewIssueType.categoryConflictCandidate);
      }
    },
  );

  test(
    'sqlite manual split persists governance log and refreshes results',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final tempDirectory = await Directory.systemTemp.createTemp(
        'manual-governance-sqlite',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final repository = SqliteFoodRepository(
        documentsDirectoryResolver: () async => tempDirectory,
      );
      await repository.initialize();
      await repository.upsertFoods([
        _food(
          id: 'canada-cnf:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
        ),
        _food(
          id: 'uk-mccance:salmon',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'United Kingdom',
          sourceName: 'CoFID',
        ),
      ]);

      await repository.splitSourceRecord(
        sourceRecordId: 'uk-mccance:salmon',
        note: 'SQLite split verification.',
      );

      expect(await repository.searchFoods('salmon'), hasLength(2));
      expect(
        (await repository.getManualGovernanceLogs()).single.action,
        'split',
      );
    },
  );
}

FoodItem _food({
  required String id,
  required String name,
  required String category,
  required String country,
  required String sourceName,
}) {
  return FoodItem(
    id: id,
    name: name,
    category: category,
    country: country,
    sourceName: sourceName,
    description: '$sourceName record for $name',
    servingBasis: 'Per 100 g',
    tags: const ['official'],
    nutrients: const [Nutrient(label: 'Protein', amount: 20, unit: 'g')],
    lastUpdated: DateTime(2026, 5, 25),
  );
}
