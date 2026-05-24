import 'dart:io';

import 'package:data_hook_claws/src/data/sqlite_food_repository.dart';
import 'package:data_hook_claws/src/models/fetch_job_entry.dart';
import 'package:data_hook_claws/src/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'migrates legacy tables into provenance-first schema without data loss',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final tempDirectory = await Directory.systemTemp.createTemp(
        'sqlite-migration',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final databasePath = p.join(tempDirectory.path, 'data_hook_claws.db');
      final legacyDb = await openDatabase(
        databasePath,
        version: 2,
        onCreate: (db, version) async {
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
          await db.execute('''
          CREATE TABLE import_logs(
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
        },
      );

      await legacyDb.insert('foods', {
        'id': 'legacy-salmon',
        'name': 'Legacy Salmon',
        'category': 'Seafood',
        'country': 'Canada',
        'source_name': 'CNF',
        'description': 'legacy row',
        'serving_basis': 'Per 100 g',
        'last_updated': DateTime(2026, 5, 23).toIso8601String(),
      });
      await legacyDb.insert('food_tags', {
        'food_id': 'legacy-salmon',
        'tag': 'omega-3',
      });
      await legacyDb.insert('nutrients', {
        'food_id': 'legacy-salmon',
        'label': 'Protein',
        'amount': 20.0,
        'unit': 'g',
      });
      await legacyDb.close();

      final repository = SqliteFoodRepository(
        documentsDirectoryResolver: () async => tempDirectory,
      );
      await repository.initialize();

      final foods = await repository.searchFoods('legacy');
      expect(foods.single.name, 'Legacy Salmon');
      final details = await repository.getFoodDetails(foods.single.id);
      expect(details?.displayName, 'Legacy Salmon');
      expect(details?.aliases, contains('omega-3'));
      expect(details?.sourceRecords, isNotEmpty);
      expect(details?.sourceRecords.first.mergeAudit, isNotNull);
      expect(details?.nutrientObservations, isNotEmpty);

      final migratedDb = await openDatabase(databasePath);
      final canonicalRows = await migratedDb.query('canonical_food');
      final sourceRows = await migratedDb.query('source_record');
      final nutrientRows = await migratedDb.query('nutrient_observation');
      final aliasRows = await migratedDb.query('food_alias');
      final auditRows = await migratedDb.query('merge_audit');
      final candidateRows = await migratedDb.query('merge_audit_candidate');

      expect(canonicalRows, isNotEmpty);
      expect(sourceRows, isNotEmpty);
      expect(nutrientRows, isNotEmpty);
      expect(aliasRows, isNotEmpty);
      expect(auditRows, isNotEmpty);
      expect(candidateRows, isEmpty);

      await migratedDb.close();
    },
  );

  test('reads recent fetch jobs by query and phase', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final tempDirectory = await Directory.systemTemp.createTemp('sqlite-jobs');
    addTearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final repository = SqliteFoodRepository(
      documentsDirectoryResolver: () async => tempDirectory,
    );
    await repository.initialize();

    await repository.upsertFetchJob(
      FetchJobEntry(
        id: 'foreground-1',
        query: 'salmon',
        phase: 'foreground',
        status: 'success',
        importerId: 'canada-cnf',
        startedAt: DateTime(2026, 5, 23, 10),
        finishedAt: DateTime(2026, 5, 23, 10, 0, 1),
        message: 'foreground done',
      ),
    );
    await repository.upsertFetchJob(
      FetchJobEntry(
        id: 'enrichment-1',
        query: 'salmon',
        phase: 'enrichment',
        status: 'queued',
        importerId: 'uk-mccance',
        startedAt: DateTime(2026, 5, 23, 11),
        finishedAt: null,
        message: 'queued',
      ),
    );

    final jobs = await repository.getRecentFetchJobs(
      query: 'salmon',
      phase: 'enrichment',
      limit: 10,
    );
    final latest = await repository.getLatestFetchJobForQuery(
      query: 'salmon',
      phase: 'enrichment',
    );

    expect(jobs, hasLength(1));
    expect(jobs.single.importerId, 'uk-mccance');
    expect(latest?.id, 'enrichment-1');
  });

  test('returns empty provenance observations without throwing', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final tempDirectory = await Directory.systemTemp.createTemp(
      'sqlite-empty-details',
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
      FoodItem(
        id: 'food-1',
        name: 'Plain Rice',
        category: 'Grains',
        country: 'Japan',
        sourceName: 'MEXT',
        description: 'simple food',
        servingBasis: 'Per 100 g',
        tags: const [],
        nutrients: const [],
        lastUpdated: DateTime(2026, 5, 23),
      ),
    ]);

    final foods = await repository.searchFoods('plain');
    final details = await repository.getFoodDetails(foods.single.id);

    expect(details?.displayName, 'Plain Rice');
    expect(details?.sourceRecords, isNotEmpty);
    expect(details?.sourceRecords.first.mergeAudit?.action, 'create');
    expect(details?.nutrientObservations, isEmpty);
  });

  test(
    'replaces prior merge audit rows when same source record is re-imported',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final tempDirectory = await Directory.systemTemp.createTemp(
        'sqlite-merge-audit-replace',
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
        FoodItem(
          id: 'canada-cnf:salmon-1',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
          description: 'first',
          servingBasis: 'Per 100 g',
          tags: const [],
          nutrients: const [],
          lastUpdated: DateTime(2026, 5, 23, 9),
        ),
      ]);
      await repository.upsertFoods([
        FoodItem(
          id: 'canada-cnf:salmon-1',
          name: 'Atlantic Salmon',
          category: 'Seafood',
          country: 'Canada',
          sourceName: 'CNF',
          description: 'second',
          servingBasis: 'Per 100 g',
          tags: const ['omega-3'],
          nutrients: const [],
          lastUpdated: DateTime(2026, 5, 23, 10),
        ),
      ]);

      final db = await openDatabase(
        p.join(tempDirectory.path, 'data_hook_claws.db'),
      );
      final auditRows = await db.query(
        'merge_audit',
        where: 'source_record_id = ?',
        whereArgs: ['canada-cnf:salmon-1'],
      );
      final candidateRows = await db.query(
        'merge_audit_candidate',
        where: 'merge_audit_id = ?',
        whereArgs: ['merge-audit:canada-cnf:salmon-1'],
      );

      expect(auditRows, hasLength(1));
      expect(candidateRows, hasLength(1));
      expect(candidateRows.single['accepted'], 1);

      await db.close();
    },
  );
}
