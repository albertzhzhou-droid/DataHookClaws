import 'dart:async';
import 'dart:convert';

import 'package:data_hook_claws/src/data/memory_food_repository.dart';
import 'package:data_hook_claws/src/domain/merge_review_saved_view_store.dart';
import 'package:data_hook_claws/src/models/merge_review_filter.dart';
import 'package:data_hook_claws/src/models/merge_review_issue.dart';
import 'package:data_hook_claws/src/models/merge_review_saved_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MergeReviewSavedViewStore', () {
    test('constructor enforces item and payload limits at runtime', () {
      final repository = _ControllableMetaRepository();
      final minimumPayloadLength = utf8
          .encode(MergeReviewSavedViewCodec.emptyPayload)
          .length;
      for (final maxItems in [0, -1]) {
        expect(
          () => MergeReviewSavedViewStore(repository, maxItems: maxItems),
          throwsArgumentError,
          reason: 'maxItems: $maxItems',
        );
      }
      expect(
        () => MergeReviewSavedViewStore(
          repository,
          maxValueLength: minimumPayloadLength - 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => MergeReviewSavedViewStore(
          repository,
          maxValueLength: minimumPayloadLength,
        ),
        returnsNormally,
      );
    });

    test('upserts normalized names and preserves stable identity', () async {
      final clock = _SequenceClock([
        DateTime.utc(2026, 8, 30, 12),
        DateTime.utc(2026, 8, 30, 13),
        DateTime.utc(2026, 8, 30, 14),
      ]);
      final repository = _ControllableMetaRepository();
      final store = MergeReviewSavedViewStore(repository, clock: clock.call);

      final firstSnapshot = await store.save(
        name: 'Alpha View',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.info),
      );
      final original = firstSnapshot.single;
      await store.save(
        name: 'Beta View',
        filter: const MergeReviewFilter(severity: MergeReviewSeverity.warning),
      );
      final updatedSnapshot = await store.save(
        name: '  alpha\n  VIEW ',
        filter: const MergeReviewFilter(
          severity: MergeReviewSeverity.high,
          type: MergeReviewIssueType.categoryConflictCandidate,
        ),
      );

      expect(updatedSnapshot.map((view) => view.name), [
        'alpha VIEW',
        'Beta View',
      ]);
      final updated = updatedSnapshot.first;
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, DateTime.utc(2026, 8, 30, 14));
      expect(
        updated.filter,
        const MergeReviewFilter(
          severity: MergeReviewSeverity.high,
          type: MergeReviewIssueType.categoryConflictCandidate,
        ),
      );
      expect(
        MergeReviewSavedViewCodec.decode(repository.payload),
        updatedSnapshot,
      );
    });

    test(
      'clock rollback preserves an existing view updatedAt and ordering',
      () async {
        final clockValues = [
          DateTime.utc(2026, 8, 30, 12),
          DateTime.utc(2026, 8, 30, 14),
          DateTime.utc(2026, 8, 30, 13),
        ];
        var clockIndex = 0;
        final repository = _ControllableMetaRepository();
        final store = MergeReviewSavedViewStore(
          repository,
          clock: () => clockValues[clockIndex++],
        );

        await store.save(name: 'Alpha', filter: MergeReviewFilter.all);
        await store.save(name: 'Beta', filter: MergeReviewFilter.all);
        final rollbackSnapshot = await store.save(
          name: 'Beta',
          filter: const MergeReviewFilter(
            severity: MergeReviewSeverity.warning,
          ),
        );

        expect(rollbackSnapshot.map((view) => view.name), ['Beta', 'Alpha']);
        expect(rollbackSnapshot.first.updatedAt, DateTime.utc(2026, 8, 30, 14));
        expect(
          rollbackSnapshot.first.filter,
          const MergeReviewFilter(severity: MergeReviewSeverity.warning),
        );
        expect(
          MergeReviewSavedViewCodec.decode(repository.payload),
          rollbackSnapshot,
        );
      },
    );

    test('generates deterministic collision-free ids from the clock', () async {
      final now = DateTime.utc(2026, 8, 30, 12);
      final repository = _ControllableMetaRepository();
      final store = MergeReviewSavedViewStore(repository, clock: () => now);

      await store.save(name: 'Alpha', filter: MergeReviewFilter.all);
      final snapshot = await store.save(
        name: 'Beta',
        filter: MergeReviewFilter.all,
      );

      expect(snapshot.map((view) => view.id).toSet(), {
        now.microsecondsSinceEpoch.toString(),
        '${now.microsecondsSinceEpoch}-2',
      });
    });

    test(
      'loads newest deterministic winners before applying the limit',
      () async {
        final repository = _ControllableMetaRepository(
          payload: MergeReviewSavedViewCodec.encode([
            _view(
              id: 'name-old',
              name: 'ALPHA',
              updatedAt: DateTime.utc(2026, 8, 30, 8),
            ),
            _view(
              id: 'shared',
              name: 'Gamma old',
              updatedAt: DateTime.utc(2026, 8, 30, 9),
            ),
            _view(
              id: 'beta',
              name: 'Beta',
              updatedAt: DateTime.utc(2026, 8, 30, 10),
            ),
            _view(
              id: 'shared',
              name: 'Gamma new',
              updatedAt: DateTime.utc(2026, 8, 30, 10),
            ),
            _view(
              id: 'name-new',
              name: ' alpha ',
              updatedAt: DateTime.utc(2026, 8, 30, 11),
            ),
            _view(
              id: 'oldest',
              name: 'Oldest',
              updatedAt: DateTime.utc(2026, 8, 30, 7),
            ),
          ]),
        );
        final store = MergeReviewSavedViewStore(repository, maxItems: 3);

        final loaded = await store.load();

        expect(loaded.map((view) => view.id), ['name-new', 'beta', 'shared']);
        expect(loaded.map((view) => view.name), ['alpha', 'Beta', 'Gamma new']);
        expect(() => loaded.clear(), throwsUnsupportedError);
        expect(
          repository.setCalls,
          0,
          reason: 'load must not repair persisted data',
        );
      },
    );

    test('at capacity updates existing names but rejects new names', () async {
      var tick = 0;
      final repository = _ControllableMetaRepository();
      final store = MergeReviewSavedViewStore(
        repository,
        maxItems: 2,
        clock: () => DateTime.utc(2026, 8, 30, 12, tick++),
      );
      await store.save(name: 'Alpha', filter: MergeReviewFilter.all);
      await store.save(name: 'Beta', filter: MergeReviewFilter.all);

      await expectLater(
        store.save(
          name: 'ALPHA',
          filter: const MergeReviewFilter(severity: MergeReviewSeverity.high),
        ),
        completes,
      );
      final payloadBeforeRejectedSave = repository.payload;
      await expectLater(
        store.save(name: 'Gamma', filter: MergeReviewFilter.all),
        throwsStateError,
      );

      expect(repository.payload, payloadBeforeRejectedSave);
      expect((await store.load()).length, 2);
    });

    test('malformed and oversized payloads fail open without writes', () async {
      for (final payload in ['{bad', '[]', '{}']) {
        final repository = _ControllableMetaRepository(payload: payload);
        final store = MergeReviewSavedViewStore(repository);

        expect(await store.load(), isEmpty);
        expect(repository.setCalls, 0);
      }

      final oversizedRepository = _ControllableMetaRepository(
        payload: List.filled(200, 'x').join(),
      );
      final oversizedStore = MergeReviewSavedViewStore(
        oversizedRepository,
        maxValueLength: MergeReviewSavedViewCodec.emptyPayload.length,
      );
      expect(await oversizedStore.load(), isEmpty);
      expect(oversizedRepository.setCalls, 0);
    });

    test(
      'rejects an oversized mutation without replacing prior data',
      () async {
        final repository = _ControllableMetaRepository();
        final store = MergeReviewSavedViewStore(
          repository,
          maxValueLength: MergeReviewSavedViewCodec.emptyPayload.length + 10,
          clock: () => DateTime.utc(2026, 8, 30, 12),
        );

        await expectLater(
          store.save(name: 'Alpha', filter: MergeReviewFilter.all),
          throwsStateError,
        );

        expect(repository.payload, isNull);
        expect(repository.setCalls, 0);
      },
    );

    test('enforces the payload cap in UTF-8 bytes', () async {
      final now = DateTime.utc(2026, 8, 30, 12);
      final expected = MergeReviewSavedView(
        id: now.microsecondsSinceEpoch.toString(),
        name: '😀',
        filter: MergeReviewFilter.all,
        createdAt: now,
        updatedAt: now,
      );
      final encoded = MergeReviewSavedViewCodec.encode([expected]);
      final utf8Length = utf8.encode(encoded).length;
      expect(utf8Length, greaterThan(encoded.length));

      final loadRepository = _ControllableMetaRepository(payload: encoded);
      final loadStore = MergeReviewSavedViewStore(
        loadRepository,
        maxValueLength: utf8Length - 1,
      );
      expect(await loadStore.load(), isEmpty);
      expect(loadRepository.setCalls, 0);

      final saveRepository = _ControllableMetaRepository();
      final saveStore = MergeReviewSavedViewStore(
        saveRepository,
        maxValueLength: utf8Length - 1,
        clock: () => now,
      );
      await expectLater(
        saveStore.save(name: '😀', filter: MergeReviewFilter.all),
        throwsStateError,
      );
      expect(saveRepository.setCalls, 0);
    });

    test('serializes concurrent saves across store instances', () async {
      final repository = _ControllableMetaRepository(blockFirstWrite: true);
      final firstStore = MergeReviewSavedViewStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      final secondStore = MergeReviewSavedViewStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 13),
      );

      final firstSave = firstStore.save(
        name: 'Alpha',
        filter: MergeReviewFilter.all,
      );
      await repository.firstWriteStarted.future;
      final secondSave = secondStore.save(
        name: 'Beta',
        filter: MergeReviewFilter.all,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.getCalls, 1);
      expect(repository.setCalls, 1);
      repository.releaseFirstWrite.complete();
      await Future.wait([firstSave, secondSave]);

      expect(repository.getCalls, 2);
      expect(repository.setCalls, 2);
      expect(
        MergeReviewSavedViewCodec.decode(
          repository.payload,
        ).map((view) => view.name),
        ['Beta', 'Alpha'],
      );
    });

    test('failed writes do not poison later queued saves', () async {
      final repository = _ControllableMetaRepository(failWritesRemaining: 1);
      final store = MergeReviewSavedViewStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      final firstSave = store.save(
        name: 'Alpha',
        filter: MergeReviewFilter.all,
      );
      final firstExpectation = expectLater(firstSave, throwsStateError);
      final secondSave = store.save(
        name: 'Beta',
        filter: MergeReviewFilter.all,
      );

      await firstExpectation;
      await secondSave;

      expect(repository.setCalls, 2);
      expect(
        MergeReviewSavedViewCodec.decode(repository.payload).single.name,
        'Beta',
      );
    });

    test(
      'remove is idempotent and clear queues behind an in-flight save',
      () async {
        final repository = _ControllableMetaRepository(blockFirstWrite: true);
        final store = MergeReviewSavedViewStore(
          repository,
          clock: () => DateTime.utc(2026, 8, 30, 12),
        );
        final save = store.save(name: 'Alpha', filter: MergeReviewFilter.all);
        await repository.firstWriteStarted.future;
        final clear = store.clear();
        await Future<void>.delayed(Duration.zero);

        expect(repository.setCalls, 1);
        repository.releaseFirstWrite.complete();
        await save;
        await clear;

        expect(repository.setCalls, 2);
        expect(repository.payload, MergeReviewSavedViewCodec.emptyPayload);

        final writesBeforeUnknownRemove = repository.setCalls;
        expect(await store.remove('missing'), isEmpty);
        expect(repository.setCalls, writesBeforeUnknownRemove);
      },
    );

    test('removes a stored view by stable id', () async {
      final repository = _ControllableMetaRepository();
      final store = MergeReviewSavedViewStore(
        repository,
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      final saved = await store.save(
        name: 'Alpha',
        filter: MergeReviewFilter.all,
      );

      final remaining = await store.remove(saved.single.id);

      expect(remaining, isEmpty);
      expect(repository.payload, MergeReviewSavedViewCodec.emptyPayload);
    });
  });
}

MergeReviewSavedView _view({
  required String id,
  required String name,
  required DateTime updatedAt,
}) {
  return MergeReviewSavedView(
    id: id,
    name: name,
    filter: MergeReviewFilter.all,
    createdAt: DateTime.utc(2026, 8, 30, 6),
    updatedAt: updatedAt,
  );
}

class _SequenceClock {
  _SequenceClock(this._values);

  final List<DateTime> _values;
  int _index = 0;

  DateTime call() {
    final value = _values[_index];
    _index += 1;
    return value;
  }
}

class _ControllableMetaRepository extends MemoryFoodRepository {
  _ControllableMetaRepository({
    this.payload,
    this.blockFirstWrite = false,
    this.failWritesRemaining = 0,
  });

  String? payload;
  final bool blockFirstWrite;
  int failWritesRemaining;
  int getCalls = 0;
  int setCalls = 0;
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> releaseFirstWrite = Completer<void>();

  @override
  Future<String?> getAppMeta(String key) async {
    if (key != MergeReviewSavedViewStore.metaKey) {
      return super.getAppMeta(key);
    }
    getCalls += 1;
    return payload;
  }

  @override
  Future<void> setAppMeta(String key, String value) async {
    if (key != MergeReviewSavedViewStore.metaKey) {
      return super.setAppMeta(key, value);
    }
    setCalls += 1;
    if (blockFirstWrite && setCalls == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    if (failWritesRemaining > 0) {
      failWritesRemaining -= 1;
      throw StateError('simulated app_meta write failure');
    }
    payload = value;
  }
}
